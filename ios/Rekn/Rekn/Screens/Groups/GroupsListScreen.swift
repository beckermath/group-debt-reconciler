import SwiftUI

struct GroupsListScreen: View {
    let groups = GroupSummary.previews
    @State private var showingCreateGroup = false

    private var totalOwed: Int {
        groups.reduce(0) { $0 + max($1.userBalanceCents, 0) }
    }

    private var totalOwes: Int {
        groups.reduce(0) { $0 + max(-$1.userBalanceCents, 0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Global balance summary
                if totalOwed > 0 || totalOwes > 0 {
                    HStack(spacing: 12) {
                        if totalOwed > 0 {
                            BalanceSummaryCard(
                                label: "You are owed",
                                amount: totalOwed,
                                color: .green
                            )
                        }
                        if totalOwes > 0 {
                            BalanceSummaryCard(
                                label: "You owe",
                                amount: totalOwes,
                                color: .orange
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                // Group cards
                LazyVStack(spacing: 10) {
                    ForEach(groups) { group in
                        NavigationLink(value: group.id) {
                            GroupCard(group: group)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 8)
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
        .sheet(isPresented: $showingCreateGroup) {
            GroupSetupScreen()
        }
    }
}

// MARK: - Balance Summary Card

private struct BalanceSummaryCard: View {
    let label: String
    let amount: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color.opacity(0.8))
            Text("$\(String(format: "%.2f", Double(amount) / 100))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.08), in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Group Card

private struct GroupCard: View {
    let group: GroupSummary

    private var statusColor: Color {
        switch group.status {
        case .hasBalances: .orange
        case .settled: .green
        case .noExpenses: .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar stack with status dot
            ZStack(alignment: .bottomTrailing) {
                HStack(spacing: -8) {
                    ForEach(group.memberNames.prefix(3), id: \.self) { name in
                        MemberAvatar(name: name, size: 36)
                            .overlay(Circle().stroke(.background, lineWidth: 2))
                    }
                    if group.memberCount > 3 {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                            Text("+\(group.memberCount - 3)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(.background, lineWidth: 2))
                    }
                }
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(.background, lineWidth: 2))
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                HStack(spacing: 8) {
                    Label("\(group.memberCount)", systemImage: "person.2")
                    if group.expenseCount > 0 {
                        Label("\(group.expenseCount)", systemImage: "receipt")
                    }
                    if let date = group.lastActivityAt {
                        Text(date.relativeFormatted)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Balance
            if group.userBalanceCents != 0 {
                VStack(alignment: .trailing, spacing: 1) {
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

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding(14)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

// MARK: - Helpers

func formatCents(_ cents: Int, showSign: Bool = false) -> String {
    let value = Double(abs(cents)) / 100
    let formatted = String(format: "$%.2f", value)
    if showSign && cents > 0 { return "+\(formatted)" }
    if showSign && cents < 0 { return "-\(formatted)" }
    return formatted
}

extension Date {
    var relativeFormatted: String {
        let days = Calendar.current.dateComponents([.day], from: self, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days)d ago" }
        if days < 30 { return "\(days / 7)w ago" }
        return formatted(.dateTime.month(.abbreviated).day())
    }
}

#Preview {
    NavigationStack {
        GroupsListScreen()
    }
}
