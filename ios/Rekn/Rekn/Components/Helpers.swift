import Foundation

func formatCents(_ cents: Int, showSign: Bool = false) -> String {
    let value = Double(abs(cents)) / 100
    let formatted = String(format: "$%.2f", value)
    if showSign && cents > 0 { return "+\(formatted)" }
    if showSign && cents < 0 { return "-\(formatted)" }
    return formatted
}

extension Date {
    var relativeFormatted: String {
        let days = Calendar.current.dateComponents([.day], from: self, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days)d ago" }
        if days < 30 { return "\(days / 7)w ago" }
        return formatted(.dateTime.month(.abbreviated).day())
    }
}
