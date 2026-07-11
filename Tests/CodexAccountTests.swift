import Foundation

enum CodexAccountTests {
    final class FailingWriter: CodexAccountDataWriting {
        var failingPath: URL?

        func write(_ data: Data, to url: URL) throws {
            if url == failingPath {
                throw TestError.forcedWriteFailure
            }
            try LiveCodexAccountDataWriter().write(data, to: url)
        }
    }

    final class MockUsageClient: CodexUsageClient {
        struct Request {
            let token: String
            let accountID: String?
        }

        var requests: [Request] = []
        var responses: [AppUsage] = []

        func fetchCodex(context: CodexAuthContext) async -> AppUsage {
            requests.append(Request(token: context.accessToken, accountID: context.chatgptAccountId))
            return responses.isEmpty
                ? AppUsage(fiveHour: .unknown, weekly: .unknown)
                : responses.removeFirst()
        }
    }

    static func run() async -> Int {
        var failures = 0

        func expect(_ condition: Bool, _ label: String) {
            if condition {
                print("PASS \(label)")
            } else {
                print("FAIL \(label)")
                failures += 1
            }
        }

        let authJSON = sampleAuthJSON(
            accessToken: "access-a",
            accountID: "acct-workspace-1",
            principalID: "principal-1",
            idToken: makeJWT([
                "email": "jared@example.com",
                "chatgpt_user_id": "user-1",
                "chatgpt_account_id": "acct-workspace-1",
                "chatgpt_plan_type": "pro",
            ])
        )

        do {
            let parsed = try CodexAuthParser.parseAuth(data: authJSON)
            expect(parsed.accessToken == "access-a", "parser extracts access token")
            expect(parsed.chatgptAccountId == "acct-workspace-1", "parser prefers chatgpt account id")
            expect(parsed.identity.email == "jared@example.com", "parser extracts email")
            expect(parsed.identity.plan == "pro", "parser extracts plan")
            expect(parsed.identity.confidence == .strong, "parser marks user+account identity strong")

            let keyAgain = try CodexAuthParser.parseAuth(data: authJSON).accountKey
            expect(parsed.accountKey == keyAgain, "account key is deterministic")
            expect(!parsed.accountKey.contains("jared@example.com"), "account key does not expose email")
        } catch {
            expect(false, "parser handles representative auth JSON: \(error)")
        }

        do {
            let noAccess = sampleAuthJSON(accessToken: nil, accountID: "acct", principalID: "principal", idToken: makeJWT([:]))
            _ = try CodexAuthParser.parseAuth(data: noAccess)
            expect(false, "parser rejects missing access token")
        } catch {
            expect(true, "parser rejects missing access token")
        }

        let defaultLabel = CodexAccountStore.defaultLabel(forAccountKey: "account-key-123456")
        expect(defaultLabel == "Codex Account 123456", "default label uses a non-identifying account-key suffix")
        let legacyIdentityLabel = CodexAccountStore.displayLabel(for: CodexAccountRecord(
            accountKey: "account-key-123456",
            chatgptUserId: "user-123456",
            chatgptAccountId: "acct-workspace-123456",
            principalId: "principal-123456",
            identityConfidence: .strong,
            email: "jared@example.com",
            label: "jared@example.com",
            plan: "pro",
            createdAt: Date(timeIntervalSince1970: 0),
            lastUsedAt: nil,
            lastUsageAt: nil,
            lastUsage: nil,
            lastError: nil
        ))
        expect(!legacyIdentityLabel.contains("@") && !legacyIdentityLabel.contains("acct-workspace-123456"), "display label omits email and full account ID")

        do {
            let root = try makeTempRoot()
            let paths = CodexAccountPaths(root: root)
            try FileManager.default.createDirectory(at: paths.codexDirectory, withIntermediateDirectories: true)
            try authJSON.write(to: paths.activeAuthPath)

            let store = try CodexAccountStore(paths: paths)
            try store.importCurrentAuth(label: "Personal")

            expect(store.registry.accounts.count == 1, "import creates one account")
            let imported = try require(store.registry.accounts.first, "imported account")
            expect(imported.label == "Personal", "import stores label")
            expect(imported.email == "jared@example.com", "import stores email")
            expect(FileManager.default.fileExists(atPath: paths.snapshotPath(for: imported.accountKey).path), "import writes snapshot")

            let secondAuth = sampleAuthJSON(
                accessToken: "access-b",
                accountID: "acct-workspace-2",
                principalID: "principal-2",
                idToken: makeJWT([
                    "email": "jared@example.com",
                    "chatgpt_user_id": "user-1",
                    "chatgpt_account_id": "acct-workspace-2",
                    "chatgpt_plan_type": "team",
                ])
            )
            try secondAuth.write(to: paths.activeAuthPath)
            try store.importCurrentAuth(label: "Business")

            let personalKey = imported.accountKey
            let businessKey = try require(store.registry.activeAccountKey, "business active key")
            expect(personalKey != businessKey, "same email with different account id creates distinct keys")

            try store.switchToAccount(personalKey)
            let activeAfterSwitch = try CodexAuthParser.parseAuth(data: Data(contentsOf: paths.activeAuthPath))
            expect(activeAfterSwitch.accessToken == "access-a", "switch replaces active auth with selected snapshot")
            expect(store.registry.activeAccountKey == personalKey, "switch updates active account key")
            expect(store.registry.previousActiveAccountKey == businessKey, "switch records previous active account")
        } catch {
            expect(false, "registry import and switch flow: \(error)")
        }

        do {
            let root = try makeTempRoot()
            let paths = CodexAccountPaths(root: root)
            try FileManager.default.createDirectory(at: paths.codexDirectory, withIntermediateDirectories: true)
            try authJSON.write(to: paths.activeAuthPath)

            let store = try CodexAccountStore(paths: paths)
            try store.importCurrentAuth(label: "Personal")

            let client = MockUsageClient()
            client.responses = [
                AppUsage(
                    fiveHour: WindowUsage(usedPercent: 0.25, resetAt: Date(timeIntervalSince1970: 100), error: nil),
                    weekly: WindowUsage(usedPercent: 0.50, resetAt: Date(timeIntervalSince1970: 200), error: nil),
                    plan: "pro"
                )
            ]

            await store.refreshAllUsage(client: client)

            expect(client.requests.count == 1, "refresh all sends one request for one snapshot")
            expect(client.requests.first?.token == "access-a", "refresh all uses snapshot token")
            expect(client.requests.first?.accountID == "acct-workspace-1", "refresh all passes account id")
            expect(store.registry.accounts.first?.lastUsage?.fiveHour.usedPercent == 0.25, "refresh all stores usage snapshot")
            expect(store.registry.accounts.first?.plan == "pro", "refresh all updates plan")
        } catch {
            expect(false, "refresh all stores usage: \(error)")
        }

        do {
            let root = try makeTempRoot()
            let paths = CodexAccountPaths(root: root)
            try FileManager.default.createDirectory(at: paths.codexDirectory, withIntermediateDirectories: true)
            try authJSON.write(to: paths.activeAuthPath)

            let store = try CodexAccountStore(paths: paths)
            try store.importCurrentAuth(label: "Personal")
            let personalKey = try require(store.registry.activeAccountKey, "personal active key")

            let secondAuth = sampleAuthJSON(
                accessToken: "access-b",
                accountID: "acct-workspace-2",
                principalID: "principal-2",
                idToken: makeJWT([
                    "email": "jared@example.com",
                    "chatgpt_user_id": "user-1",
                    "chatgpt_account_id": "acct-workspace-2",
                    "chatgpt_plan_type": "team",
                ])
            )
            try secondAuth.write(to: paths.activeAuthPath)
            try store.importCurrentAuth(label: "Business")

            let client = MockUsageClient()
            client.responses = [
                AppUsage(fiveHour: .unknown, weekly: .unknown),
                AppUsage(fiveHour: .unknown, weekly: .unknown),
            ]
            await store.refreshAllUsage(client: client)

            expect(
                Set(client.requests.compactMap(\.accountID)) == Set(["acct-workspace-1", "acct-workspace-2"]),
                "refresh all isolates both account contexts"
            )
            expect(store.registry.accounts.count == 2, "refresh all retains both accounts")
            expect(store.registry.accounts.contains(where: { $0.accountKey == personalKey }), "refresh all retains personal account")
        } catch {
            expect(false, "refresh all isolates multiple accounts: \(error)")
        }

        do {
            let root = try makeTempRoot()
            let paths = CodexAccountPaths(root: root)
            try FileManager.default.createDirectory(at: paths.codexDirectory, withIntermediateDirectories: true)
            try authJSON.write(to: paths.activeAuthPath)

            let setupStore = try CodexAccountStore(paths: paths)
            try setupStore.importCurrentAuth(label: "Personal")
            let personalKey = try require(setupStore.registry.activeAccountKey, "personal recovery key")

            let secondAuth = sampleAuthJSON(
                accessToken: "access-b",
                accountID: "acct-workspace-2",
                principalID: "principal-2",
                idToken: makeJWT([
                    "email": "jared@example.com",
                    "chatgpt_user_id": "user-1",
                    "chatgpt_account_id": "acct-workspace-2",
                    "chatgpt_plan_type": "team",
                ])
            )
            try secondAuth.write(to: paths.activeAuthPath)
            try setupStore.importCurrentAuth(label: "Business")
            let previousKey = try require(setupStore.registry.activeAccountKey, "business recovery key")

            let activeAuthBeforeFailure = try Data(contentsOf: paths.activeAuthPath)
            let registryBytesBeforeFailure = try Data(contentsOf: paths.registryPath)
            let personalSnapshotBeforeFailure = try Data(contentsOf: paths.snapshotPath(for: personalKey))
            let businessSnapshotBeforeFailure = try Data(contentsOf: paths.snapshotPath(for: previousKey))

            let writer = FailingWriter()
            writer.failingPath = paths.registryPath
            let store = try CodexAccountStore(paths: paths, writer: writer)

            do {
                try store.switchToAccount(personalKey)
                expect(false, "switch throws when registry write fails")
            } catch TestError.forcedWriteFailure {
                expect(true, "switch throws original registry write failure")
            } catch {
                expect(false, "switch retains original registry write failure: \(error)")
            }

            expect(
                try Data(contentsOf: paths.activeAuthPath) == activeAuthBeforeFailure,
                "switch restores active auth when registry write fails"
            )
            expect(store.registry.activeAccountKey == previousKey, "switch restores in-memory active account when registry write fails")
            expect(
                try Data(contentsOf: paths.registryPath) == registryBytesBeforeFailure,
                "switch preserves on-disk registry when registry write fails"
            )
            expect(
                try Data(contentsOf: paths.snapshotPath(for: personalKey)) == personalSnapshotBeforeFailure,
                "switch preserves selected account snapshot when registry write fails"
            )
            expect(
                try Data(contentsOf: paths.snapshotPath(for: previousKey)) == businessSnapshotBeforeFailure,
                "switch preserves existing account snapshots when registry write fails"
            )
            expect(
                store.lastError == CodexAccountError.inconsistentSwitchState.localizedDescription,
                "fail-before-replace registry failure does not require durable recovery"
            )
        } catch {
            expect(false, "switch recovers from storage failure: \(error)")
        }

        do {
            let root = try makeTempRoot()
            let paths = CodexAccountPaths(root: root)
            try FileManager.default.createDirectory(at: paths.codexDirectory, withIntermediateDirectories: true)
            try authJSON.write(to: paths.activeAuthPath)

            let setupStore = try CodexAccountStore(paths: paths)
            try setupStore.importCurrentAuth(label: "Personal")
            let personalKey = try require(setupStore.registry.activeAccountKey, "personal unknown recovery key")

            let businessAuth = sampleAuthJSON(
                accessToken: "access-b",
                accountID: "acct-workspace-2",
                principalID: "principal-2",
                idToken: makeJWT([
                    "email": "jared@example.com",
                    "chatgpt_user_id": "user-1",
                    "chatgpt_account_id": "acct-workspace-2",
                    "chatgpt_plan_type": "team",
                ])
            )
            try businessAuth.write(to: paths.activeAuthPath)
            try setupStore.importCurrentAuth(label: "Business")
            let businessKey = try require(setupStore.registry.activeAccountKey, "business unknown recovery key")

            let unregisteredAuth = sampleAuthJSON(
                accessToken: "access-unregistered",
                accountID: "acct-workspace-3",
                principalID: "principal-3",
                idToken: makeJWT([
                    "email": "jared@example.com",
                    "chatgpt_user_id": "user-1",
                    "chatgpt_account_id": "acct-workspace-3",
                    "chatgpt_plan_type": "enterprise",
                ])
            )
            let unknownKey = try CodexAuthParser.parseAuth(data: unregisteredAuth).accountKey
            try unregisteredAuth.write(to: paths.activeAuthPath)

            let activeAuthBeforeFailure = try Data(contentsOf: paths.activeAuthPath)
            let registryBytesBeforeFailure = try Data(contentsOf: paths.registryPath)
            let personalSnapshotBeforeFailure = try Data(contentsOf: paths.snapshotPath(for: personalKey))
            let businessSnapshotBeforeFailure = try Data(contentsOf: paths.snapshotPath(for: businessKey))

            let writer = FailingWriter()
            writer.failingPath = paths.registryPath
            let store = try CodexAccountStore(paths: paths, writer: writer)

            do {
                try store.switchToAccount(personalKey)
                expect(false, "unknown current auth switch throws when registry write fails")
            } catch TestError.forcedWriteFailure {
                expect(true, "unknown current auth switch throws original registry write failure")
            } catch {
                expect(false, "unknown current auth retains original registry write failure: \(error)")
            }

            expect(
                try Data(contentsOf: paths.activeAuthPath) == activeAuthBeforeFailure,
                "unknown current auth switch restores active auth"
            )
            expect(store.registry.activeAccountKey == businessKey, "unknown current auth switch restores in-memory registry")
            expect(
                try Data(contentsOf: paths.registryPath) == registryBytesBeforeFailure,
                "unknown current auth switch preserves on-disk registry"
            )
            expect(
                try Data(contentsOf: paths.snapshotPath(for: personalKey)) == personalSnapshotBeforeFailure,
                "unknown current auth switch preserves personal snapshot"
            )
            expect(
                try Data(contentsOf: paths.snapshotPath(for: businessKey)) == businessSnapshotBeforeFailure,
                "unknown current auth switch preserves business snapshot"
            )
            expect(
                !FileManager.default.fileExists(atPath: paths.snapshotPath(for: unknownKey).path),
                "unknown current auth switch removes created unknown snapshot"
            )
            expect(
                store.lastError == CodexAccountError.inconsistentSwitchState.localizedDescription,
                "unknown current auth fail-before-replace registry failure does not require durable recovery"
            )
        } catch {
            expect(false, "unknown current auth switch recovers from storage failure: \(error)")
        }

        return failures
    }

    private static func require<T>(_ value: T?, _ label: String) throws -> T {
        guard let value else { throw TestError.missing(label) }
        return value
    }

    private static func makeTempRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-account-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func sampleAuthJSON(
        accessToken: String?,
        accountID: String?,
        principalID: String?,
        idToken: String
    ) -> Data {
        var tokens: [String: Any] = [
            "id_token": idToken,
        ]
        if let accessToken { tokens["access_token"] = accessToken }
        if let accountID { tokens["account_id"] = accountID }
        if let principalID { tokens["principal_id"] = principalID }

        let obj: [String: Any] = [
            "auth_mode": "chatgpt",
            "last_refresh": "2026-07-07T00:00:00Z",
            "tokens": tokens,
        ]
        return try! JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
    }

    private static func makeJWT(_ payload: [String: Any]) -> String {
        let header = try! JSONSerialization.data(withJSONObject: ["alg": "none"], options: [.sortedKeys])
        let body = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        return "\(base64URL(header)).\(base64URL(body)).signature"
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    enum TestError: Error {
        case missing(String)
        case forcedWriteFailure
    }
}
