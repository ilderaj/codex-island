import Combine
import Foundation

enum ChatGPTHostApplyState: Equatable {
    case idle
    case validatingTarget
    case switchingLocally
    case localSwitchComplete
    case terminatingHost
    case hostTerminated
    case launchAttempted
    case authReloadUnverified
    case localSwitchFailed(String)
    case terminationFailed(String)
    case launchFailed(String)
    case localRestoreFailed(String)

    var claimsAuthReload: Bool { false }
}

@MainActor
final class CodexAccountApplyCoordinator: ObservableObject {
    @Published private(set) var state: ChatGPTHostApplyState = .idle
    @Published private(set) var switchedAccountKey: String?
    @Published private(set) var restorationRequiresManualHostLaunch = false

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
        state = .validatingTarget
        let initialTarget: ChatGPTHostTarget
        do {
            initialTarget = try policy.validateTarget()
        } catch {
            state = .terminationFailed("ChatGPT target could not be verified; reopen it manually")
            return
        }

        state = .switchingLocally
        do {
            try store.switchToAccount(accountKey)
            switchedAccountKey = accountKey
            restorationRequiresManualHostLaunch = false
            state = .localSwitchComplete
        } catch {
            state = .localSwitchFailed(error.localizedDescription)
            return
        }

        let terminationTarget: ChatGPTHostTarget
        do {
            terminationTarget = try policy.validateTarget()
        } catch {
            state = .terminationFailed("ChatGPT target could not be verified; reopen it manually")
            return
        }
        guard terminationTarget == initialTarget else {
            state = .terminationFailed("ChatGPT target changed; reopen it manually")
            return
        }

        launchTarget = terminationTarget
        state = .terminatingHost
        switch await controller.terminateApplication(at: terminationTarget) {
        case .notRunning:
            hostWasTerminated = false
        case .terminated:
            hostWasTerminated = true
            state = .hostTerminated
        case .refused:
            state = .terminationFailed("ChatGPT refused to quit; reopen it manually")
            return
        case .timedOut:
            state = .terminationFailed("ChatGPT did not quit in time; reopen it manually")
            return
        }

        await launch(target: terminationTarget)
    }

    func retryLaunch() async {
        guard case .launchFailed = state, let previousTarget = launchTarget else { return }

        let retryTarget: ChatGPTHostTarget
        do {
            retryTarget = try policy.validateTarget()
        } catch {
            state = .launchFailed("ChatGPT target could not be verified; reopen it manually")
            return
        }
        guard retryTarget == previousTarget else {
            state = .launchFailed("ChatGPT target changed; reopen it manually")
            return
        }
        await launch(target: retryTarget)
    }

    func restorePreviousAccount() async {
        do {
            try store.switchPrevious()
            switchedAccountKey = store.registry.activeAccountKey
            restorationRequiresManualHostLaunch = hostWasTerminated
            state = .localSwitchComplete
        } catch {
            state = .localRestoreFailed(error.localizedDescription)
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
