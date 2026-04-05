import SwiftUI

struct GroupDetailScreen: View {
    let groupId: String
    @Environment(GroupStore.self) private var groupStore
    @State private var showingAddExpense = false
    @State private var showingAddPeople = false
    @State private var showingSettleUp = false

    // Computed from store
    private var detail: GroupDetail? {
        if case .loaded(let d) = groupStore.detailState { return d }
        return nil
    }
    private var members: [String] { detail?.members.map(\.name) ?? [] }
    private var balances: [BalanceEntry] { detail?.balances ?? [] }
    private var transfers: [Transfer] { detail?.transfers ?? [] }
    private var expenses: [Expense] { detail?.expenses ?? [] }
    private var settlements: [Settlement] { detail?.settlements ?? [] }
    private var groupName: String { detail?.name ?? "Group" }

    var body: some View {
        Group {
            switch groupStore.detailState {
            case .idle, .loading:
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let msg):
                VStack(spacing: 12) {
                    Text(msg).font(.subheadline).foregroundStyle(.secondary)
                    Button("Retry") { Task { await groupStore.loadGroupDetail(id: groupId) } }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded:
                scrollContent
            }
        }
        .task { await groupStore.loadGroupDetail(id: groupId) }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Compact member avatars
                memberAvatarRow
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                // Hero: Balances card
                balancesCard
                    .padding(.bottom, 16)

                // Transfers card (only when present)
                if !transfers.isEmpty {
                    transfersCard
                        .padding(.bottom, 16)
                }

                // Activity section label
                sectionLabel("Activity")
                    .padding(.bottom, 10)

                // Expense cards
                expenseCards
                    .padding(.bottom, 16)

                // Settlement History section label
                if !settlements.isEmpty {
                    sectionLabel("Settlement History")
                        .padding(.bottom, 10)

                    historyCard
                        .padding(.bottom, 16)
                }

                // Bottom padding for fixed button
                Spacer().frame(height: 70)
            }
            .padding(.horizontal)
        }
        .navigationTitle(groupName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddPeople = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            addExpenseBar
        }
        .navigationDestination(isPresented: $showingAddExpense) {
            AddExpenseScreen(groupId: groupId, memberList: detail?.members ?? [], currentUserId: nil)
        }
        .navigationDestination(isPresented: $showingAddPeople) {
            MemberPickerScreen(groupName: groupName, groupId: groupId)
        }
        .navigationDestination(isPresented: $showingSettleUp) {
            SettleUpScreen(groupId: groupId, transfers: transfers)
        }
        .navigationDestination(for: Settlement.self) { settlement in
            SettlementDetailScreen(settlement: settlement)
        }
    }

    // MARK: - Member Avatar Row

    private var memberAvatarRow: some View {
        HStack(spacing: -8) {
            ForEach(members.prefix(5), id: \.self) { name in
                MemberAvatar(name: name, size: 28)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
            }
            if members.count > 5 {
                Text("+\(members.count - 5)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 12)
            }
        }
    }

    // MARK: - Balances Card (Hero)

    @State private var showAllMembers = false

    private var activeBalances: [BalanceEntry] {
        balances.filter { $0.balanceCents != 0 }
    }

    private var settledMembers: [BalanceEntry] {
        balances.filter { $0.balanceCents == 0 }
    }

    private var balancesCard: some View {
        VStack(spacing: 14) {
            // Inline label
            Text("BALANCES")
                .font(.caption)
                .fontWeight(.semibold)
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Members with active balances — always shown
            ForEach(activeBalances) { entry in
                balanceRow(entry)
            }

            // Settled members — collapsed by default
            if !settledMembers.isEmpty {
                if showAllMembers {
                    ForEach(settledMembers) { entry in
                        balanceRow(entry)
                    }
                }

                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        showAllMembers.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        // Stacked mini avatars for settled members
                        if !showAllMembers {
                            HStack(spacing: -6) {
                                ForEach(settledMembers.prefix(3)) { entry in
                                    MemberAvatar(name: entry.name, size: 20)
                                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                                }
                            }
                        }
                        Text(showAllMembers
                            ? "Show less"
                            : "\(settledMembers.count) settled member\(settledMembers.count == 1 ? "" : "s")")
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: showAllMembers ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }

    private func balanceRow(_ entry: BalanceEntry) -> some View {
        HStack(spacing: 10) {
            MemberAvatar(name: entry.name, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatCents(entry.balanceCents, showSign: true))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(entry.balanceCents > 0 ? .green : entry.balanceCents < 0 ? .orange : .secondary)
                    Text(entry.balanceCents > 0 ? "is owed" : entry.balanceCents < 0 ? "owes" : "settled")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                BalanceBar(balance: entry.balanceCents, maxAbsBalance: entry.maxAbsBalance)
            }
        }
    }

    // MARK: - Transfers Card

    private var transfersCard: some View {
        VStack(spacing: 10) {
            // Header with inline action
            HStack {
                Text("\(transfers.count) payment\(transfers.count == 1 ? "" : "s") to settle")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingSettleUp = true
                } label: {
                    Label("Settle Up", systemImage: "arrow.right.circle")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .tint(.pink)
            }

            Divider()

            ForEach(transfers) { transfer in
                HStack(spacing: 8) {
                    MemberAvatar(name: transfer.fromName, size: 24)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                    MemberAvatar(name: transfer.toName, size: 24)
                    Text("\(transfer.fromName) pays \(transfer.toName)")
                        .font(.caption)
                    Spacer()
                    Text(formatCents(transfer.amount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.1), in: .capsule)
                }
            }
        }
        .padding(14)
        .background(.background, in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }

    // MARK: - Expense Cards (Individual)

    private var expenseCards: some View {
        VStack(spacing: 10) {
            if expenses.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Text("No expenses yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Tap below to add your first expense.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .foregroundStyle(.quaternary)
                )
            } else {
                ForEach(expenses) { expense in
                    ExpenseCard(expense: expense)
                }
            }
        }
    }

    // MARK: - History Card (Grouped)

    private var historyCard: some View {
        VStack(spacing: 0) {
            let maxCents = settlements.map(\.totalCents).max() ?? 1
            ForEach(settlements) { settlement in
                NavigationLink(value: settlement) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(settlement.settledAt, format: .dateTime.month(.abbreviated).day().year())
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(formatCents(settlement.totalCents))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        HStack(spacing: 6) {
                            // Weight bar
                            let fraction = CGFloat(settlement.totalCents) / CGFloat(maxCents)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.25))
                                .frame(width: 48 * fraction, height: 4)
                                .frame(width: 48, alignment: .leading)

                            Text("\(settlement.expenseCount) expenses")
                            Text("·")
                                .foregroundStyle(.quaternary)
                            Text(relativeTime(settlement.settledAt))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)

                if settlement.id != settlements.last?.id {
                    Divider().padding(.horizontal, 14)
                }
            }
        }
        .background(.background, in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }

    // MARK: - Fixed Add Expense Bar

    private var addExpenseBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            Button {
                showingAddExpense = true
            } label: {
                Label("Add Expense", systemImage: "plus")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(.bar)
    }

    // MARK: - Section Label

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .tracking(0.3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    // MARK: - Helpers

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Expense Card

private struct ExpenseCard: View {
    let expense: Expense

    // Gradient colors from the payer's avatar for accent line
    private var accentColor: Color {
        let gradients: [Color] = [
            .purple, .blue, .teal, .orange, .indigo, .green, .pink, .cyan
        ]
        let hash = abs(expense.paidByName.hashValue)
        return gradients[hash % gradients.count]
    }

    var body: some View {
        HStack(spacing: 12) {
            // Accent line
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor.opacity(0.5))
                .frame(width: 3)

            MemberAvatar(name: expense.paidByName, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(expense.paidByName)
                        .fontWeight(.medium)
                    Text("paid")
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text("split \(expense.splitCount)")
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text(relativeTime(expense.createdAt))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatCents(expense.amount))
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(.background, in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        GroupDetailScreen(groupId: "1")
            .environment(GroupStore())
    }
}
