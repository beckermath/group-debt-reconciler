import SwiftUI

struct AddExpenseScreen: View {
    let groupId: String
    let memberList: [GroupMember]  // actual members from API
    let currentUserId: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(GroupStore.self) private var groupStore

    @State private var description = ""
    @State private var amount = ""
    @State private var paidByMemberId = ""
    @State private var selectedMemberIds: Set<String> = []
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var error: String?

    private var isValid: Bool {
        !description.trimmingCharacters(in: .whitespaces).isEmpty
        && (Double(amount) ?? 0) > 0
        && !paidByMemberId.isEmpty
        && !selectedMemberIds.isEmpty
    }

    private var currentMember: GroupMember? {
        memberList.first { $0.userId == currentUserId }
    }

    var body: some View {
        if showSuccess {
            successView
        } else {
            formView
        }
    }

    // MARK: - Form

    private var formView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Dinner, taxi, groceries...", text: $description)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Amount
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack {
                            Text("$")
                                .foregroundStyle(.secondary)
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // Paid by
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paid by")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(memberList) { member in
                                    Button {
                                        paidByMemberId = member.id
                                    } label: {
                                        VStack(spacing: 4) {
                                            MemberAvatar(name: member.name, size: 40, selected: paidByMemberId == member.id)
                                            Text(member.userId == currentUserId ? "Me" : member.name.components(separatedBy: " ").first ?? member.name)
                                                .font(.caption2)
                                                .fontWeight(paidByMemberId == member.id ? .semibold : .regular)
                                                .foregroundStyle(paidByMemberId == member.id ? .primary : .secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Split between
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Split between")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Button(selectedMemberIds.count == memberList.count ? "Deselect All" : "Select All") {
                                if selectedMemberIds.count == memberList.count {
                                    selectedMemberIds = Set([currentMember?.id].compactMap { $0 })
                                } else {
                                    selectedMemberIds = Set(memberList.map(\.id))
                                }
                            }
                            .font(.caption)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 10) {
                            ForEach(memberList) { member in
                                Button {
                                    if selectedMemberIds.contains(member.id) {
                                        selectedMemberIds.remove(member.id)
                                    } else {
                                        selectedMemberIds.insert(member.id)
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        MemberAvatar(name: member.name, size: 36)
                                            .opacity(selectedMemberIds.contains(member.id) ? 1 : 0.4)
                                        Text(member.name.components(separatedBy: " ").first ?? member.name)
                                            .font(.caption2)
                                            .foregroundStyle(selectedMemberIds.contains(member.id) ? .primary : .secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !selectedMemberIds.isEmpty, let amt = Double(amount), amt > 0 {
                            let perPerson = amt / Double(selectedMemberIds.count)
                            Text("Each person pays: $\(String(format: "%.2f", perPerson))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .padding(.bottom, 80)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground)],
                    startPoint: .top, endPoint: .bottom
                ).frame(height: 20)

                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(isValid ? "Add Expense ($\(amount))" : "Add Expense")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isValid || isSubmitting)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(.bar)
        }
        .navigationTitle("Add Expense")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if paidByMemberId.isEmpty {
                paidByMemberId = currentMember?.id ?? memberList.first?.id ?? ""
            }
            if selectedMemberIds.isEmpty {
                selectedMemberIds = Set(memberList.map(\.id))
            }
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Expense added")
                .font(.headline)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarBackButtonHidden()
    }

    // MARK: - Submit

    private func submit() async {
        error = nil
        isSubmitting = true

        do {
            try await groupStore.addExpense(
                groupId: groupId,
                description: description.trimmingCharacters(in: .whitespaces),
                amount: Double(amount) ?? 0,
                paidBy: paidByMemberId,
                splitWith: Array(selectedMemberIds)
            )
            await groupStore.loadGroupDetail(id: groupId)
            withAnimation(.spring(duration: 0.4)) {
                showSuccess = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                dismiss()
            }
        } catch let apiError as APIError {
            error = apiError.errorDescription
            isSubmitting = false
        } catch {
            self.error = "Failed to add expense"
            isSubmitting = false
        }
    }
}

#Preview {
    NavigationStack {
        AddExpenseScreen(
            groupId: "test",
            memberList: [
                GroupMember(id: "m1", name: "Alice", userId: "u1", isRemoved: false),
                GroupMember(id: "m2", name: "Bob", userId: nil, isRemoved: false),
                GroupMember(id: "m3", name: "Carol", userId: nil, isRemoved: false),
            ],
            currentUserId: "u1"
        )
        .environment(GroupStore())
    }
}
