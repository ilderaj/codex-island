import SwiftUI

struct CodexAccountTags: View {
    private static let visibleTagWidth: CGFloat = 56

    @ObservedObject var store: CodexAccountStore
    @ObservedObject private var coordinator = CodexAccountApplyCoordinator.shared

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(store.registry.accounts.prefix(2))) { account in
                tagButton(for: account)
            }
            if store.registry.accounts.count > 2 {
                Menu {
                    ForEach(store.registry.accounts.dropFirst(2)) { account in
                        let active = account.accountKey == store.registry.activeAccountKey
                        Button(CodexAccountStore.displayLabel(for: account)) {
                            Task { await coordinator.apply(accountKey: account.accountKey) }
                        }
                        .disabled(active || coordinator.isApplying)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(Typography.chip)
                        .foregroundStyle(.white.opacity(0.68))
                        .frame(width: 18, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white.opacity(0.06))
                        )
                }
                .menuStyle(.borderlessButton)
                .disabled(coordinator.isApplying)
            }
        }
    }

    private func tagButton(for account: CodexAccountRecord) -> some View {
        let active = account.accountKey == store.registry.activeAccountKey

        return Button {
            guard !active else { return }
            Task { await coordinator.apply(accountKey: account.accountKey) }
        } label: {
            Text(CodexAccountStore.displayLabel(for: account))
                .lineLimit(1)
                .truncationMode(.tail)
                .font(Typography.chip)
                .foregroundStyle(active ? IslandColor.codex : .white.opacity(0.68))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .frame(width: Self.visibleTagWidth)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(active ? IslandColor.codex.opacity(0.15) : .white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .disabled(active || coordinator.isApplying)
    }
}
