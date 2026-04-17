import SwiftUI

struct ExpenseDetailScreen: View {
    let expense: Expense
    let groupId: String
    var onEdited: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(GroupStore.self) private var groupStore
    @State private var showDeleteConfirmation = false
    @State private var showEditExpense = false
    @State private var editWasSaved = false
    @State private var isDeleting = false
    @State private var error: String?

    private var members: [GroupMember] {
        if case .loaded(let detail) = groupStore.detailState {
            return detail.members
        }
        return []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Amount + description
                    VStack(spacing: 6) {
                        Text(formatCents(expense.amount))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.brandPrimary)
                        Text(expense.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(expense.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // Paid by card
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            MemberAvatar(name: expense.paidByName, imageUrl: expense.paidByImageUrl, size: 32)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Paid by")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text(expense.paidByName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                            Text(formatCents(expense.amount))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    }
                    .background(.background, in: .rect(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                    .padding(.horizontal, 16)

                    // Split details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SPLIT BETWEEN")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            detailRow(label: "People", value: "\(expense.splitCount)")
                            Divider().padding(.horizontal, 16)
                            detailRow(label: "Per person", value: formatCents(expense.amount / max(expense.splitCount, 1)))
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
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
            .background(WarmGradientBackground().ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showEditExpense = true } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
            .sheet(isPresented: $showEditExpense, onDismiss: {
                if editWasSaved {
                    onEdited?()
                    dismiss()
                    editWasSaved = false
                }
            }) {
                AddExpenseScreen(
                    groupId: groupId,
                    memberList: members,
                    currentUserId: nil,
                    editingExpenseId: expense.id,
                    prefill: expense,
                    onSaved: { editWasSaved = true }
                )
            }
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
        .sensoryFeedback(.warning, trigger: isDeleting)
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
        .padding(.horizontal, 16)
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
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            ExpenseDetailScreen(expense: Expense.previews[0], groupId: "1")
                .environment(GroupStore())
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
}
