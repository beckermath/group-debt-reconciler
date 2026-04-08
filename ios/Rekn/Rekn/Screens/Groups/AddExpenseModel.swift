import Foundation
import Observation

enum AddExpenseStep: Hashable {
    case payerSelection
    case splitMode
}

@Observable
final class AddExpenseModel {
    let groupId: String
    let memberList: [GroupMember]
    let currentUserId: String?

    var description = ""
    var amount = ""
    var paidByMemberId = ""
    var selectedMemberIds: Set<String> = []
    var splitMode: SplitMode = .equal
    var customAmounts: [String: String] = [:]
    var percentages: [String: String] = [:]
    var isSubmitting = false
    var error: String?

    init(groupId: String, memberList: [GroupMember], currentUserId: String?) {
        self.groupId = groupId
        self.memberList = memberList
        self.currentUserId = currentUserId
        self.selectedMemberIds = Set(memberList.map(\.id))
        let current = memberList.first { $0.userId == currentUserId }
        self.paidByMemberId = current?.id ?? memberList.first?.id ?? ""
    }

    // MARK: - Computed

    var amountCents: Int {
        Int(round((Double(amount) ?? 0) * 100))
    }

    var customTotalCents: Int {
        selectedMemberIds.reduce(0) { sum, id in
            sum + Int(round((Double(customAmounts[id] ?? "0") ?? 0) * 100))
        }
    }

    var remainingCents: Int {
        amountCents - customTotalCents
    }

    var percentageTotal: Double {
        selectedMemberIds.reduce(0.0) { sum, id in
            sum + (Double(percentages[id] ?? "0") ?? 0)
        }
    }

    var remainingPercent: Double {
        100.0 - percentageTotal
    }

    var currentMember: GroupMember? {
        memberList.first { $0.userId == currentUserId }
    }

    var selectedMemberArray: [GroupMember] {
        memberList.filter { selectedMemberIds.contains($0.id) }
    }

    var paidByName: String {
        guard let member = memberList.first(where: { $0.id == paidByMemberId }) else { return "Unknown" }
        return displayName(for: member)
    }

    var splitModeLabel: String {
        splitMode.label.lowercased()
    }

    var detailsValid: Bool {
        !description.trimmingCharacters(in: .whitespaces).isEmpty
        && amountCents > 0
        && !selectedMemberIds.isEmpty
    }

    var isValid: Bool {
        guard detailsValid, !paidByMemberId.isEmpty else { return false }
        switch splitMode {
        case .equal: return true
        case .custom: return remainingCents == 0
        case .percent: return abs(remainingPercent) < 0.01
        }
    }

    // MARK: - Helpers

    func displayName(for member: GroupMember) -> String {
        if let userId = currentUserId, member.userId == userId {
            return "Me"
        }
        return member.name.components(separatedBy: " ").first ?? member.name
    }

    func toggleMember(_ id: String) {
        if selectedMemberIds.contains(id) {
            selectedMemberIds.remove(id)
        } else {
            selectedMemberIds.insert(id)
        }
        resetSplitIfCustom()
    }

    func setSelectedMembers(_ ids: Set<String>) {
        selectedMemberIds = ids
        resetSplitIfCustom()
    }

    private func resetSplitIfCustom() {
        if splitMode != .equal {
            splitMode = .equal
            customAmounts = [:]
            percentages = [:]
        }
    }

    func distributeRemaining() {
        let selected = Array(selectedMemberIds)
        let unassigned = selected.filter {
            Int(round((Double(customAmounts[$0] ?? "0") ?? 0) * 100)) == 0
        }
        let targets = unassigned.isEmpty ? selected : unassigned
        guard !targets.isEmpty, remainingCents > 0 else { return }

        let perMember = remainingCents / targets.count
        let pennies = remainingCents - perMember * targets.count

        var updated = customAmounts
        for (i, id) in targets.enumerated() {
            let existing = Int(round((Double(updated[id] ?? "0") ?? 0) * 100))
            let add = perMember + (i < pennies ? 1 : 0)
            updated[id] = String(format: "%.2f", Double(existing + add) / 100.0)
        }
        customAmounts = updated
    }

    func distributeEqualPercentages() {
        let selected = Array(selectedMemberIds).sorted()
        guard !selected.isEmpty else { return }

        let each = 100.0 / Double(selected.count)
        let formatted = String(format: "%.2f", each)

        var updated = percentages
        for id in selected {
            updated[id] = formatted
        }
        if let last = selected.last {
            let othersTotal = Double(selected.count - 1) * (Double(formatted) ?? each)
            updated[last] = String(format: "%.2f", 100.0 - othersTotal)
        }
        percentages = updated
    }

    /// Compute per-member split for review display.
    func computeSplitBreakdown() -> [(member: GroupMember, cents: Int)] {
        let members = selectedMemberArray
        switch splitMode {
        case .equal:
            let base = amountCents / members.count
            let remainder = amountCents - base * members.count
            return members.enumerated().map { (i, m) in
                (m, base + (i < remainder ? 1 : 0))
            }
        case .custom:
            return members.map { m in
                let cents = Int(round((Double(customAmounts[m.id] ?? "0") ?? 0) * 100))
                return (m, cents)
            }
        case .percent:
            if let converted = percentagesToCustomAmounts(
                percentages: percentages,
                selectedMemberIds: selectedMemberIds,
                totalCents: amountCents
            ) {
                return members.map { m in
                    let cents = Int(round((Double(converted[m.id] ?? "0") ?? 0) * 100))
                    return (m, cents)
                }
            }
            return members.map { ($0, 0) }
        }
    }
}
