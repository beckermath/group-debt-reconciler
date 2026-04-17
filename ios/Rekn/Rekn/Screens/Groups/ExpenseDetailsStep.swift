import SwiftUI

enum ExpenseField: Hashable { case description, amount }

struct ExpenseDetailsStep: View {
    @Bindable var model: AddExpenseModel
    @Binding var path: NavigationPath
    let onSubmit: () async -> Void
    var focusedField: FocusState<ExpenseField?>.Binding
    var title: String = "Add Expense"

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Amount (hero) with payer indicator
                amountField
                    .padding(.bottom, 16)

                // Description
                descriptionField
                    .padding(.bottom, 20)

                // Who's involved
                membersSection
                    .padding(.bottom, 20)

                // Split preview
                if model.amountCents > 0, !model.selectedMemberIds.isEmpty {
                    splitPreview
                        .padding(.bottom, 12)
                }

                // Error
                if let error = model.error {
                    errorBanner(error)
                }
            }
            .padding()
            .padding(.bottom, 48)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(WarmGradientBackground().ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Amount Field

    private var amountField: some View {
        HStack(alignment: .center, spacing: 0) {
            // Amount input with integrated dollar sign and underline
            VStack(spacing: 4) {
                HStack(spacing: 1) {
                    Text("$")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(model.amount.isEmpty ? .quaternary : .primary)

                    TextField("0.00", text: $model.amount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 40, weight: .bold))
                        .multilineTextAlignment(.leading)
                        .focused(focusedField, equals: .amount)
                }

                Color.brand.opacity(0.15)
                    .frame(height: 2)
                    .clipShape(.rect(cornerRadius: 1))
            }

            Spacer(minLength: 12)

            // Payer indicator pill
            Button {
                path.append(AddExpenseStep.payerSelection)
            } label: {
                HStack(spacing: 6) {
                    MemberAvatar(name: payerMember?.name ?? "?", imageUrl: payerMember?.imageUrl, size: 24)
                    Text(model.paidByName + " paid")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.leading, 4)
                .padding(.trailing, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray6), in: .capsule)
            }
            .buttonStyle(.plain)
            .layoutPriority(1)
        }
        .padding(.vertical, 4)
    }

    private var payerMember: GroupMember? {
        model.memberList.first { $0.id == model.paidByMemberId }
    }

    // MARK: - Description Field

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WHAT'S IT FOR?")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(0.3)
            TextField("Dinner, taxi, groceries...", text: $model.description)
                .submitLabel(.next)
                .onSubmit { focusedField.wrappedValue = .amount }
                .focused(focusedField, equals: .description)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6), in: .rect(cornerRadius: 10))
        }
    }

    // MARK: - Split Preview

    private var splitPreview: some View {
        Button {
            path.append(AddExpenseStep.splitMode)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(model.splitMode.label + " split")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("\(model.selectedMemberIds.count) \(model.selectedMemberIds.count == 1 ? "person" : "people")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if model.splitMode == .equal {
                    let count = model.selectedMemberIds.count
                    let perPerson = model.amountCents / count
                    let remainder = model.amountCents - (perPerson * count)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formatCents(perPerson) + " / person")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.brand)
                        if remainder > 0 {
                            Text("(+\(formatCents(1)) to \(remainder))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } else {
                    let breakdown = model.computeSplitBreakdown()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(breakdown.enumerated()), id: \.element.member.id) { index, item in
                                if index > 0 {
                                    Text("\u{00B7}")
                                        .foregroundStyle(.quaternary)
                                }
                                Text("\(model.displayName(for: item.member)) \(formatCents(item.cents))")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemGray6), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Members Section

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("WHO'S INVOLVED")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .tracking(0.3)
                Spacer()
                Button(model.selectedMemberIds.count == model.memberList.count ? "Deselect All" : "Select All") {
                    if model.selectedMemberIds.count == model.memberList.count {
                        model.setSelectedMembers([])
                    } else {
                        model.setSelectedMembers(Set(model.memberList.map(\.id)))
                    }
                }
                .font(.caption)
                .fontWeight(.medium)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(model.memberList) { member in
                        Button { model.toggleMember(member.id) } label: {
                            MemberChip(
                                name: member.name,
                                imageUrl: member.imageUrl,
                                displayName: model.displayName(for: member),
                                isSelected: model.selectedMemberIds.contains(member.id),
                                size: 38
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(Color.balanceNegative)
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.balanceNegative)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.balanceNegative.opacity(0.08), in: .rect(cornerRadius: 10))
    }

}

// MARK: - Member Chip

struct MemberChip: View {
    let name: String
    var imageUrl: String? = nil
    let displayName: String
    let isSelected: Bool
    let size: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            MemberAvatar(name: name, imageUrl: imageUrl, size: size, selected: isSelected)
            Text(displayName)
                .font(.caption2)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
        }
        .opacity(isSelected ? 1 : 0.55)
    }
}
