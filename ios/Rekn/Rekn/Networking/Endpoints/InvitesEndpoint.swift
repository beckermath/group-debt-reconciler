import Foundation

enum InvitesEndpoint {
    /// Create a shareable invite link for a group.
    static func create(groupId: String) -> Endpoint {
        Endpoint(path: "groups/\(groupId)/invites", method: .post)
    }

    /// List pending direct invites for the current user.
    static func listPending() -> Endpoint {
        Endpoint(path: "user/pending-invites")
    }

    /// Send a direct invite to a user by their userId.
    static func sendDirect(groupId: String, invitedUserId: String) -> Endpoint {
        struct Body: Encodable { let invitedUserId: String }
        return Endpoint(
            path: "groups/\(groupId)/direct-invites",
            method: .post,
            body: Body(invitedUserId: invitedUserId)
        )
    }

    /// Accept a direct invite.
    static func accept(inviteId: String) -> Endpoint {
        Endpoint(path: "invites/direct/\(inviteId)/accept", method: .post)
    }

    /// Decline a direct invite.
    static func decline(inviteId: String) -> Endpoint {
        Endpoint(path: "invites/direct/\(inviteId)/decline", method: .post)
    }

    /// Search users by phone number or name (for the invite composer).
    static func searchUsers(query: String, groupId: String? = nil) -> Endpoint {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        var path = "users/search?q=\(encoded)"
        if let groupId {
            let g = groupId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            path += "&groupId=\(g)"
        }
        return Endpoint(path: path)
    }
}
