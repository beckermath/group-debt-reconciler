import SwiftUI

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: max(0, phase - 0.3)),
                            .init(color: .white.opacity(0.4), location: phase),
                            .init(color: .clear, location: min(1, phase + 0.3)),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .mask(content)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Shapes

struct SkeletonRect: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
    }
}

struct SkeletonCircle: View {
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: size, height: size)
    }
}

// MARK: - Skeleton Group Card

struct SkeletonGroupCard: View {
    var body: some View {
        HStack(spacing: 12) {
            // Avatar cluster
            HStack(spacing: -8) {
                SkeletonCircle(size: 38)
                SkeletonCircle(size: 38)
            }

            // Text lines
            VStack(alignment: .leading, spacing: 6) {
                SkeletonRect(width: 120, height: 14)
                SkeletonRect(width: 80, height: 10)
            }

            Spacer()

            // Balance
            VStack(alignment: .trailing, spacing: 4) {
                SkeletonRect(width: 60, height: 14)
                SkeletonRect(width: 40, height: 8)
            }
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(0.5), in: .rect(cornerRadius: 14))
        .shimmer()
    }
}

// MARK: - Skeleton Group Detail

struct SkeletonGroupDetail: View {
    var body: some View {
        VStack(spacing: 0) {
            // Banner placeholder
            SkeletonRect(height: UIScreen.main.bounds.height * 0.35, cornerRadius: 0)
                .ignoresSafeArea()

            // Tab bar placeholder
            HStack(spacing: 16) {
                SkeletonRect(width: 70, height: 28, cornerRadius: 14)
                SkeletonRect(width: 70, height: 28, cornerRadius: 14)
                SkeletonRect(width: 70, height: 28, cornerRadius: 14)
            }
            .padding(.top, 12)

            // Content cards
            VStack(spacing: 12) {
                // Summary strip
                HStack {
                    SkeletonCircle(size: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        SkeletonRect(width: 80, height: 10)
                        SkeletonRect(width: 60, height: 14)
                    }
                    Spacer()
                    SkeletonRect(width: 70, height: 12)
                }
                .padding(14)
                .background(Color(.systemGray6).opacity(0.3), in: .rect(cornerRadius: 14))

                // Expense rows
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 12) {
                        SkeletonCircle(size: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            SkeletonRect(width: 140, height: 14)
                            SkeletonRect(width: 100, height: 10)
                        }
                        Spacer()
                        SkeletonRect(width: 55, height: 14)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                }
                .background(Color(.systemGray6).opacity(0.3), in: .rect(cornerRadius: 14))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()
        }
        .shimmer()
    }
}

// MARK: - Skeleton Groups List

struct SkeletonGroupsList: View {
    var body: some View {
        VStack(spacing: 12) {
            // Header skeleton
            VStack(alignment: .leading, spacing: 8) {
                SkeletonRect(width: 150, height: 24, cornerRadius: 8)
                HStack {
                    SkeletonRect(width: 100, height: 28, cornerRadius: 8)
                    Spacer()
                    HStack(spacing: 8) {
                        SkeletonRect(width: 60, height: 24, cornerRadius: 8)
                        SkeletonRect(width: 60, height: 24, cornerRadius: 8)
                    }
                }
            }
            .padding(.top, 8)

            Rectangle()
                .fill(Color(.systemGray5).opacity(0.5))
                .frame(height: 1)
                .padding(.vertical, 4)

            // Card skeletons
            ForEach(0..<4, id: \.self) { _ in
                SkeletonGroupCard()
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Step Progress Bar

struct StepProgressBar: View {
    let totalSteps: Int
    let currentStep: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.brandPrimary : Color(.systemGray4))
                    .frame(height: 3)
                    .animation(.spring(duration: 0.35), value: currentStep)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 8)
    }
}

#Preview("Skeleton Cards") {
    ScrollView {
        SkeletonGroupsList()
    }
    .background(WarmGradientBackground())
}

#Preview("Skeleton Detail") {
    SkeletonGroupDetail()
        .background(WarmGradientBackground())
}
