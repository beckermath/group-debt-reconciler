import SwiftUI

struct MemberAvatar: View {
    let name: String
    var imageUrl: String? = nil
    var size: CGFloat = 32
    var selected: Bool = false

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

    private let selectionInset: CGFloat = 3

    var body: some View {
        let (from, to) = gradientPair
        ZStack {
            if selected {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2.5)
                    .frame(width: size + selectionInset * 2, height: size + selectionInset * 2)
            }

            // Initials base layer (always rendered)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [from, to], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)

            // Photo overlay (fades in on top when loaded)
            if let imageUrl, !imageUrl.isEmpty, let url = URL(string: imageUrl) {
                CachedAvatarImage(url: url, size: size)
            }
        }
        .frame(width: size + selectionInset * 2, height: size + selectionInset * 2)
        .overlay(alignment: .bottomTrailing) {
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: size * 0.32))
                    .foregroundStyle(.white, Color.accentColor)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: selected)
    }
}

// MARK: - Cached Avatar Image

/// Loads and caches avatar images in memory. Reads the cache synchronously
/// on init so if an image was previously loaded, it renders on the very
/// first frame — no flash of the placeholder letter when scrolling lists
/// or navigating between screens.
struct CachedAvatarImage: View {
    let url: URL
    let size: CGFloat
    @State private var image: UIImage?

    init(url: URL, size: CGFloat) {
        self.url = url
        self.size = size
        // Seed from the in-memory cache so a warm avatar renders immediately
        // rather than flashing the letter placeholder first.
        self._image = State(initialValue: AvatarCache.shared.get(url))
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(Circle())
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .task(id: url) {
            if image != nil { return } // already hydrated from cache
            if let cached = AvatarCache.shared.get(url) {
                image = cached
                return
            }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let uiImage = UIImage(data: data) else { return }
            AvatarCache.shared.set(url, image: uiImage)
            withAnimation(.easeIn(duration: 0.25)) {
                image = uiImage
            }
        }
    }
}

// MARK: - Avatar Cache

/// Simple in-memory image cache for avatar URLs.
final class AvatarCache: @unchecked Sendable {
    static let shared = AvatarCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 100
    }

    func get(_ url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func set(_ url: URL, image: UIImage) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

#Preview {
    HStack(spacing: -8) {
        MemberAvatar(name: "Alice Johnson", size: 40)
        MemberAvatar(name: "Bob Smith", imageUrl: "https://picsum.photos/80", size: 40)
        MemberAvatar(name: "Carol Davis", size: 40)
    }
}
