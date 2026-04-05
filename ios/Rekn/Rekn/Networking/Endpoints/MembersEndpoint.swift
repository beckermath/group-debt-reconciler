import Foundation

enum MembersEndpoint {
    static func list(groupId: String) -> Endpoint {
        Endpoint(path: "groups/\(groupId)/members")
    }

    static func add(groupId: String, name: String) -> Endpoint {
        struct Body: Encodable { let name: String }
        return Endpoint(path: "groups/\(groupId)/members", method: .post, body: Body(name: name))
    }

    static func remove(groupId: String, memberId: String) -> Endpoint {
        Endpoint(path: "groups/\(groupId)/members/\(memberId)", method: .delete)
    }
}
