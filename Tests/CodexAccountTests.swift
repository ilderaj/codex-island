import Foundation

enum CodexAccountTests {
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
    }
}
