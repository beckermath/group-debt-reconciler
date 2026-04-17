import Foundation

enum InvitesEndpoint {
    static func create(groupId: String) -> Endpoint {
        Endpoint(path: "groups/\(groupId)/invites", method: .post)
    }
}
