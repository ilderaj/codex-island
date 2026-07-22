import Foundation

enum CodexUsageWindowUpstreamAdapter: CodexUsageWindowInvoking {
    static func invoke(_ fixture: CodexUsageWindowFixture) async -> AppUsage {
        let codexDirectory = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex")
        try? FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        try? Data("{\"tokens\":{\"access_token\":\"test-token\"}}".utf8)
            .write(to: codexDirectory.appendingPathComponent("auth.json"), options: .atomic)

        CodexUsageWindowURLProtocol.install(responseData: fixture.responseData)
        defer { CodexUsageWindowURLProtocol.uninstall() }
        return await UsageFetcher.fetchCodex()
    }
}

@main
struct CodexUsageWindowUpstreamAdapterRunner {
    static func main() async {
        await CodexUsageWindowContract.run(using: CodexUsageWindowUpstreamAdapter.self)
    }
}
