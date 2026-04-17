import SwiftUI

struct GloopyLoader: View {
    @State private var phase: CGFloat = 0
    let color: Color
    let dotCount: Int
    let dotSize: CGFloat

    init(color: Color = .brandPrimary, dotCount: Int = 3, dotSize: CGFloat = 12) {
        self.color = color
        self.dotCount = dotCount
        self.dotSize = dotSize
    }

    var body: some View {
        HStack(spacing: dotSize * 0.6) {
            ForEach(0..<dotCount, id: \.self) { index in
                let delay = Double(index) * 0.15
                let bounce = bounceValue(for: phase - delay)

                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(1 + bounce * 0.5)
                    .offset(y: -bounce * dotSize * 1.2)
                    .shadow(color: color.opacity(bounce * 0.4), radius: bounce * 6, y: bounce * 4)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                phase = 1.0
            }
        }
    }

    /// Creates a smooth elastic bounce curve
    private func bounceValue(for t: Double) -> CGFloat {
        let normalized = ((t.truncatingRemainder(dividingBy: 1.0)) + 1.0).truncatingRemainder(dividingBy: 1.0)
        // Active bounce phase is 0.0 to 0.5, rest is idle
        guard normalized < 0.5 else { return 0 }
        let x = normalized * 2 // 0 to 1
        // Sine-based elastic bounce
        let bounce = sin(x * .pi)
        return bounce * bounce // Sharpen the curve
    }
}

#Preview {
    VStack(spacing: 40) {
        GloopyLoader()
        GloopyLoader(color: .brandSecondary, dotSize: 16)
        GloopyLoader(color: .balancePositive, dotCount: 4, dotSize: 10)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(WarmGradientBackground())
}
