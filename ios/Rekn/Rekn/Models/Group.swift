import Foundation

struct GroupSummary: Identifiable {
    let id: String
    let name: String
    let memberCount: Int
    let memberNames: [String]
    let memberImages: [String?]
    let expenseCount: Int
    let lastActivityAt: Date?
    let userBalanceCents: Int
    let status: GroupStatus

    enum GroupStatus {
        case settled, hasBalances, noExpenses
    }
}

struct GroupMember: Identifiable, Hashable {
    let id: String
    let name: String
    let userId: String?
    let isRemoved: Bool
    let imageUrl: String?
}

struct Expense: Identifiable, Hashable {
    let id: String
    let description: String
    let amount: Int // cents
    let paidByName: String
    let paidByMemberId: String
    let paidByImageUrl: String?
    let splitCount: Int
    let createdAt: Date
}

struct Transfer: Identifiable {
    var id: String { "\(fromName)-\(toName)" }
    let fromName: String
    let fromImageUrl: String?
    let toName: String
    let toImageUrl: String?
    let amount: Int // cents
}

struct Settlement: Identifiable, Hashable {
    let id: String
    let settledAt: Date
    let settledByName: String
    let expenseCount: Int
    let totalCents: Int
}

struct BalanceEntry: Identifiable {
    var id: String { memberId }
    let memberId: String
    let name: String
    let imageUrl: String?
    let balanceCents: Int
    let maxAbsBalance: Int
}

// MARK: - Preview Data

extension GroupSummary {
    static let previews: [GroupSummary] = [
        GroupSummary(
            id: "1", name: "Ski Trip", memberCount: 3,
            memberNames: ["Alice", "Bob", "Carol"], memberImages: [nil, nil, nil],
            expenseCount: 4, lastActivityAt: Date(),
            userBalanceCents: 2450, status: .hasBalances
        ),
        GroupSummary(
            id: "2", name: "Apartment", memberCount: 2,
            memberNames: ["Alice", "Dave"], memberImages: [nil, nil],
            expenseCount: 12, lastActivityAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
            userBalanceCents: -1200, status: .hasBalances
        ),
        GroupSummary(
            id: "3", name: "Dinner Club", memberCount: 4,
            memberNames: ["Alice", "Bob", "Carol", "Eve"], memberImages: [nil, nil, nil, nil],
            expenseCount: 8, lastActivityAt: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            userBalanceCents: 0, status: .settled
        ),
    ]
}

extension Expense {
    static let previews: [Expense] = [
        Expense(id: "e1", description: "Dinner at Luigi's", amount: 3675, paidByName: "Alice", paidByMemberId: "m1", paidByImageUrl: nil, splitCount: 3, createdAt: Date()),
        Expense(id: "e2", description: "Uber to airport", amount: 2200, paidByName: "Bob", paidByMemberId: "m2", paidByImageUrl: nil, splitCount: 2, createdAt: Calendar.current.date(byAdding: .hour, value: -5, to: Date())!),
        Expense(id: "e3", description: "Groceries", amount: 8450, paidByName: "Alice", paidByMemberId: "m1", paidByImageUrl: nil, splitCount: 3, createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
    ]
}

extension Transfer {
    static let previews: [Transfer] = [
        Transfer(fromName: "Bob", fromImageUrl: nil, toName: "Alice", toImageUrl: nil, amount: 1225),
        Transfer(fromName: "Carol", fromImageUrl: nil, toName: "Alice", toImageUrl: nil, amount: 1225),
    ]
}

extension BalanceEntry {
    static let previews: [BalanceEntry] = [
        BalanceEntry(memberId: "m1", name: "Alice", imageUrl: nil, balanceCents: 2450, maxAbsBalance: 2450),
        BalanceEntry(memberId: "m2", name: "Bob", imageUrl: nil, balanceCents: -1225, maxAbsBalance: 2450),
        BalanceEntry(memberId: "m3", name: "Carol", imageUrl: nil, balanceCents: -1225, maxAbsBalance: 2450),
        BalanceEntry(memberId: "m4", name: "Dave", imageUrl: nil, balanceCents: 0, maxAbsBalance: 2450),
        BalanceEntry(memberId: "m5", name: "Eve", imageUrl: nil, balanceCents: 0, maxAbsBalance: 2450),
        BalanceEntry(memberId: "m6", name: "Frank", imageUrl: nil, balanceCents: 0, maxAbsBalance: 2450),
    ]
}

extension Settlement {
    static let previews: [Settlement] = [
        Settlement(id: "s1",
                   settledAt: Calendar.current.date(byAdding: .day, value: -25, to: Date())!,
                   settledByName: "Alice", expenseCount: 3, totalCents: 5875),
        Settlement(id: "s2",
                   settledAt: Calendar.current.date(byAdding: .day, value: -39, to: Date())!,
                   settledByName: "Bob", expenseCount: 7, totalCents: 12430),
        Settlement(id: "s3",
                   settledAt: Calendar.current.date(byAdding: .day, value: -57, to: Date())!,
                   settledByName: "Carol", expenseCount: 2, totalCents: 2200),
    ]
}
