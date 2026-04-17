import SwiftUI

struct MemberDetailSheet: View {
    let member: GroupMember
    let balance: BalanceEntry?
    let expenses: [Expense]
    let isCurrentUser: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile header
                    VStack(spacing: 8) {
                        MemberAvatar(name: member.name, imageUrl: member.imageUrl, size: 64)
                        Text(isCurrentUser ? "\(member.name) (You)" : member.name)
                            .font(.title3)
                            .fontWeight(.bold)
                        if member.userId == nil {
                            Text("Guest")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // Balance card
                    if let balance {
                        VStack(spacing: 4) {
                            Text(balance.balanceCents == 0 ? "Settled" : balance.balanceCents > 0 ? "Is owed" : "Owes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatCents(abs(balance.balanceCents)))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    balance.balanceCents > 0 ? Color.balancePositive
                                    : balance.balanceCents < 0 ? Color.balanceNegative
                                    : Color.secondary
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.background, in: .rect(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                        .padding(.horizontal, 16)
                    }

                    // Recent expenses
                    if !expenses.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("RECENT EXPENSES")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .tracking(0.5)
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                let recentExpenses = Array(expenses.prefix(5))
                                ForEach(Array(recentExpenses.enumerated()), id: \.element.id) { index, expense in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(expense.description)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                            Text(expense.createdAt, format: .dateTime.month(.abbreviated).day())
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                        Spacer()
                                        Text(formatCents(expense.amount))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .monospacedDigit()
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)

                                    if index < recentExpenses.count - 1 {
                                        Divider().padding(.horizontal, 16)
                                    }
                                }
                            }
                            .background(.background, in: .rect(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                            .padding(.horizontal, 16)
                        }
                    } else {
                        VStack(spacing: 4) {
                            Text("No expenses yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("This member hasn't paid for any expenses.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
            }
            .background(WarmGradientBackground().ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
