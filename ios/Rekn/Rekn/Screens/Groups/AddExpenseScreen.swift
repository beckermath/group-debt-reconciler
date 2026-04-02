import SwiftUI

struct AddExpenseScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var description = ""
    @State private var amount = ""
    @State private var paidBy = "Alice"
    @State private var splitMode = "equal"
    @State private var selectedMembers: Set<String> = ["Alice", "Bob", "Carol"]
    @State private var isSubmitting = false
    @State private var showSuccess = false

    private let members = ["Alice", "Bob", "Carol"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if showSuccess {
                    successView
                } else {
                    formContent
                }
            }
            .padding()
        }
        .navigationTitle("Add Expense")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSubmitting || showSuccess)
    }

    // MARK: - Form

    private var formContent: some View {
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
                HStack(spacing: 0) {
                    Text("$")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8))
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 8, topTrailingRadius: 8))
                }
            }

            // Paid by
            VStack(alignment: .leading, spacing: 8) {
                Text("Paid by")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("Paid by", selection: $paidBy) {
                    ForEach(members, id: \.self) { name in
                        Text(name == "Alice" ? "Alice (Me)" : name).tag(name)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(.systemGray6), in: .rect(cornerRadius: 8))
            }

            // Split between
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Split between")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Mode", selection: $splitMode) {
                        Text("Equal").tag("equal")
                        Text("Custom").tag("custom")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                ForEach(members, id: \.self) { name in
                    HStack {
                        MemberAvatar(name: name, size: 28)
                        Text(name)
                            .font(.subheadline)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { selectedMembers.contains(name) },
                            set: { isOn in
                                if isOn { selectedMembers.insert(name) }
                                else { selectedMembers.remove(name) }
                            }
                        ))
                        .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
            }

            // Submit
            Button {
                submit()
            } label: {
                Text("Add Expense")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(description.isEmpty || amount.isEmpty || isSubmitting)
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
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Submit

    private func submit() {
        isSubmitting = true
        // TODO: API call
        withAnimation {
            showSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        AddExpenseScreen()
    }
}
