import SwiftUI

struct BalanceBar: View {
    let balance: Int
    let maxAbsBalance: Int

    private var percentage: CGFloat {
        guard maxAbsBalance > 0 else { return 0 }
        return max(CGFloat(abs(balance)) / CGFloat(maxAbsBalance), 0.04)
    }

    var body: some View {
        if balance != 0, maxAbsBalance > 0 {
            GeometryReader { geo in
                let barWidth = geo.size.width * percentage
                ZStack(alignment: balance > 0 ? .leading : .trailing) {
                    Capsule()
                        .fill(Color(.systemGray5))
                    Capsule()
                        .fill(balance > 0 ? Color.balancePositive.opacity(0.6) : Color.balanceNegative.opacity(0.5))
                        .frame(width: barWidth)
                }
            }
            .frame(height: 5)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        BalanceBar(balance: 2450, maxAbsBalance: 2450)
        BalanceBar(balance: -1225, maxAbsBalance: 2450)
        BalanceBar(balance: -1225, maxAbsBalance: 2450)
    }
    .padding()
}
