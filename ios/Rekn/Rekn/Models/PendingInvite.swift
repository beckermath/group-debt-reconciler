import Foundation

struct PendingInvite: Identifiable, Hashable, Sendable {
    let id: String
    let groupId: String
    let groupName: String
    let inviterName: String
    let createdAt: Date
}

struct UserSearchResult: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let maskedPhone: String
}

extension PendingInvite {
    static let previews: [PendingInvite] = [
        PendingInvite(
            id: "i1",
            groupId: "g1",
            groupName: "Weekend Trip",
            inviterName: "Alice",
            createdAt: Date()
        ),
        PendingInvite(
            id: "i2",
            groupId: "g2",
            groupName: "Apartment",
            inviterName: "Bob",
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        ),
    ]
}
