import Combine
import Foundation

final class CodexAccountStore: ObservableObject {
    static let shared = (try? CodexAccountStore()) ?? CodexAccountStore(registry: .empty)

    @Published private(set) var registry: CodexAccountRegistry
    @Published var lastError: String?
    @Published var refreshingAccountKeys: Set<String> = []

    let paths: CodexAccountPaths

    init(paths: CodexAccountPaths = CodexAccountPaths()) throws {
        self.paths = paths
        self.registry = try Self.loadRegistry(paths: paths)
    }

    private init(registry: CodexAccountRegistry) {
        self.paths = CodexAccountPaths()
        self.registry = registry
    }

    func importCurrentAuth(label: String) throws {
        let data = try Data(contentsOf: paths.activeAuthPath)
        let context = try CodexAuthParser.parseAuth(data: data)
        try ensureAccountsDirectory()
        try writePrivate(data, to: paths.snapshotPath(for: context.accountKey))

        let now = Date()
        var next = registry
        let previousActive = next.activeAccountKey
        let record = CodexAccountRecord(
            accountKey: context.accountKey,
            chatgptUserId: context.identity.chatgptUserId,
            chatgptAccountId: context.identity.chatgptAccountId,
            principalId: context.identity.principalId,
            identityConfidence: context.identity.confidence,
            email: context.identity.email,
            label: label.isEmpty ? defaultLabel(for: context) : label,
            plan: context.identity.plan,
            createdAt: now,
            lastUsedAt: now,
            lastUsageAt: nil,
            lastUsage: nil,
            lastError: nil
        )
        upsert(record, in: &next)
        if previousActive != nil && previousActive != context.accountKey {
            next.previousActiveAccountKey = previousActive
        }
        next.activeAccountKey = context.accountKey
        registry = next
        try saveRegistry()
    }

    func switchToAccount(_ accountKey: String) throws {
        guard let target = registry.accounts.first(where: { $0.accountKey == accountKey }) else {
            throw CodexAccountError.accountNotFound
        }
        let targetSnapshot = paths.snapshotPath(for: target.accountKey)
        guard FileManager.default.fileExists(atPath: targetSnapshot.path) else {
            throw CodexAccountError.snapshotMissing
        }

        let previousRegistry = registry
        let previousAuth = try? Data(contentsOf: paths.activeAuthPath)
        try importUnknownCurrentAuthIfNeeded()

        var next = registry
        let previousActive = next.activeAccountKey
        for i in next.accounts.indices where next.accounts[i].accountKey == accountKey {
            next.accounts[i].lastUsedAt = Date()
            next.accounts[i].lastError = nil
        }
        if previousActive != nil && previousActive != accountKey {
            next.previousActiveAccountKey = previousActive
        }
        next.activeAccountKey = accountKey

        do {
            let selectedData = try Data(contentsOf: targetSnapshot)
            try writePrivate(selectedData, to: paths.activeAuthPath)
            registry = next
            try saveRegistry()
        } catch {
            if let previousAuth {
                try? writePrivate(previousAuth, to: paths.activeAuthPath)
            }
            registry = previousRegistry
            try? saveRegistry()
            lastError = CodexAccountError.inconsistentSwitchState.localizedDescription
            throw error
        }
    }

    func switchPrevious() throws {
        guard let previous = registry.previousActiveAccountKey else {
            throw CodexAccountError.accountNotFound
        }
        try switchToAccount(previous)
    }

    func refreshActiveUsage(client: CodexUsageClient = UsageFetcherClient()) async {
        guard let active = registry.activeAccountKey else { return }
        await refreshUsage(for: [active], client: client)
    }

    func refreshAllUsage(client: CodexUsageClient = UsageFetcherClient()) async {
        await refreshUsage(for: registry.accounts.map(\.accountKey), client: client)
    }

    func updateActiveUsage(_ usage: AppUsage) {
        guard let key = registry.activeAccountKey,
              let index = registry.accounts.firstIndex(where: { $0.accountKey == key }) else { return }
        registry.accounts[index].lastUsage = CodexUsageSnapshot(usage)
        registry.accounts[index].lastUsageAt = Date()
        if let plan = usage.plan {
            registry.accounts[index].plan = plan
        }
        try? saveRegistry()
    }

    private func refreshUsage(for accountKeys: [String], client: CodexUsageClient) async {
        let keys = Array(Set(accountKeys))
        for key in keys {
            guard let index = registry.accounts.firstIndex(where: { $0.accountKey == key }) else { continue }
            refreshingAccountKeys.insert(key)
            defer { refreshingAccountKeys.remove(key) }

            do {
                let snapshot = paths.snapshotPath(for: key)
                let context = try CodexAuthParser.parseAuth(data: Data(contentsOf: snapshot))
                let usage = await client.fetchCodex(context: context)
                registry.accounts[index].lastUsage = CodexUsageSnapshot(usage)
                registry.accounts[index].lastUsageAt = Date()
                registry.accounts[index].lastError = nil
                if let plan = usage.plan {
                    registry.accounts[index].plan = plan
                }
            } catch {
                registry.accounts[index].lastError = error.localizedDescription
            }
        }
        try? saveRegistry()
    }

    private func importUnknownCurrentAuthIfNeeded() throws {
        guard let data = try? Data(contentsOf: paths.activeAuthPath),
              let context = try? CodexAuthParser.parseAuth(data: data),
              !registry.accounts.contains(where: { $0.accountKey == context.accountKey }) else {
            return
        }
        try writePrivate(data, to: paths.snapshotPath(for: context.accountKey))
        var record = CodexAccountRecord(
            accountKey: context.accountKey,
            chatgptUserId: context.identity.chatgptUserId,
            chatgptAccountId: context.identity.chatgptAccountId,
            principalId: context.identity.principalId,
            identityConfidence: context.identity.confidence,
            email: context.identity.email,
            label: "Previous account",
            plan: context.identity.plan,
            createdAt: Date(),
            lastUsedAt: nil,
            lastUsageAt: nil,
            lastUsage: nil,
            lastError: nil
        )
        record.lastUsedAt = Date()
        upsert(record, in: &registry)
        registry.activeAccountKey = context.accountKey
        try saveRegistry()
    }

    private static func loadRegistry(paths: CodexAccountPaths) throws -> CodexAccountRegistry {
        guard FileManager.default.fileExists(atPath: paths.registryPath.path) else {
            return .empty
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CodexAccountRegistry.self, from: Data(contentsOf: paths.registryPath))
    }

    private func saveRegistry() throws {
        try ensureAccountsDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try writePrivate(try encoder.encode(registry), to: paths.registryPath)
    }

    private func ensureAccountsDirectory() throws {
        try FileManager.default.createDirectory(
            at: paths.accountsDirectory,
            withIntermediateDirectories: true
        )
        try? FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o700))],
            ofItemAtPath: paths.accountsDirectory.path
        )
    }

    private func writePrivate(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: [.atomic])
        try? FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: url.path
        )
    }

    private func upsert(_ record: CodexAccountRecord, in registry: inout CodexAccountRegistry) {
        if let index = registry.accounts.firstIndex(where: { $0.accountKey == record.accountKey }) {
            let createdAt = registry.accounts[index].createdAt
            let lastUsage = registry.accounts[index].lastUsage
            let lastUsageAt = registry.accounts[index].lastUsageAt
            registry.accounts[index] = record
            registry.accounts[index].createdAt = createdAt
            registry.accounts[index].lastUsage = lastUsage
            registry.accounts[index].lastUsageAt = lastUsageAt
        } else {
            registry.accounts.append(record)
        }
    }

    private func defaultLabel(for context: CodexAuthContext) -> String {
        context.identity.email ?? "Codex Account"
    }
}

enum CodexAccountError: LocalizedError {
    case accountNotFound
    case snapshotMissing
    case inconsistentSwitchState

    var errorDescription: String? {
        switch self {
        case .accountNotFound:
            return "Codex account not found"
        case .snapshotMissing:
            return "Codex account snapshot missing"
        case .inconsistentSwitchState:
            return "Codex account switch may be inconsistent"
        }
    }
}

final class UsageFetcherClient: CodexUsageClient {
    func fetchCodex(context: CodexAuthContext) async -> AppUsage {
        await UsageFetcher.fetchCodex(context: context)
    }
}
