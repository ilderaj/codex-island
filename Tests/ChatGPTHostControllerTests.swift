import Foundation

@main
struct ChatGPTHostControllerTests {
    final class FakeHostRuntime: ChatGPTHostRuntime {
        var running: [URL] = []
        var terminationAccepted = true
        var terminates = true
        var launchError: Error?
        var terminationRequests: [URL] = []
        var launches: [URL] = []

        func runningApplicationURLs() async -> [URL] { running }

        func requestTermination(applicationAt appURL: URL) async -> Bool {
            terminationRequests.append(appURL)
            return terminationAccepted
        }

        func waitForTermination(applicationAt appURL: URL, timeout: TimeInterval) async -> Bool {
            terminates
        }

        func launch(applicationAt appURL: URL) async throws {
            if let launchError { throw launchError }
            launches.append(appURL)
        }
    }

    final class ControlledWriter: CodexAccountDataWriting {
        var failNextWrite = false
        var writeCount = 0

        func reset() { writeCount = 0 }

        func write(_ data: Data, to url: URL) throws {
            writeCount += 1
            if failNextWrite {
                failNextWrite = false
                throw TestError.forced
            }
            try data.write(to: url, options: .atomic)
        }
    }

    struct FixedPolicy: ChatGPTHostTargetValidating {
        let target: ChatGPTHostTarget
        func validateTarget() throws -> ChatGPTHostTarget { target }
    }

    final class SequencedPolicy: ChatGPTHostTargetValidating {
        var targets: [ChatGPTHostTarget]
        init(_ targets: [ChatGPTHostTarget]) { self.targets = targets }
        func validateTarget() throws -> ChatGPTHostTarget {
            guard !targets.isEmpty else { throw TestError.forced }
            return targets.removeFirst()
        }
    }

    enum TestError: LocalizedError {
        case forced
        var errorDescription: String? { "forced failure" }
    }

    @MainActor
    static func main() async {
        var failures = 0
        func expect(_ condition: @autoclosure () -> Bool, _ label: String) {
            if condition() { print("PASS \(label)") }
            else { print("FAIL \(label)"); failures += 1 }
        }

        do {
            let fixture = try makeFixture()
            fixture.runtime.running = [fixture.target.applicationURL]
            fixture.runtime.terminationAccepted = false
            let before = fixture.store.registry.activeAccountKey
            let bytes = try protectedBytes(fixture)
            await fixture.coordinator.apply(accountKey: fixture.alternateKey)
            let after = try protectedBytes(fixture)
            expect(fixture.coordinator.state == .cancelled, "refusal becomes cancelled")
            expect(fixture.store.registry.activeAccountKey == before, "refusal writes no active auth or registry")
            expect(after == bytes, "refusal preserves auth and registry bytes")
            expect(fixture.writer.writeCount == 0, "refusal performs zero writer calls")
            expect(fixture.runtime.launches.isEmpty, "refusal launches zero hosts")
        } catch {
            expect(false, "refusal fixture: \(error)")
        }

        do {
            let fixture = try makeFixture()
            fixture.runtime.running = [fixture.target.applicationURL]
            fixture.runtime.terminates = false
            let before = fixture.store.registry.activeAccountKey
            let bytes = try protectedBytes(fixture)
            await fixture.coordinator.apply(accountKey: fixture.alternateKey)
            let after = try protectedBytes(fixture)
            expect(fixture.coordinator.state == .cancelled, "timeout becomes cancelled")
            expect(fixture.store.registry.activeAccountKey == before, "timeout writes no active auth or registry")
            expect(after == bytes, "timeout preserves auth and registry bytes")
            expect(fixture.writer.writeCount == 0, "timeout performs zero writer calls")
            expect(fixture.runtime.launches.isEmpty, "timeout launches zero hosts")
        } catch {
            expect(false, "timeout fixture: \(error)")
        }

        do {
            let fixture = try makeFixture()
            let before = fixture.store.registry.activeAccountKey
            await fixture.coordinator.apply(accountKey: fixture.alternateKey)
            expect(fixture.store.registry.activeAccountKey != before, "not-running host switches locally")
            expect(fixture.runtime.terminationRequests.isEmpty, "not-running host requests no termination")
            expect(fixture.runtime.launches.isEmpty, "not-running host does not launch")
            expect(fixture.coordinator.state == .localSwitchComplete, "not-running switch remains locally complete")
        } catch {
            expect(false, "not-running fixture: \(error)")
        }

        do {
            let fixture = try makeFixture()
            fixture.runtime.running = [fixture.target.applicationURL]
            await fixture.coordinator.apply(accountKey: fixture.alternateKey)
            expect(fixture.store.registry.activeAccountKey == fixture.alternateKey, "terminated host switches exactly once")
            expect(fixture.runtime.terminationRequests == [fixture.target.applicationURL], "running host uses exact termination target")
            expect(fixture.runtime.launches == [fixture.target.applicationURL], "terminated host relaunches once")
            expect(fixture.coordinator.state == .authReloadUnverified, "relaunch remains auth-reload unverified")
            expect(fixture.writer.writeCount == 2, "terminated host performs one local transaction")
        } catch {
            expect(false, "terminated fixture: \(error)")
        }

        do {
            let fixture = try makeFixture()
            fixture.runtime.running = [fixture.target.applicationURL]
            fixture.writer.failNextWrite = true
            let before = fixture.store.registry.activeAccountKey
            await fixture.coordinator.apply(accountKey: fixture.alternateKey)
            expect(fixture.store.registry.activeAccountKey == before, "local switch failure restores the original account")
            expect(fixture.runtime.launches == [fixture.target.applicationURL], "local switch failure reopens the original host")
            expect({
                if case .localSwitchFailed = fixture.coordinator.state { return true }
                return false
            }(), "local switch failure never claims success")
        } catch {
            expect(false, "local switch failure fixture: \(error)")
        }

        do {
            let fixture = try makeFixture()
            fixture.runtime.running = [fixture.target.applicationURL]
            fixture.runtime.launchError = TestError.forced
            await fixture.coordinator.apply(accountKey: fixture.alternateKey)
            expect({
                if case .launchFailed = fixture.coordinator.state { return true }
                return false
            }(), "launch failure exposes local-switched host-closed state")
            fixture.runtime.launchError = nil
            await fixture.coordinator.retryLaunch()
            expect(fixture.coordinator.state == .authReloadUnverified, "retry launch preserves the verified target")
            expect(fixture.runtime.launches == [fixture.target.applicationURL], "retry launch performs exactly one verified relaunch")
        } catch {
            expect(false, "launch failure retry fixture: \(error)")
        }

        do {
            let fixture = try makeFixture()
            fixture.runtime.running = [fixture.target.applicationURL]
            fixture.runtime.launchError = TestError.forced
            let original = fixture.store.registry.activeAccountKey
            await fixture.coordinator.apply(accountKey: fixture.alternateKey)
            expect({
                if case .launchFailed = fixture.coordinator.state { return true }
                return false
            }(), "restore fixture reaches launch failed before recovery")
            let launchCount = fixture.runtime.launches.count
            await fixture.coordinator.restorePreviousAccount()
            expect(fixture.store.registry.activeAccountKey == original, "restore previous reactivates the original account")
            expect(fixture.coordinator.state == .localSwitchComplete, "restore previous ends in local switch complete")
            expect(fixture.coordinator.restorationRequiresManualHostLaunch, "restore previous flags manual host relaunch")
            expect(fixture.runtime.launches.count == launchCount, "restore previous does not relaunch ChatGPT")
        } catch {
            expect(false, "launch failure restore fixture: \(error)")
        }

        do {
            let fixture = try makeFixture()
            let changed = try makeTarget(in: fixture.root.appendingPathComponent("changed"))
            let policy = SequencedPolicy([fixture.target, changed])
            let coordinator = CodexAccountApplyCoordinator(
                store: fixture.store,
                policy: policy,
                controller: ChatGPTHostController(runtime: fixture.runtime)
            )
            let before = fixture.store.registry.activeAccountKey
            let bytes = try protectedBytes(fixture)
            await coordinator.apply(accountKey: fixture.alternateKey)
            let after = try protectedBytes(fixture)
            expect(coordinator.state == .targetDrift, "target drift has a distinct state")
            expect(fixture.store.registry.activeAccountKey == before, "target drift writes nothing")
            expect(after == bytes, "target drift preserves auth and registry bytes")
            expect(fixture.writer.writeCount == 0, "target drift performs zero writer calls")
            expect(fixture.runtime.terminationRequests.isEmpty && fixture.runtime.launches.isEmpty, "target drift performs no host action")
        } catch {
            expect(false, "target drift fixture: \(error)")
        }

        if failures > 0 { exit(1) }
        print("all ChatGPT host tests passed")
    }

    @MainActor
    private static func makeFixture() throws -> (
        root: URL,
        target: ChatGPTHostTarget,
        store: CodexAccountStore,
        alternateKey: String,
        writer: ControlledWriter,
        runtime: FakeHostRuntime,
        coordinator: CodexAccountApplyCoordinator
    ) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let target = try makeTarget(in: root)
        let paths = CodexAccountPaths(root: root.appendingPathComponent("codex-home"))
        try FileManager.default.createDirectory(at: paths.codexDirectory, withIntermediateDirectories: true)
        try auth(token: "first", account: "first").write(to: paths.activeAuthPath)
        let writer = ControlledWriter()
        let store = try CodexAccountStore(paths: paths, writer: writer)
        try store.importCurrentAuth(label: "First")
        try auth(token: "second", account: "second").write(to: paths.activeAuthPath)
        try store.importCurrentAuth(label: "Second")
        let alternateKey = try unwrap(store.registry.previousActiveAccountKey)
        writer.reset()
        let runtime = FakeHostRuntime()
        let coordinator = CodexAccountApplyCoordinator(
            store: store,
            policy: FixedPolicy(target: target),
            controller: ChatGPTHostController(runtime: runtime)
        )
        return (root, target, store, alternateKey, writer, runtime, coordinator)
    }

    private static func protectedBytes(_ fixture: (root: URL, target: ChatGPTHostTarget, store: CodexAccountStore, alternateKey: String, writer: ControlledWriter, runtime: FakeHostRuntime, coordinator: CodexAccountApplyCoordinator)) throws -> (Data, Data) {
        (try Data(contentsOf: fixture.store.paths.activeAuthPath), try Data(contentsOf: fixture.store.paths.registryPath))
    }

    private static func makeTarget(in root: URL) throws -> ChatGPTHostTarget {
        let app = root.appendingPathComponent("ChatGPT.app")
        let contents = app.appendingPathComponent("Contents")
        let executable = contents.appendingPathComponent("MacOS/ChatGPT")
        try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>CFBundleExecutable</key><string>ChatGPT</string></dict></plist>".utf8)
            .write(to: contents.appendingPathComponent("Info.plist"))
        try Data("#/bin/sh\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        return try ChatGPTHostTarget.validate(applicationURL: app)
    }

    private static func auth(token: String, account: String) -> Data {
        Data("{\"auth_mode\":\"chatgpt\",\"tokens\":{\"access_token\":\"\(token)\",\"account_id\":\"\(account)\"}}".utf8)
    }

    private static func unwrap<T>(_ value: T?) throws -> T {
        guard let value else { throw TestError.forced }
        return value
    }
}
