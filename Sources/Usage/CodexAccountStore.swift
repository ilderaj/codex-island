import Combine
import Foundation

final class CodexAccountStore: ObservableObject {
    static let shared = (try? CodexAccountStore()) ?? CodexAccountStore(registry: .empty)

    @Published private(set) var registry: CodexAccountRegistry
    @Published var lastError: String?
    @Published var refreshingAccountKeys: Set<String> = []

    let paths: CodexAccountPaths
    private let writer: CodexAccountDataWriting

    init(
        paths: CodexAccountPaths = CodexAccountPaths(),
        writer: CodexAccountDataWriting = LiveCodexAccountDataWriter()
    ) throws {
        self.paths = paths
        self.writer = writer
        self.registry = try Self.loadRegistry(paths: paths)
    }

    private init(registry: CodexAccountRegistry) {
        self.paths = CodexAccountPaths()
        self.writer = LiveCodexAccountDataWriter()
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
            label: Self.sanitizedLabel(
                label,
                accountKey: context.accountKey,
                chatgptAccountId: context.identity.chatgptAccountId,
                principalId: context.identity.principalId
            ),
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
        let previousRegistryData = try dataIfPresent(at: paths.registryPath)
        let previousAuthData = try dataIfPresent(at: paths.activeAuthPath)
        let selectedData = try Data(contentsOf: targetSnapshot)
        let unknownCurrentAuth = try unknownCurrentAuth(from: previousAuthData)
        let previousUnknownSnapshotData = try unknownCurrentAuth.map {
            try dataIfPresent(at: paths.snapshotPath(for: $0.context.accountKey))
        }

        do {
            var next = previousRegistry
            if let unknownCurrentAuth {
                try writePrivate(unknownCurrentAuth.data, to: paths.snapshotPath(for: unknownCurrentAuth.context.accountKey))
                upsert(unknownRecord(for: unknownCurrentAuth.context), in: &next)
                next.activeAccountKey = unknownCurrentAuth.context.accountKey
            }

            let previousActive = next.activeAccountKey
            for i in next.accounts.indices where next.accounts[i].accountKey == accountKey {
                next.accounts[i].lastUsedAt = Date()
                next.accounts[i].lastError = nil
            }
            if previousActive != nil && previousActive != accountKey {
                next.previousActiveAccountKey = previousActive
            }
            next.activeAccountKey = accountKey

            try writePrivate(selectedData, to: paths.activeAuthPath)
            registry = next
            try saveRegistry()
            lastError = nil
        } catch {
            var recoveryFailed = false
            if !restorePrivate(previousAuthData, to: paths.activeAuthPath) {
                recoveryFailed = true
            }
            if let unknownCurrentAuth,
               !restorePrivate(
                    previousUnknownSnapshotData ?? nil,
                    to: paths.snapshotPath(for: unknownCurrentAuth.context.accountKey)
               ) {
                recoveryFailed = true
            }
            if !restorePrivate(previousRegistryData, to: paths.registryPath) {
                recoveryFailed = true
            }
            registry = previousRegistry
            lastError = recoveryFailed
                ? CodexAccountError.durableRecoveryRequired.localizedDescription
                : CodexAccountError.inconsistentSwitchState.localizedDescription
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

    private func unknownCurrentAuth(from data: Data?) throws -> (data: Data, context: CodexAuthContext)? {
        guard let data,
              let context = try? CodexAuthParser.parseAuth(data: data),
              !registry.accounts.contains(where: { $0.accountKey == context.accountKey }) else {
            return nil
        }
        return (data, context)
    }

    private func unknownRecord(for context: CodexAuthContext) -> CodexAccountRecord {
        CodexAccountRecord(
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
    }

    private func dataIfPresent(at url: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
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
        try writer.write(data, to: url)
        try? FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: url.path
        )
    }

    private func restorePrivate(_ data: Data?, to url: URL) -> Bool {
        do {
            if let data {
                try writePrivate(data, to: url)
            } else if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            return true
        } catch {
            return (try? dataIfPresent(at: url)) == data
        }
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

    static func defaultLabel(forAccountKey accountKey: String) -> String {
        "Codex Account \(accountKey.suffix(6))"
    }

    static func displayLabel(for account: CodexAccountRecord) -> String {
        sanitizedLabel(
            account.label,
            accountKey: account.accountKey,
            chatgptAccountId: account.chatgptAccountId,
            principalId: account.principalId
        )
    }

    private static func sanitizedLabel(
        _ label: String,
        accountKey: String,
        chatgptAccountId: String?,
        principalId: String?
    ) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawIdentity = [accountKey, chatgptAccountId, principalId].compactMap { $0 }
        guard !trimmed.isEmpty,
              !trimmed.contains("@"),
              !rawIdentity.contains(where: { !$0.isEmpty && trimmed.contains($0) }) else {
            return defaultLabel(forAccountKey: accountKey)
        }
        return trimmed
    }
}

enum CodexAccountError: LocalizedError {
    case accountNotFound
    case snapshotMissing
    case inconsistentSwitchState
    case durableRecoveryRequired

    var errorDescription: String? {
        switch self {
        case .accountNotFound:
            return "Codex account not found"
        case .snapshotMissing:
            return "Codex account snapshot missing"
        case .inconsistentSwitchState:
            return "Codex account switch may be inconsistent"
        case .durableRecoveryRequired:
            return "Codex account switch requires durable recovery"
        }
    }
}

final class UsageFetcherClient: CodexUsageClient {
    func fetchCodex(context: CodexAuthContext) async -> AppUsage {
        await UsageFetcher.fetchCodex(context: context)
    }
}
