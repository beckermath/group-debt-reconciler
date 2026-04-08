import Foundation

// MARK: - Group Summary (from GET /groups?include=summary)

struct APIGroupSummary: Decodable, Identifiable {
    let id: String
    let name: String
    let createdAt: String
    let memberCount: Int
    let memberNames: [String]
    let memberImages: [String?]?
    let expenseCount: Int
    let lastActivityAt: String?
    let userBalanceCents: Int
    let status: String // "settled" | "has_balances" | "no_expenses"

    func toViewModel() -> GroupSummary {
        let statusEnum: GroupSummary.GroupStatus = switch status {
        case "settled": .settled
        case "has_balances": .hasBalances
        default: .noExpenses
        }

        return GroupSummary(
            id: id,
            name: name,
            memberCount: memberCount,
            memberNames: memberNames,
            memberImages: memberImages ?? [],
            expenseCount: expenseCount,
            lastActivityAt: parseDate(lastActivityAt),
            userBalanceCents: userBalanceCents,
            status: statusEnum
        )
    }
}

// MARK: - Group Detail (from GET /groups/:id)

struct APIGroupDetail: Decodable {
    let id: String
    let name: String
    let bannerUrl: String?
    let createdBy: String
    let createdAt: String
    let members: [APIMember]
    let expenses: [APIExpense]
    let settlements: [APISettlement]
    let balances: [String: Int] // memberId -> cents
    let transfers: [APITransfer]
    let activeMembers: Int
}

struct APIMember: Decodable, Identifiable {
    let id: String
    let name: String
    let userId: String?
    let removedAt: String?
    let imageUrl: String?

    var isRemoved: Bool { removedAt != nil }
}

struct APIExpense: Decodable, Identifiable {
    let id: String
    let description: String
    let amount: Int
    let paidBy: String
    let createdAt: String
    let splits: [APIExpenseSplit]
}

struct APIExpenseSplit: Decodable {
    let id: String
    let memberId: String
    let share: Int
}

struct APISettlement: Decodable, Identifiable {
    let id: String
    let settledAt: String
    let settledBy: String
    let note: String?
}

struct APITransfer: Decodable {
    let from: String
    let to: String
    let amount: Int
}

// MARK: - Date Parsing Helper

private func parseDate(_ dateString: String?) -> Date? {
    guard let dateString else { return nil }
    // Try ISO 8601 first, then Unix timestamp
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: dateString) { return date }
    // Try without fractional seconds
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: dateString) { return date }
    // Try as Unix timestamp (seconds)
    if let timestamp = Double(dateString) {
        return Date(timeIntervalSince1970: timestamp)
    }
    return nil
}
