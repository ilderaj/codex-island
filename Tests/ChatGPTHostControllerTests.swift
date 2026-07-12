import Foundation

@main
struct ChatGPTHostControllerTests {
    final class FakeHostRuntime: ChatGPTHostRuntime {
        var running: [URL] = []
        var terminationRequests: [URL] = []
        var terminationWaits: [URL] = []
        var launched: [URL] = []
        var acceptsTermination = true
        var terminatesBeforeTimeout = true
        var launchError: Error?

        func runningApplicationURLs() async -> [URL] { running }

        func requestTermination(applicationAt appURL: URL) async -> Bool {
            terminationRequests.append(appURL)
            return acceptsTermination
        }

        func waitForTermination(applicationAt appURL: URL, timeout: TimeInterval) async -> Bool {
            terminationWaits.append(appURL)
            return terminatesBeforeTimeout
        }

        func launch(applicationAt appURL: URL) async throws {
            if let launchError { throw launchError }
            launched.append(appURL)
        }
    }

    struct FixedTargetPolicy: ChatGPTHostTargetValidating {
        let target: ChatGPTHostTarget

        func validateTarget() throws -> ChatGPTHostTarget { target }
    }

    final class SequencedTargetPolicy: ChatGPTHostTargetValidating {
        private var targets: [ChatGPTHostTarget]

        init(_ targets: [ChatGPTHostTarget]) {
            self.targets = targets
        }

        func validateTarget() throws -> ChatGPTHostTarget {
            guard !targets.isEmpty else { throw TestError.forcedHostFailure }
            return targets.removeFirst()
        }
    }

    enum TestError: LocalizedError {
        case forcedHostFailure

        var errorDescription: String? {
            switch self {
            case .forcedHostFailure: return "forced host failure"
            }
        }
    }

    @MainActor
    static func main() async {
        var failures = 0

        func expect(_ condition: Bool, _ label: String) {
            if condition {
                print("PASS \(label)")
            } else {
                print("FAIL \(label)")
                failures += 1
            }
        }

        do {
            let root = try makeTemporaryRoot()
            let realAppURL = try makeChatGPTApp(in: root)
            let symlinkURL = root.appendingPathComponent("ChatGPT Alias.app")
            try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: realAppURL)
            let target = try ChatGPTHostTarget.validate(applicationURL: symlinkURL)
            expect(target.applicationURL == realAppURL.standardizedFileURL, "policy resolves a ChatGPT app symlink")
            expect(target.executableURL.path.hasSuffix("Contents/MacOS/ChatGPT"), "policy targets the expected executable path")
        } catch {
            expect(false, "policy resolves a ChatGPT app symlink: \(error)")
        }

        do {
            let root = try makeTemporaryRoot()
            let wrongNameURL = try makeChatGPTApp(in: root, name: "Other.app")
            do {
                _ = try ChatGPTHostTarget.validate(applicationURL: wrongNameURL)
                expect(false, "policy rejects a differently named app")
            } catch {
                expect(true, "policy rejects a differently named app")
            }

            let wrongExecutableURL = try makeChatGPTApp(in: root, executableMetadata: "Other")
            do {
                _ = try ChatGPTHostTarget.validate(applicationURL: wrongExecutableURL)
                expect(false, "policy rejects wrong executable metadata")
            } catch {
                expect(true, "policy rejects wrong executable metadata")
            }

            let missingExecutableURL = try makeChatGPTApp(in: root.appendingPathComponent("missing"))
            try FileManager.default.removeItem(
                at: missingExecutableURL.appendingPathComponent("Contents/MacOS/ChatGPT")
            )
            do {
                _ = try ChatGPTHostTarget.validate(applicationURL: missingExecutableURL)
                expect(false, "policy rejects a missing executable path")
            } catch {
                expect(true, "policy rejects a missing executable path")
            }
        } catch {
            expect(false, "policy rejects invalid app metadata: \(error)")
        }

        do {
            let root = try makeTemporaryRoot()
            let appURL = try makeChatGPTApp(in: root)
            let target = try ChatGPTHostTarget.validate(applicationURL: appURL)
            let fake = FakeHostRuntime()
            fake.running = [root.appendingPathComponent("Unrelated.app"), appURL]
            let controller = ChatGPTHostController(runtime: fake)

            let result = await controller.terminateApplication(at: target)
            expect(result == .terminated, "controller terminates a matching running app")
            expect(fake.terminationRequests == [target.applicationURL], "controller filters running apps by exact resolved URL")
            expect(fake.terminationWaits == [target.applicationURL], "controller waits only for the exact target")
        } catch {
            expect(false, "controller filters running apps by exact resolved URL: \(error)")
        }

        do {
            let root = try makeTemporaryRoot()
            let appURL = try makeChatGPTApp(in: root)
            let target = try ChatGPTHostTarget.validate(applicationURL: appURL)
            let fake = FakeHostRuntime()
            fake.running = [appURL]
            fake.acceptsTermination = false
            let coordinator = try makeCoordinator(root: root, target: target, runtime: fake)

            await coordinator.apply(accountKey: try alternateAccountKey(for: coordinator.store))
            expect(coordinator.state == .terminationFailed("ChatGPT refused to quit; reopen it manually"), "coordinator reports termination refusal")
            expect(fake.launched.isEmpty, "refusal does not launch the host")
            expect(!coordinator.state.claimsAuthReload, "refusal never claims auth reload")
        } catch {
            expect(false, "coordinator reports termination refusal: \(error)")
        }

        do {
            let root = try makeTemporaryRoot()
            let appURL = try makeChatGPTApp(in: root)
            let target = try ChatGPTHostTarget.validate(applicationURL: appURL)
            let fake = FakeHostRuntime()
            fake.running = [appURL]
            fake.terminatesBeforeTimeout = false
            let coordinator = try makeCoordinator(root: root, target: target, runtime: fake)

            await coordinator.apply(accountKey: try alternateAccountKey(for: coordinator.store))
            expect(coordinator.state == .terminationFailed("ChatGPT did not quit in time; reopen it manually"), "coordinator reports termination timeout")
            expect(fake.launched.isEmpty, "timeout does not launch the host")
            expect(!coordinator.state.claimsAuthReload, "timeout never claims auth reload")
        } catch {
            expect(false, "coordinator reports termination timeout: \(error)")
        }

        do {
            let root = try makeTemporaryRoot()
            let appURL = try makeChatGPTApp(in: root)
            let target = try ChatGPTHostTarget.validate(applicationURL: appURL)
            let fake = FakeHostRuntime()
            let coordinator = try makeCoordinator(
                root: root,
                target: target,
                runtime: fake,
                policy: SequencedTargetPolicy([])
            )
            let originalAccountKey = coordinator.store.registry.activeAccountKey

            await coordinator.apply(accountKey: try alternateAccountKey(for: coordinator.store))
            expect(
                coordinator.state == .terminationFailed("ChatGPT target could not be verified; reopen it manually"),
                "initial target validation prevents a local switch"
            )
            expect(
                coordinator.store.registry.activeAccountKey == originalAccountKey,
                "initial target validation preserves the active account"
            )
            expect(
                !coordinator.didSwitchLocallyForCurrentApply,
                "initial target validation does not expose a local restore path"
            )
            expect(
                fake.terminationRequests.isEmpty && fake.launched.isEmpty,
                "initial target validation performs no host I/O"
            )
        } catch {
            expect(false, "initial target validation prevents a local switch: \(error)")
        }

        do {
            let root = try makeTemporaryRoot()
            let firstTarget = try ChatGPTHostTarget.validate(
                applicationURL: try makeChatGPTApp(in: root.appendingPathComponent("first"))
            )
            let secondTarget = try ChatGPTHostTarget.validate(
                applicationURL: try makeChatGPTApp(in: root.appendingPathComponent("second"))
            )
            let fake = FakeHostRuntime()
            let coordinator = try makeCoordinator(
                root: root,
                target: firstTarget,
                runtime: fake,
                policy: SequencedTargetPolicy([firstTarget, secondTarget])
            )

            await coordinator.apply(accountKey: try alternateAccountKey(for: coordinator.store))
            expect(
                coordinator.state == .terminationFailed("ChatGPT target changed; reopen it manually"),
                "coordinator rejects a target that changes after local switching"
            )
            expect(fake.terminationRequests.isEmpty && fake.launched.isEmpty, "target mismatch performs no host action")
            expect(!coordinator.state.claimsAuthReload, "target mismatch never claims auth reload")
        } catch {
            expect(false, "coordinator rejects a target that changes after local switching: \(error)")
        }

        do {
            let root = try makeTemporaryRoot()
            let appURL = try makeChatGPTApp(in: root)
            let target = try ChatGPTHostTarget.validate(applicationURL: appURL)
            let fake = FakeHostRuntime()
            fake.running = [appURL]
            let coordinator = try makeCoordinator(root: root, target: target, runtime: fake)

            await coordinator.apply(accountKey: try alternateAccountKey(for: coordinator.store))
            expect(
                coordinator.state == .authReloadUnverified,
                "successful launch leaves host auth reload unverified"
            )
            expect(
                coordinator.permitsSubsequentExplicitApply,
                "post-success state permits an explicit subsequent apply command"
            )
        } catch {
            expect(false, "post-success state permits an explicit subsequent apply command: \(error)")
        }

        do {
            let root = try makeTemporaryRoot()
            let appURL = try makeChatGPTApp(in: root)
            let target = try ChatGPTHostTarget.validate(applicationURL: appURL)
            let fake = FakeHostRuntime()
            fake.running = [appURL]
            fake.launchError = TestError.forcedHostFailure
            let coordinator = try makeCoordinator(root: root, target: target, runtime: fake)
            let key = try alternateAccountKey(for: coordinator.store)

            await coordinator.apply(accountKey: key)
            expect(coordinator.state == .launchFailed("forced host failure"), "coordinator reports launch failure")
            expect(fake.terminationRequests == [target.applicationURL], "launch failure terminates only the exact target once")
            expect(!coordinator.state.claimsAuthReload, "launch failure never claims auth reload")

            fake.launchError = nil
            await coordinator.retryLaunch()
            expect(fake.terminationRequests == [target.applicationURL], "retry launch does not repeat termination")
            expect(fake.launched == [target.applicationURL], "retry launches the already validated target")
            expect(coordinator.state == .authReloadUnverified, "retry leaves host auth reload unverified")
            expect(!coordinator.state.claimsAuthReload, "retry never claims auth reload")

            let hostActionCount = fake.terminationRequests.count + fake.launched.count
            await coordinator.restorePreviousAccount()
            expect(
                coordinator.requiresManualHostLaunchInstruction,
                "restoring local auth after a terminated-host launch failure requires manual host launch"
            )
            expect(
                fake.terminationRequests.count + fake.launched.count == hostActionCount,
                "restoring the previous account performs no host I/O"
            )
        } catch {
            expect(false, "coordinator retries launch without repeat termination: \(error)")
        }

        if failures > 0 {
            print("\(failures) failure(s)")
            exit(1)
        }
        print("all ChatGPT host tests passed")
    }

    @MainActor
    private static func makeCoordinator(
        root: URL,
        target: ChatGPTHostTarget,
        runtime: FakeHostRuntime,
        policy: ChatGPTHostTargetValidating? = nil
    ) throws -> CodexAccountApplyCoordinator {
        let paths = CodexAccountPaths(root: root.appendingPathComponent("accounts-root"))
        try FileManager.default.createDirectory(at: paths.codexDirectory, withIntermediateDirectories: true)

        let firstAuth = sampleAuthJSON(token: "first", accountID: "account-first")
        let secondAuth = sampleAuthJSON(token: "second", accountID: "account-second")
        try firstAuth.write(to: paths.activeAuthPath)
        let store = try CodexAccountStore(paths: paths)
        try store.importCurrentAuth(label: "First")
        try secondAuth.write(to: paths.activeAuthPath)
        try store.importCurrentAuth(label: "Second")

        return CodexAccountApplyCoordinator(
            store: store,
            policy: policy ?? FixedTargetPolicy(target: target),
            controller: ChatGPTHostController(runtime: runtime)
        )
    }

    private static func alternateAccountKey(for store: CodexAccountStore) throws -> String {
        guard let key = store.registry.previousActiveAccountKey else {
            throw TestError.forcedHostFailure
        }
        return key
    }

    private static func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func makeChatGPTApp(
        in root: URL,
        name: String = "ChatGPT.app",
        executableMetadata: String = "ChatGPT"
    ) throws -> URL {
        let appURL = root.appendingPathComponent(name, isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let macOSURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict><key>CFBundleExecutable</key><string>\(executableMetadata)</string></dict></plist>
        """
        try plist.data(using: .utf8)!.write(to: contentsURL.appendingPathComponent("Info.plist"))
        let executableURL = macOSURL.appendingPathComponent("ChatGPT")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executableURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)
        return appURL.standardizedFileURL
    }

    private static func sampleAuthJSON(token: String, accountID: String) -> Data {
        """
        {
          "auth_mode": "chatgpt",
          "tokens": {
            "access_token": "\(token)",
            "account_id": "\(accountID)"
          }
        }
        """.data(using: .utf8)!
    }
}
