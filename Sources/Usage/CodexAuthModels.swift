import Foundation

struct CodexAuthFile: Codable {
    let authMode: String?
    let lastRefresh: String?
    let tokens: CodexAuthTokens

    enum CodingKeys: String, CodingKey {
        case authMode = "auth_mode"
        case lastRefresh = "last_refresh"
        case tokens
    }
}

struct CodexAuthTokens: Codable {
    let accessToken: String?
    let idToken: String?
    let accountID: String?
    let principalID: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case accountID = "account_id"
        case principalID = "principal_id"
    }
}

struct CodexAuthContext {
    let accountKey: String
    let accessToken: String
    let chatgptAccountId: String?
    let identity: CodexIdentity
    let authFile: CodexAuthFile
    let rawData: Data
}

struct CodexIdentity {
    let email: String?
    let chatgptUserId: String?
    let chatgptAccountId: String?
    let principalId: String?
    let plan: String?
    let confidence: CodexIdentityConfidence
}

enum CodexIdentityConfidence: String, Codable {
    case strong
    case medium
    case low
}

struct CodexUsageSnapshot: Codable {
    var fiveHour: Window
    var weekly: Window

    struct Window: Codable {
        var usedPercent: Double
        var resetAt: Date?
        var error: String?
    }

    init(fiveHour: Window, weekly: Window) {
        self.fiveHour = fiveHour
        self.weekly = weekly
    }

    init(_ usage: AppUsage) {
        self.fiveHour = Window(usage.fiveHour)
        self.weekly = Window(usage.weekly)
    }
}

extension CodexUsageSnapshot.Window {
    init(_ usage: WindowUsage) {
        self.usedPercent = usage.usedPercent
        self.resetAt = usage.resetAt
        self.error = usage.error
    }
}

struct CodexAccountRegistry: Codable {
    var schemaVersion: Int
    var activeAccountKey: String?
    var previousActiveAccountKey: String?
    var accounts: [CodexAccountRecord]

    static let empty = CodexAccountRegistry(
        schemaVersion: 1,
        activeAccountKey: nil,
        previousActiveAccountKey: nil,
        accounts: []
    )
}

struct CodexAccountRecord: Codable, Identifiable {
    var id: String { accountKey }

    var accountKey: String
    var chatgptUserId: String?
    var chatgptAccountId: String?
    var principalId: String?
    var identityConfidence: CodexIdentityConfidence
    var email: String?
    var label: String
    var plan: String?
    var createdAt: Date
    var lastUsedAt: Date?
    var lastUsageAt: Date?
    var lastUsage: CodexUsageSnapshot?
    var lastError: String?

    var isLowConfidence: Bool {
        identityConfidence == .low
    }
}

struct CodexAccountPaths {
    let root: URL

    init(root: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.root = root
    }

    var codexDirectory: URL {
        root.appendingPathComponent(".codex", isDirectory: true)
    }

    var accountsDirectory: URL {
        codexDirectory.appendingPathComponent("accounts", isDirectory: true)
    }

    var registryPath: URL {
        accountsDirectory.appendingPathComponent("registry.json")
    }

    var activeAuthPath: URL {
        codexDirectory.appendingPathComponent("auth.json")
    }

    func snapshotPath(for accountKey: String) -> URL {
        accountsDirectory.appendingPathComponent("\(accountKey).auth.json")
    }
}

protocol CodexUsageClient: AnyObject {
    func fetchCodex(context: CodexAuthContext) async -> AppUsage
}
