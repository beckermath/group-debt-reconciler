import SwiftUI

/// Section header for the pending-invites list. Renders inside the teal
/// region of GroupsListScreen, above the stack of individual invite cards.
struct PendingInvitesSectionHeader: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.brandSecondary)
            Text("Pending invites")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.85))
            Text("(\(count))")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}

/// A single invite shown as a full-width card that matches `GroupCard`
/// visual style (white `.cardStyle()` + soft shadow) with a lavender accent
/// rail on the leading edge to signal it's an incoming action item.
struct PendingInviteCard: View {
    let invite: PendingInvite
    let isProcessing: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var showingDeclineConfirm = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var useVerticalButtons: Bool {
        dynamicTypeSize >= .accessibility1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            identityRow
            actionRow
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .confirmationDialog(
            "Decline invite to \(invite.groupName)?",
            isPresented: $showingDeclineConfirm,
            titleVisibility: .visible
        ) {
            Button("Decline", role: .destructive) { onDecline() }
            Button("Cancel", role: .cancel) {}
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Invite to \(invite.groupName) from \(invite.inviterName), \(invite.createdAt.relativeFormatted)")
        .accessibilityAction(named: "Accept") { onAccept() }
        .accessibilityAction(named: "Decline") { showingDeclineConfirm = true }
    }

    // MARK: - Subviews

    private var identityRow: some View {
        HStack(spacing: 12) {
            MemberAvatar(name: invite.inviterName, imageUrl: nil, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(invite.groupName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text("Invited by \(invite.inviterName) · \(invite.createdAt.relativeFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        if isProcessing {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Joining…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .center)
        } else if useVerticalButtons {
            VStack(spacing: 6) {
                acceptButton
                declineButton
            }
        } else {
            HStack(spacing: 8) {
                declineButton
                acceptButton
            }
        }
    }

    private var acceptButton: some View {
        Button(action: onAccept) {
            Text("Accept")
                .font(.footnote)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .tint(Color.brandSecondary)
    }

    private var declineButton: some View {
        Button { showingDeclineConfirm = true } label: {
            Text("Decline")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(.secondary)
    }
}

#Preview("Idle") {
    VStack(spacing: 12) {
        PendingInvitesSectionHeader(count: PendingInvite.previews.count)
        ForEach(PendingInvite.previews) { invite in
            PendingInviteCard(
                invite: invite,
                isProcessing: false,
                onAccept: {},
                onDecline: {}
            )
        }
    }
    .padding(.horizontal, 16)
    .padding(.top, 40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.brandPrimary)
}

#Preview("Processing") {
    VStack(spacing: 12) {
        PendingInvitesSectionHeader(count: 1)
        PendingInviteCard(
            invite: PendingInvite.previews[0],
            isProcessing: true,
            onAccept: {},
            onDecline: {}
        )
    }
    .padding(.horizontal, 16)
    .padding(.top, 40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.brandPrimary)
}
