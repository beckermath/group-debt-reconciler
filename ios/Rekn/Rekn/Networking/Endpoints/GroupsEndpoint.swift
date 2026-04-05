import Foundation

enum GroupsEndpoint {
    static func list() -> Endpoint {
        Endpoint(path: "groups")
    }

    static func get(id: String) -> Endpoint {
        Endpoint(path: "groups/\(id)")
    }

    static func create(name: String) -> Endpoint {
        struct Body: Encodable { let name: String }
        return Endpoint(path: "groups", method: .post, body: Body(name: name))
    }

    static func rename(id: String, name: String) -> Endpoint {
        struct Body: Encodable { let name: String }
        return Endpoint(path: "groups/\(id)", method: .patch, body: Body(name: name))
    }

    static func delete(id: String) -> Endpoint {
        Endpoint(path: "groups/\(id)", method: .delete)
    }
}
