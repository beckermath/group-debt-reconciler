import SwiftUI

struct PendingInvitesCard: View {
    let invites: [PendingInvite]
    let onAccept: (PendingInvite) -> Void
    let onDecline: (PendingInvite) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ForEach(Array(invites.enumerated()), id: \.element.id) { index, invite in
                if index > 0 {
                    Divider().padding(.leading, 16)
                }
                InviteRow(
                    invite: invite,
                    onAccept: { onAccept(invite) },
                    onDecline: { onDecline(invite) }
                )
            }
        }
        .background(Color.brandSecondary.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.brandSecondary.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.brandSecondary)
            Text("Pending invites")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("(\(invites.count))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
}

private struct InviteRow: View {
    let invite: PendingInvite
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var showingDeclineConfirm = false
    @State private var isProcessing = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            MemberAvatar(name: invite.inviterName, imageUrl: nil, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(invite.groupName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("Invited by \(invite.inviterName) · \(invite.createdAt.relativeFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isProcessing {
                ProgressView().controlSize(.small)
                    .padding(.trailing, 4)
            } else {
                VStack(spacing: 6) {
                    Button(action: handleAccept) {
                        Text("Accept")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(minWidth: 64)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Color.brandSecondary)

                    Button { showingDeclineConfirm = true } label: {
                        Text("Decline")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(minWidth: 64)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .confirmationDialog(
            "Decline invite to \(invite.groupName)?",
            isPresented: $showingDeclineConfirm,
            titleVisibility: .visible
        ) {
            Button("Decline", role: .destructive) { handleDecline() }
            Button("Cancel", role: .cancel) {}
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Invite to \(invite.groupName) from \(invite.inviterName)")
        .accessibilityAction(named: "Accept") { handleAccept() }
        .accessibilityAction(named: "Decline") { showingDeclineConfirm = true }
    }

    private func handleAccept() {
        isProcessing = true
        onAccept()
    }

    private func handleDecline() {
        isProcessing = true
        onDecline()
    }
}

#Preview("With invites") {
    VStack {
        PendingInvitesCard(
            invites: PendingInvite.previews,
            onAccept: { _ in },
            onDecline: { _ in }
        )
        .padding()
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}
