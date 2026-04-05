import Foundation

enum SettlementsEndpoint {
    static func list(groupId: String) -> Endpoint {
        Endpoint(path: "groups/\(groupId)/settlements")
    }

    static func create(groupId: String) -> Endpoint {
        Endpoint(path: "groups/\(groupId)/settlements", method: .post)
    }

    static func undo(groupId: String, settlementId: String) -> Endpoint {
        Endpoint(path: "groups/\(groupId)/settlements/\(settlementId)", method: .delete)
    }
}
