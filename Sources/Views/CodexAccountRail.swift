import SwiftUI

enum CodexAccountRailRoute: Equatable {
    case summary
    case accounts
    case selected(String)
}

struct CodexAccountRail: View {
    @ObservedObject var store: CodexAccountStore
    @ObservedObject var coordinator: CodexAccountApplyCoordinator
    @Binding var route: CodexAccountRailRoute
    @State private var confirmsSwitch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            railHeader
            switch route {
            case .summary, .accounts:
                accountList
            case .selected(let accountKey):
                selectedAccount(accountKey: accountKey)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var railHeader: some View {
        HStack {
            Button {
                route = .summary
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            Text(L10n.tr("Accounts"))
                .font(Typography.rowTitle)
                .foregroundStyle(.white.opacity(0.92))
            Spacer()
        }
    }

    @ViewBuilder
    private var accountList: some View {
        if store.registry.accounts.isEmpty {
            Text(L10n.tr("No stored accounts"))
                .font(Typography.label)
                .foregroundStyle(.white.opacity(0.45))
        } else {
            VStack(spacing: 7) {
                ForEach(store.registry.accounts) { account in
                    accountRow(account)
                }
            }
        }
    }

    private func accountRow(_ account: CodexAccountRecord) -> some View {
        let active = account.accountKey == store.registry.activeAccountKey
        return Button {
            guard !active else { return }
            route = .selected(account.accountKey)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(CodexAccountStore.displayLabel(for: account))
                        .font(Typography.rowTitle)
                    if active {
                        railChip("Active", color: IslandColor.codex)
                    }
                    if let plan = account.plan {
                        railChip(plan.uppercased(), color: .white)
                    }
                    Spacer(minLength: 0)
                    if !active {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                Text(accountStatus(account))
                    .font(Typography.micro)
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
                Text(accountUsage(account))
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(active ? IslandColor.codex.opacity(0.08) : .white.opacity(0.03))
            )
        }
        .buttonStyle(.plain)
        .disabled(active)
    }

    @ViewBuilder
    private func selectedAccount(accountKey: String) -> some View {
        if let account = store.registry.accounts.first(where: { $0.accountKey == accountKey }) {
            VStack(alignment: .leading, spacing: 10) {
                Text(CodexAccountStore.displayLabel(for: account))
                    .font(Typography.rowTitle)
                    .foregroundStyle(.white.opacity(0.92))
                Text(accountStatus(account))
                    .font(Typography.micro)
                    .foregroundStyle(.white.opacity(0.55))
                coordinatorControls(for: account)
            }
            .alert(L10n.tr("Switch & relaunch ChatGPT"), isPresented: $confirmsSwitch) {
                Button(L10n.tr("Switch & relaunch ChatGPT"), role: .destructive) {
                    Task { await coordinator.apply(accountKey: account.accountKey) }
                }
                Button(L10n.tr("Cancel"), role: .cancel) {}
            } message: {
                Text(L10n.tr("ChatGPT will quit and reopen to apply this account."))
            }
        } else {
            Text(L10n.tr("No stored accounts"))
        }
    }

    @ViewBuilder
    private func coordinatorControls(for account: CodexAccountRecord) -> some View {
        switch coordinator.state {
        case .terminationFailed(let message):
            coordinatorMessage(message)
            if coordinator.didSwitchLocallyForCurrentApply { restoreButton }
        case .launchFailed(let message):
            coordinatorMessage(message)
            Button(L10n.tr("Retry launch")) {
                Task { await coordinator.retryLaunch() }
            }
            .buttonStyle(.bordered)
            if coordinator.didSwitchLocallyForCurrentApply { restoreButton }
        case .localRestoreFailed(let message), .localSwitchFailed(let message):
            coordinatorMessage(message)
        case .localSwitchComplete:
            coordinatorMessage(L10n.tr("Local switch complete"))
        case .authReloadUnverified:
            coordinatorMessage(L10n.tr("ChatGPT relaunch attempted"))
        case .validatingTarget, .switchingLocally:
            EmptyView()
        case .terminatingHost, .hostTerminated, .launchAttempted:
            coordinatorMessage(L10n.tr("Local switch complete"))
        case .idle:
            Button(L10n.tr("Switch & relaunch ChatGPT")) {
                confirmsSwitch = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var restoreButton: some View {
        Button(L10n.tr("Restore previous local account")) {
            Task { await coordinator.restorePreviousAccount() }
        }
        .buttonStyle(.bordered)
    }

    private func coordinatorMessage(_ message: String) -> some View {
        Text(message)
            .font(Typography.micro)
            .foregroundStyle(.white.opacity(0.55))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func railChip(_ text: String, color: Color) -> some View {
        Text(L10n.tr(text))
            .font(Typography.chip)
            .foregroundStyle(color.opacity(0.75))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.08)))
    }

    private func accountStatus(_ account: CodexAccountRecord) -> String {
        var parts: [String] = []
        if let plan = account.plan { parts.append(plan.uppercased()) }
        if let lastUsed = account.lastUsedAt {
            parts.append(L10n.tr("Last active %@", Self.relativeFormatter.localizedString(for: lastUsed, relativeTo: Date())))
        }
        parts.append(account.lastUsage == nil ? L10n.tr("No usage snapshot") : L10n.tr("Usage available"))
        return parts.joined(separator: " · ")
    }

    private func accountUsage(_ account: CodexAccountRecord) -> String {
        if let error = account.lastError { return "⚠ \(error)" }
        guard let usage = account.lastUsage else { return L10n.tr("No usage snapshot") }
        let values = ["5h \(Int((usage.fiveHour.usedPercent * 100).rounded()))%", "week \(Int((usage.weekly.usedPercent * 100).rounded()))%"]
        if let last = account.lastUsageAt {
            return values.joined(separator: " · ") + " · " + L10n.tr("Last refreshed %@", Self.relativeFormatter.localizedString(for: last, relativeTo: Date()))
        }
        return values.joined(separator: " · ")
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = L10n.locale
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
