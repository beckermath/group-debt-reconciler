import SwiftUI

struct SplitModeScreen: View {
    @Bindable var model: AddExpenseModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedMemberId: String?

    private var selectedIds: [String] {
        model.selectedMemberArray.map(\.id)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    // Mode picker
                    Picker("Split mode", selection: $model.splitMode) {
                        ForEach(SplitMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Mode content
                    switch model.splitMode {
                    case .equal:
                        equalContent
                    case .custom:
                        customContent
                    case .percent:
                        percentContent
                    }
                }
                .padding()
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: focusedMemberId) { _, newId in
                if let newId {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focusedMemberId != nil {
                    Button { focusPrevious() } label: {
                        Image(systemName: "chevron.up")
                    }
                    Button { focusNext() } label: {
                        Image(systemName: "chevron.down")
                    }
                    Spacer()
                    remainingLabel
                    Spacer()
                    Button("Done") { focusedMemberId = nil }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(WarmGradientBackground().ignoresSafeArea())
        .navigationTitle("Split")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: - Remaining Label

    private var remainingLabel: some View {
        Group {
            if model.splitMode == .custom {
                Text("Remaining: \(formatCents(model.remainingCents))")
            } else {
                Text("Remaining: \(String(format: "%.1f%%", model.remainingPercent))")
            }
        }
        .font(.caption)
        .foregroundStyle(
            (model.splitMode == .custom ? model.remainingCents == 0 : abs(model.remainingPercent) < 0.01)
                ? Color.balancePositive : .secondary
        )
    }

    // MARK: - Equal

    private var equalContent: some View {
        VStack(spacing: 16) {
            if !model.selectedMemberIds.isEmpty, model.amountCents > 0 {
                VStack(spacing: 4) {
                    Text(formatCents(model.amountCents / model.selectedMemberIds.count))
                        .font(.system(size: 28, weight: .bold))
                    Text("per person")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            ForEach(model.selectedMemberArray) { member in
                HStack(spacing: 10) {
                    MemberAvatar(name: member.name, imageUrl: member.imageUrl, size: 36)
                    Text(model.displayName(for: member))
                        .font(.subheadline)
                    Spacer()
                    Text(formatCents(model.amountCents / max(model.selectedMemberIds.count, 1)))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Custom

    private var customContent: some View {
        VStack(spacing: 10) {
            ForEach(model.selectedMemberArray) { member in
                HStack(spacing: 10) {
                    MemberAvatar(name: member.name, imageUrl: member.imageUrl, size: 36)
                    Text(model.displayName(for: member))
                        .font(.subheadline)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("$")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: Binding(
                            get: { model.customAmounts[member.id] ?? "" },
                            set: { model.customAmounts[member.id] = $0 }
                        ))
                        .keyboardType(.decimalPad)
                        .font(.subheadline.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .focused($focusedMemberId, equals: member.id)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6), in: .rect(cornerRadius: 10))
                }
                .id(member.id)
            }

            HStack {
                Text("Remaining:")
                    .font(.caption)
                    .fontWeight(.medium)
                Text(formatCents(model.remainingCents))
                    .font(.caption.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        model.remainingCents == 0 && model.amountCents > 0
                            ? Color.balancePositive
                            : model.remainingCents < 0
                                ? Color.balanceNegative
                                : .secondary
                    )
                Spacer()
                if model.remainingCents > 0 {
                    Button("Distribute") { model.distributeRemaining() }
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Percent

    private var percentContent: some View {
        VStack(spacing: 10) {
            ForEach(model.selectedMemberArray) { member in
                HStack(spacing: 10) {
                    MemberAvatar(name: member.name, imageUrl: member.imageUrl, size: 36)
                    Text(model.displayName(for: member))
                        .font(.subheadline)
                    Spacer()

                    let pct = Double(model.percentages[member.id] ?? "0") ?? 0
                    let memberCents = Int(round(pct / 100.0 * Double(model.amountCents)))
                    Text(formatCents(memberCents))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        TextField("0", text: Binding(
                            get: { model.percentages[member.id] ?? "" },
                            set: { model.percentages[member.id] = $0 }
                        ))
                        .keyboardType(.decimalPad)
                        .font(.subheadline.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(width: 56)
                        .focused($focusedMemberId, equals: member.id)
                        Text("%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6), in: .rect(cornerRadius: 10))
                }
                .id(member.id)
            }

            HStack {
                Text("Remaining:")
                    .font(.caption)
                    .fontWeight(.medium)
                Text(String(format: "%.1f%%", model.remainingPercent))
                    .font(.caption.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        abs(model.remainingPercent) < 0.01
                            ? Color.balancePositive
                            : model.remainingPercent < 0
                                ? Color.balanceNegative
                                : .secondary
                    )
                Spacer()
                if abs(model.remainingPercent) > 0.01 {
                    Button("Split Equally") { model.distributeEqualPercentages() }
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Focus Navigation

    private func focusNext() {
        guard let current = focusedMemberId,
              let idx = selectedIds.firstIndex(of: current),
              idx + 1 < selectedIds.count else {
            focusedMemberId = nil
            return
        }
        focusedMemberId = selectedIds[idx + 1]
    }

    private func focusPrevious() {
        guard let current = focusedMemberId,
              let idx = selectedIds.firstIndex(of: current),
              idx > 0 else { return }
        focusedMemberId = selectedIds[idx - 1]
    }
}
