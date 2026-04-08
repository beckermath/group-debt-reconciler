import SwiftUI

struct SettleUpScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GroupStore.self) private var groupStore
    let groupId: String
    let transfers: [Transfer]
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showConfirmation = false
    @State private var error: String?

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
                        MemberAvatar(name: transfer.fromName, imageUrl: transfer.fromImageUrl, size: 28)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                        MemberAvatar(name: transfer.toName, imageUrl: transfer.toImageUrl, size: 28)
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

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.balanceNegative)
            }

            // Confirm button
            Button {
                showConfirmation = true
            } label: {
                if isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Confirm settlement")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isSubmitting)
            .confirmationDialog(
                "Settle all debts?",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Settle \(formatCents(totalCents))", role: .destructive) {
                    submit()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will mark all current debts as settled. This cannot be undone.")
            }
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.balancePositive)
            Text("All settled up!")
                .font(.headline)
            Text("No payments needed right now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Submit

    private func submit() {
        isSubmitting = true
        Task {
            do {
                try await groupStore.settleUp(groupId: groupId)
                await groupStore.loadGroupDetail(id: groupId, forceReload: true)
                withAnimation {
                    showSuccess = true
                }
            } catch let apiError as APIError {
                error = apiError.errorDescription
                isSubmitting = false
            } catch {
                self.error = "Failed to settle up"
                isSubmitting = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettleUpScreen(groupId: "test", transfers: Transfer.previews)
            .environment(GroupStore())
    }
}
