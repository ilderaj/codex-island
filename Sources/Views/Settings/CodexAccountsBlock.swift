import AppKit
import SwiftUI

struct CodexAccountsBlock: View {
    @ObservedObject var store: CodexAccountStore
    @ObservedObject private var coordinator = CodexAccountApplyCoordinator.shared

    @State private var actionMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            actionGrid
            accountRows
            footerMessage
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.065), lineWidth: 0.5)
                }
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("Codex Accounts"))
                    .font(Typography.rowTitle)
                    .foregroundStyle(.white.opacity(0.92))
                Text(L10n.tr("Local snapshots in ~/.codex/accounts. Active auth stays ~/.codex/auth.json."))
                    .font(Typography.micro)
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            accountMenu
        }
    }

    private var accountMenu: some View {
        Menu {
            if store.registry.accounts.isEmpty {
                Text(L10n.tr("No stored accounts"))
            } else {
                ForEach(store.registry.accounts) { account in
                    Button(CodexAccountStore.displayLabel(for: account)) {
                        confirmSwitch(to: account)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(activeAccountLabel)
                    .font(Typography.button)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                    }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var activeAccountLabel: String {
        guard let key = store.registry.activeAccountKey,
              let account = store.registry.accounts.first(where: { $0.accountKey == key }) else {
            return L10n.tr("No stored accounts")
        }
        return CodexAccountStore.displayLabel(for: account)
    }

    private var actionGrid: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                accountAction("Import Current Auth", prominent: true) {
                    importCurrentAuth()
                }
                accountAction("Switch Previous") {
                    confirmPreviousSwitch()
                }
                .disabled(store.registry.previousActiveAccountKey == nil)
            }
            HStack(spacing: 6) {
                accountAction("Refresh Active") {
                    Task { await store.refreshActiveUsage() }
                }
                .disabled(store.registry.activeAccountKey == nil)
                accountAction("Refresh All") {
                    Task { await store.refreshAllUsage() }
                }
                .disabled(store.registry.accounts.isEmpty)
            }
        }
    }

    private func accountAction(
        _ label: String,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(L10n.tr(label))
                .font(Typography.button)
                .foregroundStyle(prominent ? Color.white.opacity(0.95) : .white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(prominent ? IslandColor.codex.opacity(0.22) : .white.opacity(0.075))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(prominent ? IslandColor.codex.opacity(0.35) : .white.opacity(0.08), lineWidth: 0.5)
                        }
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var accountRows: some View {
        if store.registry.accounts.isEmpty {
            Text(L10n.tr("No stored accounts"))
                .font(Typography.label)
                .foregroundStyle(.white.opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
        } else {
            VStack(spacing: 6) {
                ForEach(store.registry.accounts) { account in
                    accountRow(account)
                }
            }
        }
    }

    private func accountRow(_ account: CodexAccountRecord) -> some View {
        let active = account.accountKey == store.registry.activeAccountKey
        return HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(active ? IslandColor.codex : Color.white.opacity(0.18))
                .frame(width: 7, height: 7)
                .shadow(color: active ? IslandColor.codex.opacity(0.65) : .clear, radius: 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(CodexAccountStore.displayLabel(for: account))
                        .font(Typography.rowTitle)
                        .foregroundStyle(.white.opacity(0.90))
                    if active {
                        chip("Active", color: IslandColor.codex)
                    }
                    if let plan = account.plan {
                        chip(plan.uppercased(), color: .white)
                    }
                }
                Text(accountStatus(account))
                    .font(Typography.micro)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(accountUsage(account))
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(active ? IslandColor.codex.opacity(0.07) : .white.opacity(0.025))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(active ? IslandColor.codex.opacity(0.22) : .white.opacity(0.055), lineWidth: 0.5)
                }
        }
        .accessibilityElement(children: .combine)
    }

    private func chip(_ label: String, color: Color) -> some View {
        Text(L10n.tr(label))
            .font(Typography.chip)
            .tracking(0.6)
            .foregroundStyle(color.opacity(0.78))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.07))
            }
    }

    @ViewBuilder
    private var footerMessage: some View {
        if let message = coordinatorMessage ?? actionMessage ?? store.lastError {
            Text(message)
                .font(Typography.micro)
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var coordinatorMessage: String? {
        switch coordinator.state {
        case .localSwitchComplete:
            return L10n.tr("Local switch complete")
        case .authReloadUnverified:
            return L10n.tr("ChatGPT relaunch attempted")
        case .launchFailed:
            return L10n.tr("ChatGPT relaunch failed")
        case .terminationFailed(let message), .localSwitchFailed(let message), .localRestoreFailed(let message):
            return message
        case .idle, .validatingTarget, .switchingLocally, .terminatingHost, .hostTerminated, .launchAttempted:
            return nil
        }
    }

    private func accountStatus(_ account: CodexAccountRecord) -> String {
        var parts: [String] = []
        if let plan = account.plan { parts.append(plan.uppercased()) }
        if let last = account.lastUsageAt {
            parts.append(L10n.tr("Last refreshed %@", Self.relativeFormatter.localizedString(for: last, relativeTo: Date())))
        } else {
            parts.append(L10n.tr(account.lastUsage == nil ? "No usage snapshot" : "Usage available"))
        }
        return parts.joined(separator: " · ")
    }

    private func accountUsage(_ account: CodexAccountRecord) -> String {
        if let error = account.lastError {
            return "⚠ \(error)"
        }
        guard let usage = account.lastUsage else {
            return L10n.tr("No usage snapshot")
        }
        let five = windowText(label: "5h", usage.fiveHour)
        let week = windowText(label: "week", usage.weekly)
        if let last = account.lastUsageAt {
            return "\(five) · \(week) · \(L10n.tr("Last refreshed %@", Self.relativeFormatter.localizedString(for: last, relativeTo: Date())))"
        }
        return "\(five) · \(week)"
    }

    private func windowText(label: String, _ window: CodexUsageSnapshot.Window) -> String {
        if let error = window.error { return "\(L10n.tr(label)) ⚠ \(error)" }
        let percent = Int((window.usedPercent * 100).rounded())
        guard let resetAt = window.resetAt else {
            return "\(L10n.tr(label)) \(percent)%"
        }
        let delta = max(0, resetAt.timeIntervalSinceNow)
        return "\(L10n.tr(label)) \(percent)% \(L10n.tr("resets in %@", Duration.compact(delta)))"
    }

    private func importCurrentAuth() {
        let label = promptForLabel()
        perform(L10n.tr("Imported current Codex auth")) {
            try store.importCurrentAuth(label: label)
        }
    }

    private func promptForLabel() -> String {
        let alert = NSAlert()
        alert.messageText = L10n.tr("Import Current Auth")
        alert.informativeText = L10n.tr("Choose a local label for this Codex account.")
        alert.addButton(withTitle: L10n.tr("Import"))
        alert.addButton(withTitle: L10n.tr("Cancel"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = L10n.tr("Codex Account")
        alert.accessoryView = field
        let result = alert.runModal()
        if result == .alertFirstButtonReturn {
            return field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private func confirmPreviousSwitch() {
        guard let key = store.registry.previousActiveAccountKey,
              let account = store.registry.accounts.first(where: { $0.accountKey == key }) else { return }
        confirmSwitch(to: account)
    }

    private func confirmSwitch(to account: CodexAccountRecord) {
        let alert = NSAlert()
        alert.messageText = L10n.tr("Switch & relaunch ChatGPT")
        alert.informativeText = "\(CodexAccountStore.displayLabel(for: account))\n\n\(L10n.tr("ChatGPT will quit and reopen to apply this account."))"
        alert.addButton(withTitle: L10n.tr("Switch & relaunch ChatGPT"))
        alert.addButton(withTitle: L10n.tr("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { await coordinator.apply(accountKey: account.accountKey) }
    }

    private func perform(_ success: String, action: () throws -> Void) {
        do {
            try action()
            actionMessage = success
        } catch {
            actionMessage = error.localizedDescription
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = L10n.locale
        f.unitsStyle = .abbreviated
        return f
    }()
}
