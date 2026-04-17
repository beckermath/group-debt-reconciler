import SwiftUI

struct GroupsListScreen: View {
    @Binding var path: NavigationPath
    @Environment(GroupStore.self) private var groupStore
    @Environment(AuthManager.self) private var authManager
    @Environment(InviteStore.self) private var inviteStore
    @State private var showingCreateGroup = false
    @State private var showingSettings = false
    @State private var scrollOffset: CGFloat = 0
    @State private var inviteError: String?

    private var groups: [GroupSummary] {
        if case .loaded(let g) = groupStore.groupsState { return g }
        return []
    }

    private var pendingInvites: [PendingInvite] {
        if case .loaded(let invites) = inviteStore.pendingState { return invites }
        return []
    }

    private var showInvitesForCurrentUser: Bool {
        !(authManager.currentUser?.isGuest ?? true)
    }

    private var totalOwed: Int {
        groups.reduce(0) { $0 + max($1.userBalanceCents, 0) }
    }

    private var totalOwes: Int {
        groups.reduce(0) { $0 + max(-$1.userBalanceCents, 0) }
    }

    private var netBalance: Int { totalOwed - totalOwes }

    var body: some View {
        Group {
            switch groupStore.groupsState {
            case .idle, .loading:
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let message):
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Couldn't load groups")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await groupStore.loadGroups() }
                    } label: {
                        Text("Try Again")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded(let groups) where groups.isEmpty:
                emptyState

            case .loaded:
                groupsList
                    .transition(.opacity.animation(.easeIn(duration: 0.3)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: groupStore.groupsState.isLoaded)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showingSettings = true } label: {
                    MemberAvatar(
                        name: authManager.currentUser?.name ?? "?",
                        imageUrl: authManager.currentUser?.imageUrl,
                        size: 30
                    )
                    .overlay(
                        Circle().stroke(.white.opacity(0.35), lineWidth: 1)
                    )
                }
                .accessibilityLabel("Settings")
            }
            ToolbarItem(placement: .principal) {
                Text("Your Groups")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showingCreateGroup = true } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.white)
                }
            }
        }
        .navigationDestination(for: String.self) { groupId in
            GroupDetailScreen(groupId: groupId)
        }
        .sheet(isPresented: $showingCreateGroup) {
            CreateGroupSheet { groupId in
                // Navigate to the new group
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    path.append(groupId)
                }
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsScreen()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            async let groupsTask: () = groupStore.loadGroups()
            async let invitesTask: () = showInvitesForCurrentUser
                ? inviteStore.loadPending()
                : ()
            _ = await (groupsTask, invitesTask)
        }
        .refreshable {
            async let groupsTask: () = groupStore.loadGroups(forceReload: true)
            async let invitesTask: () = showInvitesForCurrentUser
                ? inviteStore.loadPending(forceReload: true)
                : ()
            _ = await (groupsTask, invitesTask)
        }
        .alert("Couldn't update invite", isPresented: .constant(inviteError != nil)) {
            Button("OK") { inviteError = nil }
        } message: {
            Text(inviteError ?? "")
        }
    }

    // MARK: - Invite Actions

    private func handleAccept(_ invite: PendingInvite) {
        // Guard against double-tap while in flight.
        guard !inviteStore.isProcessing(inviteId: invite.id) else { return }
        Task {
            do {
                _ = try await inviteStore.accept(inviteId: invite.id)
                // InviteStore.accept already reloaded pending invites from
                // the server — refresh groups so the newly joined group shows.
                await groupStore.loadGroups(forceReload: true)
            } catch let error as APIError {
                inviteError = error.errorDescription ?? "Couldn't accept invite"
            } catch {
                inviteError = "Couldn't accept invite"
            }
        }
    }

    private func handleDecline(_ invite: PendingInvite) {
        guard !inviteStore.isProcessing(inviteId: invite.id) else { return }
        Task {
            do {
                try await inviteStore.decline(inviteId: invite.id)
            } catch let error as APIError {
                inviteError = error.errorDescription ?? "Couldn't decline invite"
            } catch {
                inviteError = "Couldn't decline invite"
            }
        }
    }

    // MARK: - Groups List

    private var groupsList: some View {
        ZStack(alignment: .top) {
            // 1. Background teal — static backdrop, behind everything
            VStack(spacing: 0) {
                Color.brandPrimary
                    .frame(height: 240)
                LinearGradient(
                    colors: [Color.brandPrimary, .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 160)
            }
            .ignoresSafeArea()

            // 2. ScrollView — cards scroll over the backdrop
            ScrollView {
                VStack(spacing: 12) {
                    if showInvitesForCurrentUser, !pendingInvites.isEmpty {
                        VStack(spacing: 10) {
                            PendingInvitesSectionHeader(count: pendingInvites.count)
                                .padding(.horizontal, -16) // header uses its own 16pt inset
                            ForEach(pendingInvites) { invite in
                                PendingInviteCard(
                                    invite: invite,
                                    isProcessing: inviteStore.isProcessing(inviteId: invite.id),
                                    onAccept: { handleAccept(invite) },
                                    onDecline: { handleDecline(invite) }
                                )
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .scale(scale: 0.98))
                                ))
                            }
                        }
                    }
                    ForEach(groups) { group in
                        NavigationLink(value: group.id) {
                            GroupCard(group: group)
                        }
                        .buttonStyle(CardPressStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .animation(.snappy(duration: 0.25), value: pendingInvites.map(\.id))
            }
            .contentMargins(.top, 80, for: .scrollContent)
            .scrollIndicators(.hidden)
            .tint(.white)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top
            } action: { _, offset in
                scrollOffset = max(0, offset)
            }

            // 3. Foreground teal — slightly transparent so content is faintly visible
            VStack(spacing: 0) {
                Color.brandPrimary.opacity(0.92)
                    .frame(height: 180)
                // Fade grows as user scrolls
                let fadeAmount = min(40, scrollOffset * 0.8)
                if fadeAmount > 0 {
                    LinearGradient(
                        colors: [Color.brandPrimary.opacity(0.92), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: fadeAmount)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // 4. Balance pinned on the foreground teal
            if totalOwed > 0 || totalOwes > 0 {
                balanceHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Compact Header

    private var balanceHeader: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack {
                // Balance at 1/3
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatCents(netBalance, showSign: true))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(netBalance > 0 ? "owed to you" : netBalance < 0 ? "you owe" : "all settled")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .position(x: width * 0.25, y: 24)

                // Pills stacked at 2/3
                VStack(alignment: .trailing, spacing: 6) {
                    if totalOwed > 0 {
                        balancePill(amount: totalOwed, label: "owed", color: Color.balancePositive)
                    }
                    if totalOwes > 0 {
                        balancePill(amount: totalOwes, label: "owing", color: Color.balanceNegative)
                    }
                }
                .position(x: width * 0.75, y: 24)
            }
        }
        .frame(height: 50)
        .padding(.bottom, 8)
    }

    private func balancePill(amount: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(formatCents(amount)) \(label)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.white.opacity(0.12), in: .rect(cornerRadius: 10))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.3))
            Text("No groups yet")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Create a group to start splitting expenses")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showingCreateGroup = true
            } label: {
                Text("Create Group")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: 260)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Group Card

private struct GroupCard: View {
    let group: GroupSummary

    var body: some View {
        HStack(spacing: 12) {
            // Avatar cluster
            HStack(spacing: -12) {
                ForEach(Array(group.memberNames.prefix(2).enumerated()), id: \.offset) { index, name in
                    let imgUrl = index < group.memberImages.count ? group.memberImages[index] : nil
                    MemberAvatar(name: name, imageUrl: imgUrl, size: 32)
                }
                if group.memberCount > 2 {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                        Text("+\(group.memberCount - 2)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 32, height: 32)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                HStack(spacing: 0) {
                    Text("\(group.memberCount) members")
                    if let date = group.lastActivityAt {
                        Text(" · ")
                            .foregroundStyle(.quaternary)
                        Text(date.relativeFormatted)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Balance
            if group.userBalanceCents != 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCents(group.userBalanceCents, showSign: true))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(group.userBalanceCents > 0 ? Color.balancePositive : Color.balanceNegative)
                    Text(group.userBalanceCents > 0 ? "owed" : "owe")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            } else if group.status == .settled {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.balancePositive)
                    Text("Settled")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.balancePositive)
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Card Press Style

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    @Previewable @State var path = NavigationPath()
    NavigationStack(path: $path) {
        GroupsListScreen(path: $path)
            .environment(GroupStore())
            .environment(AuthManager())
            .environment(InviteStore())
    }
}
