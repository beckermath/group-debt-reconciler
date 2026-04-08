import Foundation

enum SplitMode: String, CaseIterable, Identifiable {
    case equal
    case custom
    case percent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .equal: "Equal"
        case .custom: "Custom"
        case .percent: "Percent"
        }
    }
}

/// Convert percentage strings to dollar-amount strings suitable for the API's `customAmounts` field.
///
/// Returns `nil` if the percentages don't sum to 100% (within 0.01 tolerance).
/// Handles penny rounding by assigning remainder pennies to the first N members.
func percentagesToCustomAmounts(
    percentages: [String: String],
    selectedMemberIds: Set<String>,
    totalCents: Int
) -> [String: String]? {
    let memberIds = selectedMemberIds.sorted()
    guard !memberIds.isEmpty, totalCents > 0 else { return nil }

    // Parse percentages and validate sum
    let parsed: [(String, Double)] = memberIds.map { id in
        (id, Double(percentages[id] ?? "0") ?? 0)
    }
    let percentSum = parsed.reduce(0.0) { $0 + $1.1 }
    guard abs(percentSum - 100.0) < 0.01 else { return nil }

    // Compute raw cents per member
    var rawCents = parsed.map { (id, pct) in
        (id, pct / 100.0 * Double(totalCents))
    }

    // Floor each and distribute remainder pennies
    var floored = rawCents.map { ($0.0, Int(floor($0.1))) }
    let flooredTotal = floored.reduce(0) { $0 + $1.1 }
    var remainder = totalCents - flooredTotal

    // Sort by fractional part descending to assign pennies fairly
    let fractionals = rawCents.enumerated().map { (i, pair) in
        (i, pair.1 - floor(pair.1))
    }.sorted { $0.1 > $1.1 }

    for (i, _) in fractionals {
        guard remainder > 0 else { break }
        floored[i].1 += 1
        remainder -= 1
    }

    // Convert to dollar strings
    var result: [String: String] = [:]
    for (id, cents) in floored {
        result[id] = String(format: "%.2f", Double(cents) / 100.0)
    }
    return result
}
