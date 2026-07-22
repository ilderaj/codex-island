import Combine
import Foundation

enum ChatGPTHostApplyState: Equatable {
    case idle
    case validatingTarget
    case requestingHostTermination
    case cancelled
    case targetDrift
    case switchingLocally
    case localSwitchComplete
    case hostTerminated
    case launchAttempted
    case authReloadUnverified
    case localSwitchFailed(String)
    case launchFailed(String)
    case localRestoreFailed(String)
}

@MainActor
final class CodexAccountApplyCoordinator: ObservableObject {
    static let shared = CodexAccountApplyCoordinator()

    @Published private(set) var state: ChatGPTHostApplyState = .idle
    @Published private(set) var switchedAccountKey: String?
    @Published private(set) var didSwitchLocallyForCurrentApply = false
    @Published private(set) var applyingAccountKey: String?
    @Published private(set) var restorationRequiresManualHostLaunch = false

    var isApplying: Bool { applyingAccountKey != nil }

    let store: CodexAccountStore
    private let policy: ChatGPTHostTargetValidating
    private let controller: ChatGPTHostController
    private var launchTarget: ChatGPTHostTarget?
    private var hostWasTerminated = false

    init(
        store: CodexAccountStore = .shared,
        policy: ChatGPTHostTargetValidating = ChatGPTHostPolicy(),
        controller: ChatGPTHostController = ChatGPTHostController()
    ) {
        self.store = store
        self.policy = policy
        self.controller = controller
    }

    func apply(accountKey: String) async {
        guard applyingAccountKey == nil else { return }
        applyingAccountKey = accountKey
        defer { applyingAccountKey = nil }
        didSwitchLocallyForCurrentApply = false
        hostWasTerminated = false
        restorationRequiresManualHostLaunch = false
        state = .validatingTarget
        let initial: ChatGPTHostTarget
        do {
            initial = try policy.validateTarget()
        } catch {
            state = .targetDrift
            return
        }

        state = .requestingHostTermination
        let termination = await controller.terminateApplication(at: initial)
        switch termination {
        case .refused, .timedOut:
            state = .cancelled
            return
        case .notRunning:
            guard targetStillMatches(initial) else {
                state = .targetDrift
                return
            }
            switchLocally(accountKey)
        case .terminated:
            hostWasTerminated = true
            state = .hostTerminated
            guard targetStillMatches(initial) else {
                state = .targetDrift
                return
            }
            guard switchLocally(accountKey) else {
                await reopenOriginalHost(afterFailedSwitchAt: initial)
                return
            }
            launchTarget = initial
            await launch(target: initial)
        }
    }

    func retryLaunch() async {
        guard applyingAccountKey == nil,
              case .launchFailed = state,
              let target = launchTarget,
              targetStillMatches(target) else { return }
        applyingAccountKey = switchedAccountKey
        defer { applyingAccountKey = nil }
        await launch(target: target)
    }

    func restorePreviousAccount() async {
        guard applyingAccountKey == nil, case .launchFailed = state else { return }
        applyingAccountKey = switchedAccountKey
        defer { applyingAccountKey = nil }
        do {
            try store.switchPrevious()
            switchedAccountKey = store.registry.activeAccountKey
            didSwitchLocallyForCurrentApply = true
            restorationRequiresManualHostLaunch = hostWasTerminated
            state = .localSwitchComplete
        } catch {
            state = .localRestoreFailed(error.localizedDescription)
        }
    }

    private func targetStillMatches(_ expected: ChatGPTHostTarget) -> Bool {
        (try? policy.validateTarget()) == expected
    }

    @discardableResult
    private func switchLocally(_ accountKey: String) -> Bool {
        state = .switchingLocally
        do {
            try store.switchToAccount(accountKey)
            switchedAccountKey = accountKey
            didSwitchLocallyForCurrentApply = true
            state = .localSwitchComplete
            return true
        } catch {
            state = .localSwitchFailed(error.localizedDescription)
            return false
        }
    }

    private func reopenOriginalHost(afterFailedSwitchAt target: ChatGPTHostTarget) async {
        do {
            try await controller.launchApplication(at: target)
        } catch {
            state = .localSwitchFailed(error.localizedDescription)
        }
    }

    private func launch(target: ChatGPTHostTarget) async {
        state = .launchAttempted
        do {
            try await controller.launchApplication(at: target)
            state = .authReloadUnverified
        } catch {
            state = .launchFailed(error.localizedDescription)
        }
    }
}
