import SwiftUI

extension Color {
    // MARK: - Brand Colors

    /// Primary brand: Warm Slate
    static let brand = Color.accentColor

    /// Secondary brand: Blush
    static let brandSecondary = Color(light: .init(red: 0.831, green: 0.565, blue: 0.478),
                                       dark: .init(red: 0.894, green: 0.706, blue: 0.635))

    /// Accent brand: Warm Gold (celebrations, badges)
    static let brandAccent = Color(light: .init(red: 0.788, green: 0.659, blue: 0.298),
                                    dark: .init(red: 0.871, green: 0.678, blue: 0.416))

    // MARK: - Semantic Financial Colors

    /// Positive balance (you are owed): Sage Green
    static let balancePositive = Color(light: .init(red: 0.357, green: 0.620, blue: 0.447),
                                        dark: .init(red: 0.435, green: 0.722, blue: 0.510))

    /// Negative balance (you owe): Soft Red
    static let balanceNegative = Color(light: .init(red: 0.761, green: 0.439, blue: 0.400),
                                        dark: .init(red: 0.851, green: 0.541, blue: 0.502))

    /// Settled state
    static let balanceSettled = Color.secondary
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
