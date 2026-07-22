import Foundation

protocol CodexUsageWindowInvoking {
    static func invoke(_ fixture: CodexUsageWindowFixture) async -> AppUsage
}

struct CodexUsageWindowFixture {
    let responseData: Data

    init(_ json: String) {
        responseData = Data(json.utf8)
    }
}

final class CodexUsageWindowURLProtocol: URLProtocol {
    nonisolated(unsafe) private static var responseData = Data()
    private static let responseLock = NSLock()

    static func install(responseData: Data) {
        responseLock.lock()
        Self.responseData = responseData
        responseLock.unlock()
        URLProtocol.registerClass(Self.self)
    }

    static func uninstall() {
        URLProtocol.unregisterClass(Self.self)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "chatgpt.com"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.responseLock.lock()
        let data = Self.responseData
        Self.responseLock.unlock()

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

enum CodexUsageWindowContract {
    private static let reversedWindows = CodexUsageWindowFixture("""
    {"rate_limit":{"primary_window":{"limit_window_seconds":604800,"used_percent":62,"reset_at":1900000000},"secondary_window":{"limit_window_seconds":18000,"used_percent":11,"reset_at":1800000000}},"plan_type":"pro"}
    """)

    private static let weeklyOnly = CodexUsageWindowFixture("""
    {"rate_limit":{"primary_window":{"limit_window_seconds":604800,"used_percent":62,"reset_at":1900000000}},"plan_type":"pro"}
    """)

    private static let reorderedProperties = CodexUsageWindowFixture("""
    {"plan_type":"pro","rate_limit":{"secondary_window":{"reset_at":1800000000,"used_percent":11,"limit_window_seconds":18000},"primary_window":{"reset_at":1900000000,"used_percent":62,"limit_window_seconds":604800}}}
    """)

    private static let clampedPercentages = CodexUsageWindowFixture("""
    {"rate_limit":{"primary_window":{"limit_window_seconds":18000,"used_percent":150,"reset_at":1800000000},"secondary_window":{"limit_window_seconds":604800,"used_percent":-10,"reset_at":1900000000}},"plan_type":"pro"}
    """)

    static func run<Invoker: CodexUsageWindowInvoking>(using _: Invoker.Type) async {
        var failures = 0

        func emit(_ line: String) {
            FileHandle.standardOutput.write(Data((line + "\n").utf8))
        }

        func expect(_ condition: @autoclosure () -> Bool, _ label: String) {
            if condition() {
                emit("PASS \(label)")
            } else {
                emit("FAIL \(label)")
                failures += 1
            }
        }

        func expectWindow(
            _ window: WindowUsage,
            usedPercent: Double,
            resetAt: TimeInterval,
            _ label: String
        ) {
            expect(abs(window.usedPercent - usedPercent) < 0.000_001, "\(label) usedPercent")
            expect(abs((window.resetAt?.timeIntervalSince1970 ?? -1) - resetAt) < 0.000_001, "\(label) resetAt")
            expect(window.error == nil, "\(label) has no error")
        }

        let reversed = await Invoker.invoke(reversedWindows)
        expectWindow(reversed.fiveHour, usedPercent: 0.11, resetAt: 1_800_000_000, "reversed fiveHour")
        expectWindow(reversed.weekly, usedPercent: 0.62, resetAt: 1_900_000_000, "reversed weekly")
        expect(reversed.plan == "pro", "reversed plan")

        let onlyWeekly = await Invoker.invoke(weeklyOnly)
        expect(onlyWeekly.fiveHour.error == WindowUsage.unknown.error, "weekly-only fiveHour is unknown")
        expectWindow(onlyWeekly.weekly, usedPercent: 0.62, resetAt: 1_900_000_000, "weekly-only weekly")

        let reordered = await Invoker.invoke(reorderedProperties)
        expectWindow(reordered.fiveHour, usedPercent: 0.11, resetAt: 1_800_000_000, "reordered fiveHour")
        expectWindow(reordered.weekly, usedPercent: 0.62, resetAt: 1_900_000_000, "reordered weekly")

        let clamped = await Invoker.invoke(clampedPercentages)
        expectWindow(clamped.fiveHour, usedPercent: 1, resetAt: 1_800_000_000, "clamped fiveHour")
        expectWindow(clamped.weekly, usedPercent: 0, resetAt: 1_900_000_000, "clamped weekly")

        if failures > 0 {
            fatalError("Codex usage window contract failed: \(failures) assertions")
        }
        emit("PASS Codex usage window contract")
    }
}
