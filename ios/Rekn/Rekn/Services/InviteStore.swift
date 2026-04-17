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

    /// Optimistically remove the invite, then call accept. Reverts on failure.
    func accept(inviteId: String) async throws(APIError) -> String {
        let previous = currentInvites
        removeInviteLocally(id: inviteId)
        do {
            struct Response: Decodable { let groupId: String }
            let result: Response = try await APIClient.shared.request(
                InvitesEndpoint.accept(inviteId: inviteId)
            )
            return result.groupId
        } catch let error as APIError {
            pendingState = .loaded(previous)
            throw error
        }
    }

    /// Optimistically remove the invite, then call decline. Reverts on failure.
    func decline(inviteId: String) async throws(APIError) {
        let previous = currentInvites
        removeInviteLocally(id: inviteId)
        do {
            try await APIClient.shared.requestNoContent(
                InvitesEndpoint.decline(inviteId: inviteId)
            )
        } catch let error as APIError {
            pendingState = .loaded(previous)
            throw error
        }
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
    }

    // MARK: - Helpers

    private var currentInvites: [PendingInvite] {
        if case .loaded(let invites) = pendingState { return invites }
        return []
    }

    private func removeInviteLocally(id: String) {
        guard case .loaded(let invites) = pendingState else { return }
        pendingState = .loaded(invites.filter { $0.id != id })
    }
}
