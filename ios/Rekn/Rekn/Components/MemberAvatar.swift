import SwiftUI

struct MemberAvatar: View {
    let name: String
    var size: CGFloat = 32

    private let gradients: [(Color, Color)] = [
        (Color(red: 0.36, green: 0.13, blue: 0.73), Color(red: 0.34, green: 0.16, blue: 0.86)),
        (Color(red: 0.25, green: 0.56, blue: 0.82), Color(red: 0.21, green: 0.36, blue: 0.85)),
        (Color(red: 0.32, green: 0.65, blue: 0.42), Color(red: 0.25, green: 0.52, blue: 0.62)),
        (Color(red: 0.72, green: 0.35, blue: 0.15), Color(red: 0.58, green: 0.16, blue: 0.68)),
        (Color(red: 0.36, green: 0.13, blue: 0.93), Color(red: 0.28, green: 0.16, blue: 1.0)),
        (Color(red: 0.45, green: 0.65, blue: 0.18), Color(red: 0.25, green: 0.52, blue: 0.42)),
        (Color(red: 0.72, green: 0.13, blue: 0.58), Color(red: 0.58, green: 0.16, blue: 0.68)),
        (Color(red: 0.25, green: 0.62, blue: 0.55), Color(red: 0.21, green: 0.42, blue: 0.75)),
    ]

    private var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }

    private var gradientPair: (Color, Color) {
        let hash = abs(name.hashValue)
        return gradients[hash % gradients.count]
    }

    var body: some View {
        let (from, to) = gradientPair
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [from, to], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: -8) {
        MemberAvatar(name: "Alice Johnson", size: 40)
        MemberAvatar(name: "Bob Smith", size: 40)
        MemberAvatar(name: "Carol Davis", size: 40)
    }
}
