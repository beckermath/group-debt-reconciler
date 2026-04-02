import SwiftUI

struct SettleUpScreen: View {
    @Environment(\.dismiss) private var dismiss
    let transfers: [Transfer]
    @State private var isSubmitting = false
    @State private var showSuccess = false

    private var totalCents: Int {
        transfers.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if showSuccess {
                    successView
                } else {
                    formContent
                }
            }
            .padding()
        }
        .navigationTitle("Settle all debts?")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSubmitting || showSuccess)
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(spacing: 20) {
            Text("This will mark all current debts as settled. New expenses will start with a clean slate.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Summary header
            HStack {
                Text("\(transfers.count) payment\(transfers.count == 1 ? "" : "s") to settle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(formatCents(totalCents)) total")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            // Transfer list
            VStack(spacing: 8) {
                ForEach(transfers) { transfer in
                    HStack {
                        MemberAvatar(name: transfer.fromName, size: 28)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                        MemberAvatar(name: transfer.toName, size: 28)
                        VStack(alignment: .leading) {
                            Text("\(transfer.fromName) pays \(transfer.toName)")
                                .font(.subheadline)
                        }
                        Spacer()
                        Text(formatCents(transfer.amount))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1), in: .capsule)
                    }
                    .padding(12)
                    .background(Color(.systemGray6), in: .rect(cornerRadius: 10))
                }
            }

            // Confirm button
            Button {
                submit()
            } label: {
                Text("Confirm settlement")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .controlSize(.large)
            .disabled(isSubmitting)
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("All settled up!")
                .font(.headline)
            Text("No payments needed right now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        SettleUpScreen(transfers: Transfer.previews)
    }
}
