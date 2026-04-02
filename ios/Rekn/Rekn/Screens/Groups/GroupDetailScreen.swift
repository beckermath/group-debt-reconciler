import SwiftUI

struct GroupDetailScreen: View {
    let groupId: String
    @State private var selectedTab = 0
    @State private var showingAddExpense = false
    @State private var showingAddPeople = false
    @State private var showingSettleUp = false

    // Preview data
    private let balances = BalanceEntry.previews
    private let transfers = Transfer.previews
    private let expenses = Expense.previews

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Balances card
                balancesCard

                // Segmented picker
                Picker("Section", selection: $selectedTab) {
                    Text("Expenses (\(expenses.count))").tag(0)
                    Text("Members (3)").tag(1)
                    Text("History").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Tab content
                switch selectedTab {
                case 0: expensesTab
                case 1: membersTab
                case 2: historyTab
                default: EmptyView()
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle("Ski Trip")
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
        .navigationDestination(isPresented: $showingAddExpense) {
            AddExpenseScreen()
        }
        .navigationDestination(isPresented: $showingAddPeople) {
            AddPeopleScreen()
        }
        .navigationDestination(isPresented: $showingSettleUp) {
            SettleUpScreen(transfers: transfers)
        }
    }

    // MARK: - Balances Card

    private var balancesCard: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Balances")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddExpense = true
                } label: {
                    Label("Add Expense", systemImage: "plus")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
            }

            // Balance entries
            VStack(spacing: 12) {
                ForEach(balances) { entry in
                    HStack(spacing: 10) {
                        MemberAvatar(name: entry.name, size: 32)
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
            }

            Divider()

            // Transfers
            VStack(spacing: 8) {
                Text("\(transfers.count) payment\(transfers.count == 1 ? "" : "s") to settle")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(transfers) { transfer in
                    HStack(spacing: 10) {
                        MemberAvatar(name: transfer.fromName, size: 28)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                        MemberAvatar(name: transfer.toName, size: 28)
                        Text("\(transfer.fromName) pays \(transfer.toName)")
                            .font(.subheadline)
                        Spacer()
                        Text(formatCents(transfer.amount))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1), in: .capsule)
                    }
                }
            }

            // Settle up button
            Button {
                showingSettleUp = true
            } label: {
                Text("Settle Up")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .controlSize(.large)
        }
        .padding()
        .background(.background, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        .padding(.horizontal)
    }

    // MARK: - Expenses Tab

    private var expensesTab: some View {
        LazyVStack(spacing: 0) {
            ForEach(expenses) { expense in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(expense.description)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(formatCents(expense.amount))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text("\(expense.paidByName) paid · split \(expense.splitCount) way\(expense.splitCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {} label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {} label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                Divider().padding(.leading)
            }
        }
        .background(.background, in: .rect(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Members Tab

    private var membersTab: some View {
        VStack(spacing: 0) {
            ForEach(["Alice", "Bob", "Carol"], id: \.self) { name in
                HStack(spacing: 12) {
                    MemberAvatar(name: name, size: 36)
                    Text(name)
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.horizontal)
                if name != "Carol" {
                    Divider().padding(.leading, 60)
                }
            }
        }
        .background(.background, in: .rect(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - History Tab

    private var historyTab: some View {
        VStack(spacing: 16) {
            Text("No settlements yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

#Preview {
    NavigationStack {
        GroupDetailScreen(groupId: "1")
    }
}
