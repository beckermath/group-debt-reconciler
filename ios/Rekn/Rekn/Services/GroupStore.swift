import Foundation
import Observation

enum LoadState<T: Sendable>: Sendable {
    case idle
    case loading
    case loaded(T)
    case failed(String)
}

@Observable
final class GroupStore: @unchecked Sendable {
    var groupsState: LoadState<[GroupSummary]> = .idle
    var detailState: LoadState<GroupDetail> = .idle

    // MARK: - Groups List

    func loadGroups() async {
        groupsState = .loading
        do {
            let summaries: [APIGroupSummary] = try await APIClient.shared.request(
                Endpoint(path: "groups?include=summary")
            )
            let viewModels = summaries.map { $0.toViewModel() }
            groupsState = .loaded(viewModels)
        } catch let error as APIError {
            groupsState = .failed(error.errorDescription ?? "Failed to load groups")
        } catch {
            groupsState = .failed("Failed to load groups")
        }
    }

    // MARK: - Group Detail

    func loadGroupDetail(id: String) async {
        detailState = .loading
        do {
            let detail: APIGroupDetail = try await APIClient.shared.request(
                Endpoint(path: "groups/\(id)")
            )
            let viewModel = buildGroupDetail(from: detail)
            detailState = .loaded(viewModel)
        } catch let error as APIError {
            detailState = .failed(error.errorDescription ?? "Failed to load group")
        } catch {
            detailState = .failed("Failed to load group")
        }
    }

    // MARK: - Create Group

    func createGroup(name: String) async throws(APIError) -> String {
        struct Response: Decodable { let groupId: String }
        let result: Response = try await APIClient.shared.request(
            Endpoint(path: "groups", method: .post, body: ["name": name])
        )
        return result.groupId
    }

    // MARK: - Expenses

    func addExpense(groupId: String, description: String, amount: Double, paidBy: String, splitWith: [String], splitMode: String = "equal") async throws(APIError) {
        struct Body: Encodable {
            let description: String
            let amount: Double
            let paidBy: String
            let splitWith: [String]
            let splitMode: String
        }
        try await APIClient.shared.requestNoContent(
            Endpoint(path: "groups/\(groupId)/expenses", method: .post, body: Body(
                description: description, amount: amount, paidBy: paidBy,
                splitWith: splitWith, splitMode: splitMode
            ))
        )
    }

    func deleteExpense(groupId: String, expenseId: String) async throws(APIError) {
        try await APIClient.shared.requestNoContent(
            Endpoint(path: "groups/\(groupId)/expenses/\(expenseId)", method: .delete)
        )
    }

    // MARK: - Members

    func addMember(groupId: String, name: String) async throws(APIError) {
        struct Body: Encodable { let name: String }
        struct Response: Decodable { let memberId: String }
        let _: Response = try await APIClient.shared.request(
            Endpoint(path: "groups/\(groupId)/members", method: .post, body: Body(name: name))
        )
    }

    // MARK: - Settlements

    func settleUp(groupId: String) async throws(APIError) {
        struct Response: Decodable { let settlementId: String }
        let _: Response = try await APIClient.shared.request(
            Endpoint(path: "groups/\(groupId)/settlements", method: .post)
        )
    }

    // MARK: - Transform API → View Models

    private func buildGroupDetail(from api: APIGroupDetail) -> GroupDetail {
        let memberMap = Dictionary(uniqueKeysWithValues: api.members.map { ($0.id, $0.name) })
        let activeMembers = api.members.filter { !$0.isRemoved }
        let maxAbs = api.balances.values.map { abs($0) }.max() ?? 0

        let balanceEntries = activeMembers.map { member in
            BalanceEntry(
                memberId: member.id,
                name: member.name,
                balanceCents: api.balances[member.id] ?? 0,
                maxAbsBalance: maxAbs
            )
        }.sorted { abs($0.balanceCents) > abs($1.balanceCents) }

        let transfers = api.transfers.map { t in
            Transfer(
                fromName: memberMap[t.from] ?? "Unknown",
                toName: memberMap[t.to] ?? "Unknown",
                amount: t.amount
            )
        }

        // Find last settlement to filter current expenses
        let settlements = api.settlements.sorted { $0.settledAt > $1.settledAt }
        let lastSettlementDate = settlements.first.flatMap { parseAPIDate($0.settledAt) }

        let currentExpenses = api.expenses
            .filter { expense in
                guard let lastDate = lastSettlementDate,
                      let expDate = parseAPIDate(expense.createdAt) else { return true }
                return expDate > lastDate
            }
            .sorted { ($0.createdAt) > ($1.createdAt) }
            .map { expense in
                Expense(
                    id: expense.id,
                    description: expense.description,
                    amount: expense.amount,
                    paidByName: memberMap[expense.paidBy] ?? "Unknown",
                    paidByMemberId: expense.paidBy,
                    splitCount: expense.splits.count,
                    createdAt: parseAPIDate(expense.createdAt) ?? Date()
                )
            }

        let settlementViewModels = settlements.map { s in
            let periodExpenses = api.expenses.filter { e in
                // Simplified — count expenses before this settlement
                true
            }
            return Settlement(
                id: s.id,
                settledAt: parseAPIDate(s.settledAt) ?? Date(),
                settledByName: memberMap[s.settledBy] ?? "Unknown",
                expenseCount: periodExpenses.count,
                totalCents: periodExpenses.reduce(0) { $0 + $1.amount }
            )
        }

        return GroupDetail(
            id: api.id,
            name: api.name,
            members: activeMembers.map { m in
                GroupMember(id: m.id, name: m.name, userId: m.userId, isRemoved: m.isRemoved)
            },
            balances: balanceEntries,
            transfers: transfers,
            expenses: currentExpenses,
            settlements: settlementViewModels
        )
    }

    private func parseAPIDate(_ str: String) -> Date? {
        // Try Unix timestamp (SQLite stores as integer)
        if let ts = Double(str) {
            return Date(timeIntervalSince1970: ts)
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: str)
    }
}

// MARK: - Group Detail View Model

struct GroupDetail {
    let id: String
    let name: String
    let members: [GroupMember]
    let balances: [BalanceEntry]
    let transfers: [Transfer]
    let expenses: [Expense]
    let settlements: [Settlement]
}
