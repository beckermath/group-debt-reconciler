import Foundation

#if DEBUG

enum DevEndpoint {
    static func testUsers() -> Endpoint {
        Endpoint(path: "dev/test-users")
    }
}

struct APITestUser: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let phoneNumber: String
}

#endif
