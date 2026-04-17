import Foundation
import Observation

enum LoadState<T: Sendable>: Sendable {
    case idle
    case loading
    case loaded(T)
    case failed(String)

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }
}

@Observable
final class GroupStore: @unchecked Sendable {
    var groupsState: LoadState<[GroupSummary]> = .idle
    var detailState: LoadState<GroupDetail> = .idle

    // MARK: - Groups List

    /// Load groups. If cached data exists, show it immediately and refresh in the background.
    /// Use `forceReload: true` after mutations to show the loading state.
    func loadGroups(forceReload: Bool = false) async {
        if case .loaded = groupsState {
            // Already have data — always refresh in background without spinner
            // (covers both forceReload and normal re-enter)
            await fetchGroups()
            return
        }
        groupsState = .loading
        await fetchGroups()
    }

    private func fetchGroups() async {
        do {
            let summaries: [APIGroupSummary] = try await APIClient.shared.request(
                Endpoint(path: "groups?include=summary")
            )
            let viewModels = summaries.map { $0.toViewModel() }
            groupsState = .loaded(viewModels)
        } catch let error as APIError {
            // Only show error if we don't have cached data
            if case .loaded = groupsState { return }
            groupsState = .failed(error.errorDescription ?? "Failed to load groups")
        } catch {
            if case .loaded = groupsState { return }
            groupsState = .failed("Failed to load groups")
        }
    }

    // MARK: - Group Detail

    /// Load group detail. If the same group is already loaded, show cached and refresh in background.
    /// Use `forceReload: true` after mutations.
    func loadGroupDetail(id: String, forceReload: Bool = false) async {
        if case .loaded(let detail) = detailState, detail.id == id {
            // Same group already loaded — background refresh without spinner
            await fetchGroupDetail(id: id)
            return
        }
        // Different group or no data — show loading
        detailState = .loading
        await fetchGroupDetail(id: id)
    }

    private func fetchGroupDetail(id: String) async {
        do {
            let detail: APIGroupDetail = try await APIClient.shared.request(
                Endpoint(path: "groups/\(id)")
            )
            let viewModel = buildGroupDetail(from: detail)
            detailState = .loaded(viewModel)
        } catch let error as APIError {
            if case .loaded = detailState { return }
            detailState = .failed(error.errorDescription ?? "Failed to load group")
        } catch {
            if case .loaded = detailState { return }
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

    func addExpense(groupId: String, description: String, amount: Double, paidBy: String, splitWith: [String], splitMode: String = "equal", customAmounts: [String: String] = [:]) async throws(APIError) {
        struct Body: Encodable {
            let description: String
            let amount: Double
            let paidBy: String
            let splitWith: [String]
            let splitMode: String
            let customAmounts: [String: String]
        }
        try await APIClient.shared.requestNoContent(
            Endpoint(path: "groups/\(groupId)/expenses", method: .post, body: Body(
                description: description, amount: amount, paidBy: paidBy,
                splitWith: splitWith, splitMode: splitMode, customAmounts: customAmounts
            ))
        )
    }

    func updateExpense(groupId: String, expenseId: String, description: String, amount: Double, paidBy: String, splitWith: [String], splitMode: String = "equal", customAmounts: [String: String] = [:]) async throws(APIError) {
        struct Body: Encodable {
            let description: String
            let amount: Double
            let paidBy: String
            let splitWith: [String]
            let splitMode: String
            let customAmounts: [String: String]
        }
        struct Response: Decodable { let expenseId: String }
        let _: Response = try await APIClient.shared.request(
            Endpoint(
                path: "groups/\(groupId)/expenses/\(expenseId)",
                method: .patch,
                body: Body(description: description, amount: amount, paidBy: paidBy, splitWith: splitWith, splitMode: splitMode, customAmounts: customAmounts)
            )
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

    // MARK: - Group Editing

    func renameGroup(id: String, name: String) async throws(APIError) {
        struct Body: Encodable { let name: String }
        struct Response: Decodable { let id: String; let name: String }
        let _: Response = try await APIClient.shared.request(
            Endpoint(path: "groups/\(id)", method: .patch, body: Body(name: name))
        )
    }

    func uploadBanner(groupId: String, imageData: Data) async throws(APIError) -> String {
        struct Response: Decodable { let bannerUrl: String }
        let result: Response = try await APIClient.shared.uploadMultipart(
            path: "groups/\(groupId)/banner",
            fileData: imageData,
            fileName: "banner.jpg",
            mimeType: "image/jpeg"
        )
        return result.bannerUrl
    }

    func removeBanner(groupId: String) async throws(APIError) {
        try await APIClient.shared.requestNoContent(
            Endpoint(path: "groups/\(groupId)/banner", method: .delete)
        )
    }

    // MARK: - Profile

    func uploadAvatar(imageData: Data) async throws(APIError) -> String {
        struct Response: Decodable { let imageUrl: String }
        let result: Response = try await APIClient.shared.uploadMultipart(
            path: "user/avatar",
            fileData: imageData,
            fileName: "avatar.jpg",
            mimeType: "image/jpeg"
        )
        return result.imageUrl
    }

    func removeAvatar() async throws(APIError) {
        try await APIClient.shared.requestNoContent(
            Endpoint(path: "user/avatar", method: .delete)
        )
    }

    // MARK: - Settlements

    func settleUp(groupId: String) async throws(APIError) {
        struct Response: Decodable { let settlementId: String }
        let _: Response = try await APIClient.shared.request(
            Endpoint(path: "groups/\(groupId)/settlements", method: .post)
        )
    }

    func deleteGroup(id: String) async throws(APIError) {
        try await APIClient.shared.requestNoContent(
            GroupsEndpoint.delete(id: id)
        )
    }

    func removeMember(groupId: String, memberId: String) async throws(APIError) {
        struct Body: Encodable { let action: String }
        struct Response: Decodable { let memberId: String; let status: String }
        let _: Response = try await APIClient.shared.request(
            Endpoint(path: "groups/\(groupId)/members/\(memberId)", method: .patch, body: Body(action: "remove"))
        )
    }

    func createInviteLink(groupId: String) async throws(APIError) -> String {
        struct Response: Decodable { let code: String }
        let result: Response = try await APIClient.shared.request(
            InvitesEndpoint.create(groupId: groupId)
        )
        return result.code
    }

    func restoreMember(groupId: String, memberId: String) async throws(APIError) {
        struct Body: Encodable { let action: String }
        struct Response: Decodable { let memberId: String; let status: String }
        let _: Response = try await APIClient.shared.request(
            Endpoint(path: "groups/\(groupId)/members/\(memberId)", method: .patch, body: Body(action: "restore"))
        )
    }

    func undoSettlement(groupId: String, settlementId: String) async throws(APIError) {
        try await APIClient.shared.requestNoContent(
            SettlementsEndpoint.undo(groupId: groupId, settlementId: settlementId)
        )
    }

    // MARK: - Transform API → View Models

    private func buildGroupDetail(from api: APIGroupDetail) -> GroupDetail {
        let memberMap = Dictionary(uniqueKeysWithValues: api.members.map { ($0.id, $0.name) })
        let removedMemberIds = Set(api.members.filter { $0.isRemoved }.map(\.id))
        // Display name with "(removed)" suffix for labels, clean name for avatars
        func displayName(for memberId: String) -> String {
            let name = memberMap[memberId] ?? "Unknown"
            return removedMemberIds.contains(memberId) ? "\(name) (removed)" : name
        }
        let memberImageMap = Dictionary(uniqueKeysWithValues: api.members.map { ($0.id, $0.imageUrl) })
        let activeMembers = api.members.filter { !$0.isRemoved }
        let removedMembers = api.members.filter { $0.isRemoved }
        let maxAbs = api.balances.values.map { abs($0) }.max() ?? 0

        let balanceEntries = activeMembers.map { member in
            BalanceEntry(
                memberId: member.id,
                name: member.name,
                imageUrl: member.imageUrl,
                balanceCents: api.balances[member.id] ?? 0,
                maxAbsBalance: maxAbs
            )
        }.sorted { abs($0.balanceCents) > abs($1.balanceCents) }

        let transfers = api.transfers.map { t in
            Transfer(
                fromName: memberMap[t.from] ?? "Unknown",
                fromImageUrl: memberImageMap[t.from] ?? nil,
                toName: memberMap[t.to] ?? "Unknown",
                toImageUrl: memberImageMap[t.to] ?? nil,
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
                    paidByImageUrl: memberImageMap[expense.paidBy] ?? nil,
                    splitCount: expense.splits.count,
                    createdAt: parseAPIDate(expense.createdAt) ?? Date()
                )
            }

        // Build all expenses (including settled) for settlement detail views
        let allExpensesSorted = api.expenses
            .sorted { $0.createdAt > $1.createdAt }
            .map { expense in
                Expense(
                    id: expense.id,
                    description: expense.description,
                    amount: expense.amount,
                    paidByName: memberMap[expense.paidBy] ?? "Unknown",
                    paidByMemberId: expense.paidBy,
                    paidByImageUrl: memberImageMap[expense.paidBy] ?? nil,
                    splitCount: expense.splits.count,
                    createdAt: parseAPIDate(expense.createdAt) ?? Date()
                )
            }

        // Compute settlement expense counts using timestamp windows
        let settlementViewModels: [Settlement] = settlements.enumerated().map { index, s in
            let settledAt = parseAPIDate(s.settledAt) ?? Date()
            let prevDate = index + 1 < settlements.count
                ? parseAPIDate(settlements[index + 1].settledAt)
                : nil
            let periodExpenses = api.expenses.filter { e in
                guard let expDate = parseAPIDate(e.createdAt) else { return false }
                let beforeCurrent = expDate <= settledAt
                let afterPrev = prevDate.map { expDate > $0 } ?? true
                return afterPrev && beforeCurrent
            }
            return Settlement(
                id: s.id,
                settledAt: settledAt,
                settledByName: memberMap[s.settledBy] ?? "Unknown",
                expenseCount: periodExpenses.count,
                totalCents: periodExpenses.reduce(0) { $0 + $1.amount }
            )
        }

        return GroupDetail(
            id: api.id,
            name: api.name,
            bannerUrl: api.bannerUrl,
            members: activeMembers.map { m in
                GroupMember(id: m.id, name: m.name, userId: m.userId, isRemoved: m.isRemoved, imageUrl: m.imageUrl)
            },
            removedMembers: removedMembers.map { m in
                GroupMember(id: m.id, name: m.name, userId: m.userId, isRemoved: m.isRemoved, imageUrl: m.imageUrl)
            },
            balances: balanceEntries,
            transfers: transfers,
            expenses: currentExpenses,
            settlements: settlementViewModels,
            allExpenses: allExpensesSorted
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
    let bannerUrl: String?
    let members: [GroupMember]
    let removedMembers: [GroupMember]
    let balances: [BalanceEntry]
    let transfers: [Transfer]
    let expenses: [Expense]
    let settlements: [Settlement]
    let allExpenses: [Expense] // includes settled expenses, for settlement detail views

    func expenses(for settlement: Settlement) -> [Expense] {
        let sortedSettlements = settlements.sorted { $0.settledAt > $1.settledAt }
        let index = sortedSettlements.firstIndex(where: { $0.id == settlement.id })
        let prevDate = index.flatMap { i in
            i + 1 < sortedSettlements.count ? sortedSettlements[i + 1].settledAt : nil
        }
        return allExpenses.filter { expense in
            let beforeCurrent = expense.createdAt <= settlement.settledAt
            let afterPrev = prevDate.map { expense.createdAt > $0 } ?? true
            return afterPrev && beforeCurrent
        }
    }
}
