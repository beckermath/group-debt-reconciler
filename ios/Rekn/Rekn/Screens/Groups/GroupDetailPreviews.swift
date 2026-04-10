import SwiftUI

// MARK: - Mock Data Helpers

private func mockGroupStore() -> GroupStore {
    let store = GroupStore()
    store.detailState = .loaded(GroupDetail(
        id: "preview-1",
        name: "Minneapolis Fun",
        bannerUrl: "https://placekitten.com/800/600",
        members: [
            GroupMember(id: "m1", name: "Becker", userId: "user1", isRemoved: false, imageUrl: nil),
            GroupMember(id: "m2", name: "Mickey", userId: nil, isRemoved: false, imageUrl: nil),
            GroupMember(id: "m3", name: "Eddie", userId: nil, isRemoved: false, imageUrl: nil),
            GroupMember(id: "m4", name: "Eva", userId: nil, isRemoved: false, imageUrl: nil),
        ],
        balances: [
            BalanceEntry(memberId: "m1", name: "Becker", imageUrl: nil, balanceCents: 16875, maxAbsBalance: 16875),
            BalanceEntry(memberId: "m2", name: "Mickey", imageUrl: nil, balanceCents: -5625, maxAbsBalance: 16875),
            BalanceEntry(memberId: "m3", name: "Eddie", imageUrl: nil, balanceCents: -5625, maxAbsBalance: 16875),
            BalanceEntry(memberId: "m4", name: "Eva", imageUrl: nil, balanceCents: -5625, maxAbsBalance: 16875),
        ],
        transfers: [
            Transfer(fromName: "Mickey", fromImageUrl: nil, toName: "Becker", toImageUrl: nil, amount: 5625),
            Transfer(fromName: "Eddie", fromImageUrl: nil, toName: "Becker", toImageUrl: nil, amount: 5625),
            Transfer(fromName: "Eva", fromImageUrl: nil, toName: "Becker", toImageUrl: nil, amount: 5625),
        ],
        expenses: [
            Expense(id: "e1", description: "Little Ts", amount: 5680, paidByName: "Eddie", paidByMemberId: "m3", paidByImageUrl: nil, splitCount: 4, createdAt: Date()),
            Expense(id: "e2", description: "Balls", amount: 700, paidByName: "Becker", paidByMemberId: "m1", paidByImageUrl: nil, splitCount: 4, createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!),
            Expense(id: "e3", description: "Yahoo", amount: 4600, paidByName: "Becker", paidByMemberId: "m1", paidByImageUrl: nil, splitCount: 4, createdAt: Calendar.current.date(byAdding: .hour, value: -3, to: Date())!),
            Expense(id: "e4", description: "Yuck!", amount: 4600, paidByName: "Becker", paidByMemberId: "m1", paidByImageUrl: nil, splitCount: 4, createdAt: Calendar.current.date(byAdding: .hour, value: -4, to: Date())!),
            Expense(id: "e5", description: "Bloo", amount: 7000, paidByName: "Becker", paidByMemberId: "m1", paidByImageUrl: nil, splitCount: 4, createdAt: Calendar.current.date(byAdding: .hour, value: -5, to: Date())!),
            Expense(id: "e6", description: "Blah", amount: 5600, paidByName: "Becker", paidByMemberId: "m1", paidByImageUrl: nil, splitCount: 4, createdAt: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!),
        ],
        settlements: [
            Settlement(id: "s1", settledAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, settledByName: "Becker", expenseCount: 9, totalCents: 44925),
            Settlement(id: "s2", settledAt: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, settledByName: "Becker", expenseCount: 9, totalCents: 44925),
        ]
    ))
    return store
}

private func mockAuthManager() -> AuthManager {
    let auth = AuthManager()
    auth.currentUser = AuthManager.AuthUser(id: "user1", name: "Becker", phoneNumber: nil, isGuest: false, imageUrl: nil)
    auth.isAuthenticated = true
    return auth
}

// MARK: - Option A: Ultra-thin material strip behind pills + white inactive titles

/// Pills get a full-width ultra-thin material backdrop that clips content.
/// Inactive titles use white with shadow for contrast over the banner image.
#Preview("Option A: Material Strip") {
    NavigationStack {
        GroupDetailOptionA(groupId: "preview-1")
            .environment(mockGroupStore())
            .environment(mockAuthManager())
    }
}

/// Copy of GroupDetailScreen with Option A treatment applied.
/// Only the tabBar and its background are modified.
private struct GroupDetailOptionA: View {
    let groupId: String
    @Environment(GroupStore.self) var groupStore
    @Environment(AuthManager.self) var authManager
    @State private var selectedPage: GroupDetailScreen.DetailPage = .activity
    @State private var bannerTint: Color = Color(.systemBackground)
    @State private var bannerCollapsed = false
    @State private var currentScrollOffset: CGFloat = 0
    @State private var overscrollAmount: CGFloat = 0
    @State private var horizontalOffset: CGFloat = UIScreen.main.bounds.width
    @State private var isProgrammaticScroll = true
    @State private var pillFrames: [GroupDetailScreen.DetailPage: CGRect] = [:]
    @State private var hScrollPosition = ScrollPosition(id: GroupDetailScreen.DetailPage.activity, anchor: .center)
    @State private var membersScrollPos = ScrollPosition(edge: .top)
    @State private var activityScrollPos = ScrollPosition(edge: .top)
    @State private var balancesScrollPos = ScrollPosition(edge: .top)

    private let bannerSpacerHeight: CGFloat = 120
    private let pillBarHeight: CGFloat = 44

    private var detail: GroupDetail? {
        if case .loaded(let d) = groupStore.detailState { return d }
        return nil
    }
    private var hasBanner: Bool { detail?.bannerUrl != nil }
    private var expenses: [Expense] { detail?.expenses ?? [] }
    private var settlements: [Settlement] { detail?.settlements ?? [] }
    private var balances: [BalanceEntry] { detail?.balances ?? [] }
    private var transfers: [Transfer] { detail?.transfers ?? [] }

    private var fractionalPage: CGFloat {
        let w = UIScreen.main.bounds.width
        guard w > 0 else { return 1 }
        return horizontalOffset / w
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(.systemBackground).ignoresSafeArea()

            ZStack(alignment: .top) {
                // Pages
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(GroupDetailScreen.DetailPage.allCases, id: \.self) { page in
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(expenses) { expense in
                                        HStack {
                                            Circle().fill(.blue.opacity(0.3)).frame(width: 40, height: 40)
                                            VStack(alignment: .leading) {
                                                Text(expense.description).font(.subheadline).fontWeight(.medium)
                                                Text("\(expense.paidByName) paid").font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Text(formatCents(expense.amount)).font(.subheadline).fontWeight(.semibold)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 14)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 88)
                                .background(.background, in: .rect(cornerRadius: 14))
                                .padding(.horizontal, 16)
                            }
                            .contentMargins(.top, (hasBanner && !bannerCollapsed ? bannerSpacerHeight : 0) + pillBarHeight + 4, for: .scrollContent)
                            .scrollContentBackground(.hidden)
                            .containerRelativeFrame(.horizontal)
                            .id(page)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition($hScrollPosition)
                .scrollIndicators(.hidden)

                // OPTION A: Material strip behind pills
                VStack(spacing: 0) {
                    // Material strip — clips content, provides contrast
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: pillBarHeight + 8)
                        .allowsHitTesting(false)

                    // Soft fade below the strip
                    LinearGradient(colors: [Color(.systemBackground).opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 12)
                        .allowsHitTesting(false)
                }
                .offset(y: !hasBanner ? 0
                    : bannerCollapsed ? 0
                    : max(0, bannerSpacerHeight - currentScrollOffset))

                // Pills on top
                optionATabBar
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .offset(y: !hasBanner ? 0
                        : bannerCollapsed ? 0
                        : max(0, bannerSpacerHeight - currentScrollOffset))
            }
        }
        .navigationTitle(detail?.name ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var optionATabBar: some View {
        HStack(spacing: 4) {
            ForEach(GroupDetailScreen.DetailPage.allCases, id: \.self) { page in
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selectedPage = page }
                } label: {
                    Text(page.title)
                        .font(.subheadline)
                        .fontWeight(selectedPage == page ? .semibold : .medium)
                        // Option A: white inactive titles with shadow for contrast
                        .foregroundStyle(selectedPage == page ? Color.primary : Color.white.opacity(0.75))
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            GeometryReader { geo in
                                Color.clear.onAppear { pillFrames[page] = geo.frame(in: .named("tabA")) }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .coordinateSpace(name: "tabA")
        .background(alignment: .topLeading) {
            if let f = interpolatedFrame {
                Capsule().fill(.ultraThinMaterial)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    .frame(width: f.width, height: f.height)
                    .offset(x: f.minX, y: f.minY)
            }
        }
        .padding(.vertical, 6)
    }

    private var interpolatedFrame: CGRect? {
        let pages = GroupDetailScreen.DetailPage.allCases
        let p = max(0, min(CGFloat(pages.count - 1), fractionalPage))
        let from = Int(p), to = min(from + 1, pages.count - 1)
        let frac = p - CGFloat(from)
        guard let ff = pillFrames[pages[from]], let tf = pillFrames[pages[to]] else { return pillFrames[selectedPage] }
        return CGRect(
            x: ff.minX + (tf.minX - ff.minX) * frac,
            y: ff.minY,
            width: ff.width + (tf.width - ff.width) * frac,
            height: ff.height
        )
    }
}

// MARK: - Option B: Extended banner gradient covers pill area

/// The banner image gradient extends further down to naturally cover the pill area.
/// No separate strip — the image's own gradient provides the contrast.
/// Content clips at the pill boundary.
#Preview("Option B: Extended Gradient") {
    NavigationStack {
        GroupDetailOptionB(groupId: "preview-1")
            .environment(mockGroupStore())
            .environment(mockAuthManager())
    }
}

private struct GroupDetailOptionB: View {
    let groupId: String
    @Environment(GroupStore.self) var groupStore
    @Environment(AuthManager.self) var authManager
    @State private var selectedPage: GroupDetailScreen.DetailPage = .activity
    @State private var bannerTint: Color = Color(.systemBackground)
    @State private var bannerCollapsed = false
    @State private var currentScrollOffset: CGFloat = 0
    @State private var overscrollAmount: CGFloat = 0
    @State private var horizontalOffset: CGFloat = UIScreen.main.bounds.width
    @State private var isProgrammaticScroll = true
    @State private var pillFrames: [GroupDetailScreen.DetailPage: CGRect] = [:]
    @State private var hScrollPosition = ScrollPosition(id: GroupDetailScreen.DetailPage.activity, anchor: .center)

    private let bannerSpacerHeight: CGFloat = 120
    private let pillBarHeight: CGFloat = 44

    private var detail: GroupDetail? {
        if case .loaded(let d) = groupStore.detailState { return d }
        return nil
    }
    private var hasBanner: Bool { detail?.bannerUrl != nil }
    private var expenses: [Expense] { detail?.expenses ?? [] }

    private var fractionalPage: CGFloat {
        let w = UIScreen.main.bounds.width
        guard w > 0 else { return 1 }
        return horizontalOffset / w
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Banner background with EXTENDED gradient that covers pill area
            if let urlString = detail?.bannerUrl, let url = URL(string: urlString) {
                GeometryReader { geo in
                    let bannerH = geo.size.height * 0.35
                    ZStack {
                        Color(.systemBackground)
                        VStack(spacing: 0) {
                            ZStack {
                                CachedBannerImage(url: url, height: bannerH) { color in bannerTint = color }
                                    .frame(width: geo.size.width, height: bannerH)
                                    .clipped()
                                // Top dark overlay for nav title
                                LinearGradient(
                                    stops: [
                                        .init(color: .black.opacity(0.4), location: 0),
                                        .init(color: .black.opacity(0.15), location: 0.25),
                                        .init(color: .clear, location: 0.45),
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                ).frame(height: bannerH)

                                // Option B: Gradient extends BELOW image into pill area
                                // Starts earlier and ends with full tint coverage at pill position
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.25),
                                        .init(color: bannerTint.opacity(0.6), location: 0.55),
                                        .init(color: bannerTint.opacity(0.9), location: 0.75),
                                        .init(color: bannerTint, location: 0.85),
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                ).frame(height: bannerH)
                            }
                            .frame(height: bannerH)

                            LinearGradient(colors: [bannerTint, Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
                                .frame(height: geo.size.height * 0.15)
                            Color(.systemBackground)
                        }
                    }
                }
                .ignoresSafeArea()
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }

            ZStack(alignment: .top) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(GroupDetailScreen.DetailPage.allCases, id: \.self) { page in
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(expenses) { expense in
                                        HStack {
                                            Circle().fill(.blue.opacity(0.3)).frame(width: 40, height: 40)
                                            VStack(alignment: .leading) {
                                                Text(expense.description).font(.subheadline).fontWeight(.medium)
                                                Text("\(expense.paidByName) paid").font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Text(formatCents(expense.amount)).font(.subheadline).fontWeight(.semibold)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 14)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 88)
                                .background(.background, in: .rect(cornerRadius: 14))
                                .padding(.horizontal, 16)
                            }
                            .contentMargins(.top, (hasBanner && !bannerCollapsed ? bannerSpacerHeight : 0) + pillBarHeight + 4, for: .scrollContent)
                            // Option B: Mask clips content at the pill boundary
                            .mask(
                                VStack(spacing: 0) {
                                    let clipHeight = hasBanner && !bannerCollapsed
                                        ? bannerSpacerHeight + pillBarHeight + 4
                                        : pillBarHeight + 4
                                    Color.clear.frame(height: clipHeight)
                                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                                        .frame(height: 10)
                                    Color.black
                                }
                            )
                            .scrollContentBackground(.hidden)
                            .containerRelativeFrame(.horizontal)
                            .id(page)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition($hScrollPosition)
                .scrollIndicators(.hidden)

                // Pills
                optionBTabBar
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .offset(y: !hasBanner ? 0
                        : bannerCollapsed ? 0
                        : max(0, bannerSpacerHeight - currentScrollOffset))
            }
        }
        .navigationTitle(detail?.name ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var optionBTabBar: some View {
        HStack(spacing: 4) {
            ForEach(GroupDetailScreen.DetailPage.allCases, id: \.self) { page in
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selectedPage = page }
                } label: {
                    Text(page.title)
                        .font(.subheadline)
                        .fontWeight(selectedPage == page ? .semibold : .medium)
                        // Inactive: light color since gradient provides solid tinted bg
                        .foregroundStyle(selectedPage == page ? Color.primary : Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            GeometryReader { geo in
                                Color.clear.onAppear { pillFrames[page] = geo.frame(in: .named("tabB")) }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .coordinateSpace(name: "tabB")
        .background(alignment: .topLeading) {
            if let f = interpolatedFrame {
                Capsule().fill(.ultraThinMaterial)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    .frame(width: f.width, height: f.height)
                    .offset(x: f.minX, y: f.minY)
            }
        }
        .padding(.vertical, 6)
    }

    private var interpolatedFrame: CGRect? {
        let pages = GroupDetailScreen.DetailPage.allCases
        let p = max(0, min(CGFloat(pages.count - 1), fractionalPage))
        let from = Int(p), to = min(from + 1, pages.count - 1)
        let frac = p - CGFloat(from)
        guard let ff = pillFrames[pages[from]], let tf = pillFrames[pages[to]] else { return pillFrames[selectedPage] }
        return CGRect(x: ff.minX + (tf.minX - ff.minX) * frac, y: ff.minY, width: ff.width + (tf.width - ff.width) * frac, height: ff.height)
    }
}

// MARK: - Option C: Tint-colored bar that fades at edges

/// A horizontal bar of bannerTint color sits behind the pills.
/// Its top and bottom edges fade to transparent, blending smoothly
/// with the image above and content below. No hard edges.
#Preview("Option C: Soft Tint Bar") {
    NavigationStack {
        GroupDetailOptionC(groupId: "preview-1")
            .environment(mockGroupStore())
            .environment(mockAuthManager())
    }
}

private struct GroupDetailOptionC: View {
    let groupId: String
    @Environment(GroupStore.self) var groupStore
    @Environment(AuthManager.self) var authManager
    @State private var selectedPage: GroupDetailScreen.DetailPage = .activity
    @State private var bannerTint: Color = Color(.systemBackground)
    @State private var bannerCollapsed = false
    @State private var currentScrollOffset: CGFloat = 0
    @State private var overscrollAmount: CGFloat = 0
    @State private var horizontalOffset: CGFloat = UIScreen.main.bounds.width
    @State private var isProgrammaticScroll = true
    @State private var pillFrames: [GroupDetailScreen.DetailPage: CGRect] = [:]
    @State private var hScrollPosition = ScrollPosition(id: GroupDetailScreen.DetailPage.activity, anchor: .center)

    private let bannerSpacerHeight: CGFloat = 120
    private let pillBarHeight: CGFloat = 44

    private var detail: GroupDetail? {
        if case .loaded(let d) = groupStore.detailState { return d }
        return nil
    }
    private var hasBanner: Bool { detail?.bannerUrl != nil }
    private var expenses: [Expense] { detail?.expenses ?? [] }

    private var fractionalPage: CGFloat {
        let w = UIScreen.main.bounds.width
        guard w > 0 else { return 1 }
        return horizontalOffset / w
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Standard banner background
            if let urlString = detail?.bannerUrl, let url = URL(string: urlString) {
                GeometryReader { geo in
                    let bannerH = geo.size.height * 0.35
                    ZStack {
                        Color(.systemBackground)
                        VStack(spacing: 0) {
                            ZStack {
                                CachedBannerImage(url: url, height: bannerH) { color in bannerTint = color }
                                    .frame(width: geo.size.width, height: bannerH).clipped()
                                LinearGradient(
                                    stops: [
                                        .init(color: .black.opacity(0.4), location: 0),
                                        .init(color: .black.opacity(0.15), location: 0.25),
                                        .init(color: .clear, location: 0.45),
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                ).frame(height: bannerH)
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.4),
                                        .init(color: bannerTint.opacity(0.8), location: 0.7),
                                        .init(color: bannerTint, location: 1.0),
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                ).frame(height: bannerH)
                            }.frame(height: bannerH)
                            LinearGradient(colors: [bannerTint, Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
                                .frame(height: geo.size.height * 0.25)
                            Color(.systemBackground)
                        }
                    }
                }.ignoresSafeArea()
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }

            ZStack(alignment: .top) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(GroupDetailScreen.DetailPage.allCases, id: \.self) { page in
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(expenses) { expense in
                                        HStack {
                                            Circle().fill(.blue.opacity(0.3)).frame(width: 40, height: 40)
                                            VStack(alignment: .leading) {
                                                Text(expense.description).font(.subheadline).fontWeight(.medium)
                                                Text("\(expense.paidByName) paid").font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Text(formatCents(expense.amount)).font(.subheadline).fontWeight(.semibold)
                                        }
                                        .padding(.vertical, 8).padding(.horizontal, 14)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.bottom, 88)
                                .background(.background, in: .rect(cornerRadius: 14))
                                .padding(.horizontal, 16)
                            }
                            .contentMargins(.top, (hasBanner && !bannerCollapsed ? bannerSpacerHeight : 0) + pillBarHeight + 4, for: .scrollContent)
                            .scrollContentBackground(.hidden)
                            .containerRelativeFrame(.horizontal)
                            .id(page)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition($hScrollPosition)
                .scrollIndicators(.hidden)

                // Option C: Soft tint bar behind pills — fades at top and bottom edges
                if hasBanner {
                    let pillY = bannerCollapsed ? 0.0 : max(0, bannerSpacerHeight - currentScrollOffset)
                    VStack(spacing: 0) {
                        // Fade in from transparent
                        LinearGradient(colors: [.clear, bannerTint.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 24)
                        // Solid-ish tint behind pills
                        bannerTint.opacity(0.85)
                            .frame(height: pillBarHeight + 8)
                        // Fade out to transparent
                        LinearGradient(colors: [bannerTint.opacity(0.85), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 20)
                    }
                    .offset(y: pillY - 24)
                    .allowsHitTesting(false)
                }

                // Pills
                optionCTabBar
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .offset(y: !hasBanner ? 0
                        : bannerCollapsed ? 0
                        : max(0, bannerSpacerHeight - currentScrollOffset))
            }
        }
        .navigationTitle(detail?.name ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var optionCTabBar: some View {
        HStack(spacing: 4) {
            ForEach(GroupDetailScreen.DetailPage.allCases, id: \.self) { page in
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selectedPage = page }
                } label: {
                    Text(page.title)
                        .font(.subheadline)
                        .fontWeight(selectedPage == page ? .semibold : .medium)
                        // Inactive: white since tint bar provides contrast
                        .foregroundStyle(selectedPage == page ? Color.primary : Color.white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            GeometryReader { geo in
                                Color.clear.onAppear { pillFrames[page] = geo.frame(in: .named("tabC")) }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .coordinateSpace(name: "tabC")
        .background(alignment: .topLeading) {
            if let f = interpolatedFrame {
                Capsule().fill(.ultraThinMaterial)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    .frame(width: f.width, height: f.height)
                    .offset(x: f.minX, y: f.minY)
            }
        }
        .padding(.vertical, 6)
    }

    private var interpolatedFrame: CGRect? {
        let pages = GroupDetailScreen.DetailPage.allCases
        let p = max(0, min(CGFloat(pages.count - 1), fractionalPage))
        let from = Int(p), to = min(from + 1, pages.count - 1)
        let frac = p - CGFloat(from)
        guard let ff = pillFrames[pages[from]], let tf = pillFrames[pages[to]] else { return pillFrames[selectedPage] }
        return CGRect(x: ff.minX + (tf.minX - ff.minX) * frac, y: ff.minY, width: ff.width + (tf.width - ff.width) * frac, height: ff.height)
    }
}
