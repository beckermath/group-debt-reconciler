import SwiftUI

struct ExpenseDetailScreen: View {
    let expense: Expense
    let groupId: String

    @Environment(\.dismiss) private var dismiss
    @Environment(GroupStore.self) private var groupStore
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero amount
                VStack(spacing: 8) {
                    Text(formatCents(expense.amount))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text(expense.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)

                // Details card
                SectionCard(header: "Details") {
                    VStack(spacing: 0) {
                        detailRow(label: "Paid by", value: expense.paidByName)
                        Divider().padding(.horizontal, 12)
                        detailRow(label: "Split between", value: "\(expense.splitCount) people")
                        Divider().padding(.horizontal, 12)
                        detailRow(label: "Per person", value: formatCents(expense.amount / max(expense.splitCount, 1)))
                        Divider().padding(.horizontal, 12)
                        detailRow(label: "Date", value: expense.createdAt.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))
                    }
                }
                .padding(.horizontal)

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.balanceNegative)
                        .padding(.horizontal)
                }

                // Delete button
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    if isDeleting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Expense")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isDeleting)
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Expense")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this expense?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await deleteExpense() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove \"\(expense.description)\" and recalculate all balances. This cannot be undone.")
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }

    private func deleteExpense() async {
        isDeleting = true
        error = nil
        do {
            try await groupStore.deleteExpense(groupId: groupId, expenseId: expense.id)
            await groupStore.loadGroupDetail(id: groupId, forceReload: true)
            dismiss()
        } catch let apiError as APIError {
            error = apiError.errorDescription
            isDeleting = false
        } catch {
            self.error = "Failed to delete expense"
            isDeleting = false
        }
    }
}

#Preview {
    NavigationStack {
        ExpenseDetailScreen(expense: Expense.previews[0], groupId: "1")
            .environment(GroupStore())
    }
}
