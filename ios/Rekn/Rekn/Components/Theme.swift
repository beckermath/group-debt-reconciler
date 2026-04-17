import SwiftUI

extension Color {
    // MARK: - Brand Colors

    /// Primary brand: Teal
    static let brand = Color.accentColor

    /// Primary brand explicit: #2D7D9A
    static let brandPrimary = Color(light: .init(red: 0.176, green: 0.490, blue: 0.604),
                                     dark: .init(red: 0.275, green: 0.588, blue: 0.706))

    /// Secondary brand: Vivid Lavender #8B6CC1
    static let brandSecondary = Color(light: .init(red: 0.545, green: 0.424, blue: 0.757),
                                       dark: .init(red: 0.631, green: 0.522, blue: 0.824))

    /// Accent brand: Warm Gold (celebrations, badges)
    static let brandAccent = Color(light: .init(red: 0.788, green: 0.659, blue: 0.298),
                                    dark: .init(red: 0.871, green: 0.678, blue: 0.416))

    // MARK: - Semantic Financial Colors

    /// Positive balance (you are owed): Signal Green #2E9E5E
    static let balancePositive = Color(light: .init(red: 0.180, green: 0.620, blue: 0.369),
                                        dark: .init(red: 0.275, green: 0.722, blue: 0.463))

    /// Negative balance (you owe): Signal Red #D94452
    static let balanceNegative = Color(light: .init(red: 0.851, green: 0.267, blue: 0.322),
                                        dark: .init(red: 0.898, green: 0.380, blue: 0.420))

    /// Settled state
    static let balanceSettled = Color.secondary

    // MARK: - Page Background

    /// Plain white / system background
    static let warmBackgroundTop = Color(.systemBackground)
    static let warmBackgroundBottom = Color(.systemBackground)
}

// MARK: - Reusable Views

/// Plain background — used across all screens
struct WarmGradientBackground: View {
    var body: some View {
        Color(.systemBackground)
    }
}

// MARK: - Card Style

extension View {
    /// Copilot-style card: generous corner radius, soft shadow, no border
    func cardStyle() -> some View {
        self
            .background(.background, in: .rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

// MARK: - Light/Dark Adaptive Color Helper

private extension Color {
    init(light: Color.Resolved, dark: Color.Resolved) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: CGFloat(dark.red), green: CGFloat(dark.green), blue: CGFloat(dark.blue), alpha: 1)
                : UIColor(red: CGFloat(light.red), green: CGFloat(light.green), blue: CGFloat(light.blue), alpha: 1)
        })
    }
}
