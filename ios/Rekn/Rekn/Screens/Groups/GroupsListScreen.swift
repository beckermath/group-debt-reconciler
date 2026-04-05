import SwiftUI

struct GroupsListScreen: View {
    @Environment(GroupStore.self) private var groupStore
    @State private var showingCreateGroup = false

    private var groups: [GroupSummary] {
        if case .loaded(let g) = groupStore.groupsState { return g }
        return []
    }

    private var totalOwed: Int {
        groups.reduce(0) { $0 + max($1.userBalanceCents, 0) }
    }

    private var totalOwes: Int {
        groups.reduce(0) { $0 + max(-$1.userBalanceCents, 0) }
    }

    var body: some View {
        Group {
            switch groupStore.groupsState {
            case .idle, .loading:
                ProgressView("Loading groups...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let message):
                VStack(spacing: 12) {
                    Text("Something went wrong")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Try again") {
                        Task { await groupStore.loadGroups() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded(let groups) where groups.isEmpty:
                emptyState

            case .loaded:
                groupsList
            }
        }
        .navigationTitle("Your Groups")
        .navigationDestination(for: String.self) { groupId in
            GroupDetailScreen(groupId: groupId)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateGroup = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(isPresented: $showingCreateGroup) {
            GroupNameScreen()
        }
        .task {
            await groupStore.loadGroups()
        }
        .refreshable {
            await groupStore.loadGroups()
        }
    }

    // MARK: - Groups List

    private var groupsList: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Balance summary
                if totalOwed > 0 || totalOwes > 0 {
                    balanceSummaryRow
                        .padding(.top, 4)
                }

                // Group cards
                ForEach(groups) { group in
                    NavigationLink(value: group.id) {
                        GroupCard(group: group)
                    }
                    .buttonStyle(CardPressStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.3))
            Text("No groups yet")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Create a group to start splitting expenses")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showingCreateGroup = true
            } label: {
                Text("Create Group")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: 260)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Balance Summary Row

    private var balanceSummaryRow: some View {
        HStack(spacing: 0) {
            if totalOwed > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text("You are owed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("+\(formatCents(totalOwed))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
            }

            if totalOwed > 0 && totalOwes > 0 {
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
                    .padding(.horizontal, 12)
            }

            if totalOwes > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text("You owe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCents(totalOwes))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Group Card

private struct GroupCard: View {
    let group: GroupSummary

    var body: some View {
        HStack(spacing: 12) {
            // Avatar cluster
            HStack(spacing: -8) {
                ForEach(group.memberNames.prefix(2), id: \.self) { name in
                    MemberAvatar(name: name, size: 34)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                }
                if group.memberCount > 2 {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                        Text("+\(group.memberCount - 2)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                if let date = group.lastActivityAt {
                    Text(date.relativeFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No expenses yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Balance
            if group.userBalanceCents != 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCents(group.userBalanceCents, showSign: true))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(group.userBalanceCents > 0 ? .green : .orange)
                    Text(group.userBalanceCents > 0 ? "owed to you" : "you owe")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            } else if group.status == .settled {
                Text("Settled")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }
}

// MARK: - Card Press Style

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        GroupsListScreen()
            .environment(GroupStore())
    }
}
