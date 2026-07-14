import AppKit
import Foundation

protocol ChatGPTHostRuntime {
    func runningApplicationURLs() async -> [URL]
    func requestTermination(applicationAt appURL: URL) async -> Bool
    func waitForTermination(applicationAt appURL: URL, timeout: TimeInterval) async -> Bool
    func launch(applicationAt appURL: URL) async throws
}

enum ChatGPTHostTerminationResult: Equatable {
    case notRunning
    case terminated
    case refused
    case timedOut
}

final class ChatGPTHostController {
    private let runtime: ChatGPTHostRuntime
    private let terminationTimeout: TimeInterval

    init(runtime: ChatGPTHostRuntime = SystemChatGPTHostRuntime(), terminationTimeout: TimeInterval = 5) {
        self.runtime = runtime
        self.terminationTimeout = terminationTimeout
    }

    func terminateApplication(at target: ChatGPTHostTarget) async -> ChatGPTHostTerminationResult {
        let targetURL = target.applicationURL.resolvingSymlinksInPath().standardizedFileURL
        let runningURLs = await runtime.runningApplicationURLs()
        guard runningURLs.contains(where: {
            $0.resolvingSymlinksInPath().standardizedFileURL == targetURL
        }) else {
            return .notRunning
        }

        guard await runtime.requestTermination(applicationAt: targetURL) else {
            return .refused
        }
        return await runtime.waitForTermination(applicationAt: targetURL, timeout: terminationTimeout)
            ? .terminated
            : .timedOut
    }

    func launchApplication(at target: ChatGPTHostTarget) async throws {
        try await runtime.launch(applicationAt: target.applicationURL)
    }
}

final class SystemChatGPTHostRuntime: ChatGPTHostRuntime {
    func runningApplicationURLs() async -> [URL] {
        NSWorkspace.shared.runningApplications.compactMap(\.bundleURL)
    }

    func requestTermination(applicationAt appURL: URL) async -> Bool {
        let targetURL = appURL.resolvingSymlinksInPath().standardizedFileURL
        guard let application = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == targetURL
        }) else {
            return false
        }
        return application.terminate()
    }

    func waitForTermination(applicationAt appURL: URL, timeout: TimeInterval) async -> Bool {
        let targetURL = appURL.resolvingSymlinksInPath().standardizedFileURL
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let stillRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == targetURL
            }
            if !stillRunning { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return !NSWorkspace.shared.runningApplications.contains {
            $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == targetURL
        }
    }

    func launch(applicationAt appURL: URL) async throws {
        _ = try await NSWorkspace.shared.openApplication(
            at: appURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}
