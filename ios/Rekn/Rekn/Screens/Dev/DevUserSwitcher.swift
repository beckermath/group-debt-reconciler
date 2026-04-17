import SwiftUI

#if DEBUG

/// Persistent bottom-left pill that lets the developer switch between seeded
/// test users without using real SMS. Only compiled in DEBUG builds and only
/// visible when the server reports dev mode is active (PLAYWRIGHT_TEST=1).
struct DevUserSwitcherPill: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(GroupStore.self) private var groupStore
    @Environment(InviteStore.self) private var inviteStore
    @State private var devStore = DevUserStore()
    @State private var showingSwitcher = false

    var body: some View {
        Group {
            if devStore.availability == .available, authManager.isAuthenticated {
                pill
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .task { await devStore.probe() }
    }

    private var pill: some View {
        Button { showingSwitcher = true } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.balanceNegative.opacity(0.15))
                        .frame(width: 18, height: 18)
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.balanceNegative)
                }
                Text(currentLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.82), in: .capsule)
            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSwitcher) {
            DevUserSwitcherSheet(
                devStore: devStore,
                authManager: authManager,
                groupStore: groupStore,
                inviteStore: inviteStore
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var currentLabel: String {
        if let name = authManager.currentUser?.name, !name.isEmpty {
            return "Dev: \(name)"
        }
        return "Dev"
    }
}

// MARK: - Switcher Sheet

private struct DevUserSwitcherSheet: View {
    let devStore: DevUserStore
    let authManager: AuthManager
    let groupStore: GroupStore
    let inviteStore: InviteStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    debugBanner

                    if devStore.users.isEmpty {
                        ContentUnavailableView(
                            "No seeded test users",
                            systemImage: "person.slash",
                            description: Text("Run the seed script against your dev database.")
                        )
                        .padding(.top, 40)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(devStore.users.enumerated()), id: \.element.id) { index, user in
                                userRow(for: user)
                                if index < devStore.users.count - 1 {
                                    Divider().padding(.leading, 62)
                                }
                            }
                        }
                        .background(.background, in: .rect(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                    }

                    if let error = devStore.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.balanceNegative)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Switch Test User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var debugBanner: some View {
        HStack(spacing: 8) {
            Text("DEBUG")
                .font(.caption2).fontWeight(.bold)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.balanceNegative.opacity(0.18), in: .capsule)
                .foregroundStyle(Color.balanceNegative)
            Text("Seeded test accounts")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func userRow(for user: APITestUser) -> some View {
        let isCurrent = authManager.currentUser?.phoneNumber == user.phoneNumber
        return Button {
            guard !isCurrent, !devStore.isSwitching else { return }
            Task {
                await devStore.switchTo(
                    user: user,
                    authManager: authManager,
                    groupStore: groupStore,
                    inviteStore: inviteStore
                )
                if devStore.lastError == nil { dismiss() }
            }
        } label: {
            HStack(spacing: 12) {
                MemberAvatar(name: user.name, imageUrl: nil, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(user.phoneNumber)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if devStore.isSwitching, !isCurrent {
                    ProgressView().controlSize(.small)
                } else if isCurrent {
                    Label("Active", systemImage: "person.fill.checkmark")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Color.brandPrimary)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
            .opacity(isCurrent ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isCurrent || devStore.isSwitching)
    }
}

#Preview {
    DevUserSwitcherPill()
        .environment(AuthManager())
        .environment(GroupStore())
        .environment(InviteStore())
}

#endif
