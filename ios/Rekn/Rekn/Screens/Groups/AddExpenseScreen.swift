import SwiftUI

struct AddExpenseScreen: View {
    let groupId: String
    let memberList: [GroupMember]
    let currentUserId: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(GroupStore.self) private var groupStore
    @State private var model: AddExpenseModel
    @State private var path = NavigationPath()
    @FocusState private var focusedField: ExpenseField?

    init(groupId: String, memberList: [GroupMember], currentUserId: String?) {
        self.groupId = groupId
        self.memberList = memberList
        self.currentUserId = currentUserId
        self._model = State(initialValue: AddExpenseModel(
            groupId: groupId, memberList: memberList, currentUserId: currentUserId
        ))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ExpenseDetailsStep(model: model, path: $path, onSubmit: submit, focusedField: $focusedField)
                .task {
                    // Only auto-focus on initial presentation, not when navigating back
                    if model.amount.isEmpty {
                        focusedField = .amount
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if model.isSubmitting {
                            ProgressView()
                        } else {
                            Button("Save") {
                                Task { await submit() }
                            }
                            .fontWeight(.semibold)
                            .disabled(!model.isValid || model.isSubmitting)
                        }
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(focusedField == .amount ? "Next" : "Done") {
                            if focusedField == .amount {
                                focusedField = .description
                            } else {
                                focusedField = nil
                            }
                        }
                        .fontWeight(.medium)
                    }
                }
                .navigationDestination(for: AddExpenseStep.self) { step in
                    switch step {
                    case .payerSelection:
                        PayerSelectionScreen(model: model)
                    case .splitMode:
                        SplitModeScreen(model: model)
                    }
                }
        }
    }

    // MARK: - Submit

    private func submit() async {
        model.error = nil
        model.isSubmitting = true

        let resolvedSplitMode: String
        let resolvedCustomAmounts: [String: String]

        switch model.splitMode {
        case .equal:
            resolvedSplitMode = "equal"
            resolvedCustomAmounts = [:]
        case .custom:
            resolvedSplitMode = "custom"
            resolvedCustomAmounts = model.customAmounts
        case .percent:
            resolvedSplitMode = "custom"
            guard let converted = percentagesToCustomAmounts(
                percentages: model.percentages,
                selectedMemberIds: model.selectedMemberIds,
                totalCents: model.amountCents
            ) else {
                model.error = "Percentages must sum to 100%"
                model.isSubmitting = false
                return
            }
            resolvedCustomAmounts = converted
        }

        do {
            try await groupStore.addExpense(
                groupId: model.groupId,
                description: model.description.trimmingCharacters(in: .whitespaces),
                amount: Double(model.amount) ?? 0,
                paidBy: model.paidByMemberId,
                splitWith: Array(model.selectedMemberIds),
                splitMode: resolvedSplitMode,
                customAmounts: resolvedCustomAmounts
            )
            await groupStore.loadGroupDetail(id: model.groupId, forceReload: true)
            dismiss()
        } catch let apiError as APIError {
            model.error = apiError.errorDescription
            model.isSubmitting = false
        } catch {
            model.error = "Failed to add expense"
            model.isSubmitting = false
        }
    }
}

#Preview {
    NavigationStack {
        AddExpenseScreen(
            groupId: "test",
            memberList: [
                GroupMember(id: "m1", name: "Alice", userId: "u1", isRemoved: false, imageUrl: nil),
                GroupMember(id: "m2", name: "Bob", userId: nil, isRemoved: false, imageUrl: nil),
                GroupMember(id: "m3", name: "Carol", userId: nil, isRemoved: false, imageUrl: nil),
            ],
            currentUserId: "u1"
        )
        .environment(GroupStore())
    }
}
