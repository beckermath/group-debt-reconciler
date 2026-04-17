import Foundation
import Observation

@Observable
final class InviteStore: @unchecked Sendable {
    var pendingState: LoadState<[PendingInvite]> = .idle

    // MARK: - Pending Invites

    /// Load pending invites. If cached data exists, show it immediately and refresh in the background.
    func loadPending(forceReload: Bool = false) async {
        if case .loaded = pendingState, !forceReload {
            await fetchPending()
            return
        }
        if !forceReload {
            pendingState = .loading
        }
        await fetchPending()
    }

    private func fetchPending() async {
        do {
            let invites: [APIPendingInvite] = try await APIClient.shared.request(
                InvitesEndpoint.listPending()
            )
            pendingState = .loaded(invites.map { $0.toViewModel() })
        } catch let error as APIError {
            if case .loaded = pendingState { return }
            pendingState = .failed(error.errorDescription ?? "Failed to load invites")
        } catch {
            if case .loaded = pendingState { return }
            pendingState = .failed("Failed to load invites")
        }
    }

    // MARK: - Mutations

    /// Track in-flight accept/decline calls so the UI can disable buttons for
    /// specific invites without relying on local row state that may be destroyed
    /// when the list reloads.
    var processingInviteIds: Set<String> = []

    /// Accept an invite, then reload pending invites from the server so the
    /// card reliably disappears. Server reload is the source of truth — optimistic
    /// mutation alone was flaky when the scroll/card view recycled.
    func accept(inviteId: String) async throws(APIError) -> String {
        processingInviteIds.insert(inviteId)
        defer { processingInviteIds.remove(inviteId) }

        struct Response: Decodable { let groupId: String }
        let result: Response = try await APIClient.shared.request(
            InvitesEndpoint.accept(inviteId: inviteId)
        )
        await fetchPending()
        return result.groupId
    }

    /// Decline an invite, then reload pending invites from the server.
    func decline(inviteId: String) async throws(APIError) {
        processingInviteIds.insert(inviteId)
        defer { processingInviteIds.remove(inviteId) }

        try await APIClient.shared.requestNoContent(
            InvitesEndpoint.decline(inviteId: inviteId)
        )
        await fetchPending()
    }

    // MARK: - Send

    func sendDirectInvite(groupId: String, invitedUserId: String) async throws(APIError) {
        try await APIClient.shared.requestNoContent(
            InvitesEndpoint.sendDirect(groupId: groupId, invitedUserId: invitedUserId)
        )
    }

    // MARK: - User Search

    func searchUsers(query: String, groupId: String? = nil) async throws(APIError) -> [UserSearchResult] {
        guard query.count >= 3 else { return [] }
        let results: [APIUserSearchResult] = try await APIClient.shared.request(
            InvitesEndpoint.searchUsers(query: query, groupId: groupId)
        )
        return results.map { $0.toViewModel() }
    }

    // MARK: - Lifecycle

    func reset() {
        pendingState = .idle
        processingInviteIds = []
    }

    func isProcessing(inviteId: String) -> Bool {
        processingInviteIds.contains(inviteId)
    }
}
