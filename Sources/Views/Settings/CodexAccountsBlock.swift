import AppKit
import SwiftUI

struct CodexAccountsBlock: View {
    @ObservedObject var store: CodexAccountStore
    @ObservedObject private var coordinator = CodexAccountApplyCoordinator.shared
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("Codex Accounts"))
                        .font(Typography.rowTitle)
                }
                Spacer()
                Button(L10n.tr("Import Current Auth")) { importCurrentAuth() }
                    .buttonStyle(.bordered)
                Button(L10n.tr("Refresh All")) { Task { await store.refreshAllUsage() } }
                    .buttonStyle(.bordered)
                    .disabled(store.registry.accounts.isEmpty)
            }

            if store.registry.accounts.isEmpty {
                Text(L10n.tr("No stored accounts"))
                    .font(Typography.label)
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                ForEach(store.registry.accounts) { account in
                    accountCard(account)
                }
            }

            if let message = coordinatorMessage ?? message ?? store.lastError {
                Text(message)
                    .font(Typography.micro)
                    .foregroundStyle(.white.opacity(0.55))
            }
            recoveryControls
        }
    }

    private func accountCard(_ account: CodexAccountRecord) -> some View {
        let active = account.accountKey == store.registry.activeAccountKey
        return Button {
            guard !active else { return }
            Task { await coordinator.apply(accountKey: account.accountKey) }
        } label: {
            HStack(spacing: 9) {
                Circle()
                    .fill(active ? IslandColor.codex : .white.opacity(0.18))
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(CodexAccountStore.displayLabel(for: account))
                            .font(Typography.rowTitle)
                        if active {
                            Text(L10n.tr("Active"))
                                .font(Typography.chip)
                                .foregroundStyle(IslandColor.codex)
                        } else {
                            Text(L10n.tr("Select"))
                                .font(Typography.chip)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        if let plan = account.plan {
                            Text(plan.uppercased()).font(Typography.chip).foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    Text(usageText(account))
                        .font(Typography.micro)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                if coordinator.applyingAccountKey == account.accountKey || store.refreshingAccountKeys.contains(account.accountKey) {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(active ? IslandColor.codex.opacity(0.10) : .white.opacity(0.025))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(active ? IslandColor.codex.opacity(0.42) : .white.opacity(0.07), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
        .disabled(active || coordinator.isApplying)
        .accessibilityLabel("\(CodexAccountStore.displayLabel(for: account)), \(active ? "Active" : "Select")")
    }

    private var coordinatorMessage: String? {
        switch coordinator.state {
        case .cancelled: L10n.tr("ChatGPT was not closed; account unchanged.")
        case .targetDrift: L10n.tr("ChatGPT target changed; account unchanged.")
        case .authReloadUnverified: L10n.tr("ChatGPT relaunch attempted; auth reload unverified.")
        case .launchFailed: L10n.tr("Account switched locally. ChatGPT is closed; retry launch or restore the previous account.")
        case .localSwitchComplete where coordinator.restorationRequiresManualHostLaunch:
            L10n.tr("Previous account restored locally. ChatGPT is still closed.")
        case .localSwitchFailed(let error), .localRestoreFailed(let error): error
        default: nil
        }
    }

    @ViewBuilder
    private var recoveryControls: some View {
        if case .launchFailed = coordinator.state {
            HStack(spacing: 8) {
                Button {
                    Task { await coordinator.retryLaunch() }
                } label: {
                    Label(L10n.tr("Retry launch"), systemImage: "arrow.clockwise")
                }
                .disabled(coordinator.isApplying)
                Button {
                    Task { await coordinator.restorePreviousAccount() }
                } label: {
                    Label(L10n.tr("Restore previous"), systemImage: "arrow.uturn.backward")
                }
                .disabled(coordinator.isApplying)
            }
            .buttonStyle(.bordered)
        }
    }

    private func usageText(_ account: CodexAccountRecord) -> String {
        guard let usage = account.lastUsage else { return L10n.tr("No usage snapshot") }
        return "5h \(Int((usage.fiveHour.usedPercent * 100).rounded()))% · week \(Int((usage.weekly.usedPercent * 100).rounded()))%"
    }

    private func importCurrentAuth() {
        let alert = NSAlert()
        alert.messageText = L10n.tr("Import Current Auth")
        alert.addButton(withTitle: L10n.tr("Import"))
        alert.addButton(withTitle: L10n.tr("Cancel"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = L10n.tr("Codex Account")
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try store.importCurrentAuth(label: field.stringValue)
            message = L10n.tr("Imported current Codex auth")
        } catch {
            message = error.localizedDescription
        }
    }
}
