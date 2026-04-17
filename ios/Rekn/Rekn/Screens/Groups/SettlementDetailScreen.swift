import SwiftUI

struct SettlementDetailScreen: View {
    let settlement: Settlement
    let groupId: String
    let includedExpenses: [Expense]
    @Environment(\.dismiss) private var dismiss
    @Environment(GroupStore.self) private var groupStore
    @State private var showUndoConfirmation = false
    @State private var isUndoing = false
    @State private var showExpenses = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 6) {
                        Text("Settlement")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(settlement.settledAt.formatted(.dateTime.month(.wide).day().year()))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // Details card
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            gridCell(label: "Settled by", value: settlement.settledByName)
                            Divider()
                            gridCell(label: "Expenses", value: "\(settlement.expenseCount)")
                        }
                        .frame(height: 60)

                        Divider()

                        VStack(spacing: 2) {
                            Text("Total amount")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatCents(settlement.totalCents))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.brandPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .background(.background, in: .rect(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                    .padding(.horizontal, 16)

                    // Expenses collapsible
                    if !includedExpenses.isEmpty {
                        VStack(spacing: 0) {
                            Button {
                                withAnimation(.snappy(duration: 0.25)) {
                                    showExpenses.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("\(includedExpenses.count) expense\(includedExpenses.count == 1 ? "" : "s") included")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: showExpenses ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.primary)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if showExpenses {
                                Divider().padding(.horizontal, 16)

                                ForEach(Array(includedExpenses.enumerated()), id: \.element.id) { index, expense in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(expense.description)
                                                .font(.subheadline)
                                                .lineLimit(1)
                                            Text("\(expense.paidByName) paid")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(formatCents(expense.amount))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .monospacedDigit()
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)

                                    if index < includedExpenses.count - 1 {
                                        Divider().padding(.horizontal, 16)
                                    }
                                }
                            }
                        }
                        .background(.background, in: .rect(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                        .padding(.horizontal, 16)
                    }

                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.balanceNegative)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .background(WarmGradientBackground().ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if isUndoing {
                        ProgressView()
                    } else {
                        Button {
                            showUndoConfirmation = true
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                    }
                }
            }
            .confirmationDialog(
                "Undo this settlement?",
                isPresented: $showUndoConfirmation,
                titleVisibility: .visible
            ) {
                Button("Undo Settlement", role: .destructive) {
                    Task { await undoSettlement() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will revert balances to before this settlement. Only the most recent settlement can be undone.")
            }
            .sensoryFeedback(.warning, trigger: isUndoing)
        }
    }

    private func gridCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private func undoSettlement() async {
        isUndoing = true
        error = nil
        do {
            try await groupStore.undoSettlement(groupId: groupId, settlementId: settlement.id)
            await groupStore.loadGroupDetail(id: groupId, forceReload: true)
            dismiss()
        } catch let apiError as APIError {
            error = apiError.errorDescription
            isUndoing = false
        } catch {
            self.error = "Failed to undo settlement"
            isUndoing = false
        }
    }
}

#Preview {
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            SettlementDetailScreen(
                settlement: Settlement.previews[0],
                groupId: "1",
                includedExpenses: Expense.previews
            )
            .environment(GroupStore())
            .presentationDetents([.fraction(0.35), .medium])
            .presentationDragIndicator(.visible)
        }
}
