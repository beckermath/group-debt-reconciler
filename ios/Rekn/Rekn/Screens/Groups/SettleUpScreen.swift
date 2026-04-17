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
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if showSuccess {
                        successView
                    } else {
                        formContent
                    }
                }
                .padding(16)
            }
            .background(WarmGradientBackground().ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !showSuccess {
                        Button("Cancel") { dismiss() }
                            .disabled(isSubmitting)
                    }
                }
            }
            .interactiveDismissDisabled(isSubmitting)
        }
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                Text("Settle Up")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Review transfers to settle all balances")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            // Transfer list card
            VStack(spacing: 0) {
                ForEach(Array(transfers.enumerated()), id: \.element.id) { index, transfer in
                    HStack(spacing: 12) {
                        MemberAvatar(name: transfer.fromName, imageUrl: transfer.fromImageUrl, size: 28)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        MemberAvatar(name: transfer.toName, imageUrl: transfer.toImageUrl, size: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(transfer.fromName) pays")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(transfer.toName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Spacer()
                        Text(formatCents(transfer.amount))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.brandPrimary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)

                    if index < transfers.count - 1 {
                        Divider().padding(.horizontal, 16)
                    }
                }

                // Total row
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                HStack {
                    Text("Total")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(formatCents(totalCents))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.brandPrimary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
            .background(.background, in: .rect(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.balanceNegative)
            }

            // Confirm button
            Button {
                showConfirmation = true
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        Image(systemName: "arrow.trianglehead.clockwise")
                            .symbolEffect(.rotate, isActive: isSubmitting)
                    }
                    Text(isSubmitting ? "Settling..." : "Confirm Settlement")
                }
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .background(Color.brandPrimary, in: .rect(cornerRadius: 12))
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
                .font(.system(size: 48))
                .foregroundStyle(Color.balancePositive)
                .symbolEffect(.bounce, value: showSuccess)
            Text("All settled up!")
                .font(.headline)
            Text("No payments needed right now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .sensoryFeedback(.success, trigger: showSuccess)
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        }
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
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            SettleUpScreen(groupId: "test", transfers: Transfer.previews)
                .environment(GroupStore())
                .presentationDetents([.medium, .fraction(0.6)])
                .presentationDragIndicator(.visible)
        }
}
