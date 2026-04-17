import SwiftUI

struct GroupDetailScreen: View {
    let groupId: String
    @Environment(\.dismiss) private var dismiss
    @Environment(GroupStore.self) private var groupStore
    @Environment(AuthManager.self) private var authManager
    @State private var showingAddExpense = false
    @State private var showingEditGroup = false
    @State private var showingSettleUp = false
    @State private var showingInviteComposer = false
    @State private var selectedExpense: Expense?
    @State private var selectedSettlement: Settlement?
    @State private var selectedMember: GroupMember?
    @State private var highlightedExpenseId: String?
    @State private var selectedPage: DetailPage = .activity
    @State private var hScrollPosition = ScrollPosition(id: DetailPage.activity, anchor: .center)
    @State private var showAllMembers = false
    @State private var bannerTint: Color = Color.warmBackgroundTop
    @State private var bannerTintIsDark = false
    @State private var bannerCollapsed = false
    @State private var currentScrollOffset: CGFloat = 0
    @State private var overscrollAmount: CGFloat = 0
    @State private var horizontalOffset: CGFloat = UIScreen.main.bounds.width
    @State private var isProgrammaticScroll = true
    @State private var initialLayoutDone = false
    @State private var pillFrames: [DetailPage: CGRect] = [:]
    @State private var membersScrollPos = ScrollPosition(edge: .top)
    @State private var activityScrollPos = ScrollPosition(edge: .top)
    @State private var balancesScrollPos = ScrollPosition(edge: .top)
    private let maxBannerHeight: CGFloat = 200

    @State private var contentTopY: CGFloat = 100 // measured global Y of content area top

    enum DetailPage: Int, CaseIterable {
        case members = 0
        case activity = 1
        case balances = 2

        var title: String {
            switch self {
            case .members: "Members"
            case .activity: "Activity"
            case .balances: "Balances"
            }
        }
    }

    private var detail: GroupDetail? {
        if case .loaded(let d) = groupStore.detailState { return d }
        return nil
    }
    private var balances: [BalanceEntry] { detail?.balances ?? [] }
    private var transfers: [Transfer] { detail?.transfers ?? [] }
    private var expenses: [Expense] { detail?.expenses ?? [] }
    private var settlements: [Settlement] { detail?.settlements ?? [] }
    private var groupName: String { detail?.name ?? "Group" }

    private var currentUserBalance: BalanceEntry? {
        guard let userId = authManager.currentUser?.id else { return nil }
        let memberIds = detail?.members.filter { $0.userId == userId }.map(\.id) ?? []
        return balances.first { memberIds.contains($0.memberId) }
    }

    private var activeBalances: [BalanceEntry] {
        balances.filter { $0.balanceCents != 0 }
    }

    private var settledMembers: [BalanceEntry] {
        balances.filter { $0.balanceCents == 0 }
    }

    private var hasBanner: Bool {
        detail?.bannerUrl != nil
    }

    private var isGroupSettled: Bool {
        activeBalances.isEmpty && transfers.isEmpty
    }

    var body: some View {
        Group {
            switch groupStore.detailState {
            case .idle, .loading:
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(WarmGradientBackground().ignoresSafeArea())
            case .failed(let msg):
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Couldn't load group")
                        .font(.headline)
                    Text(msg)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await groupStore.loadGroupDetail(id: groupId) }
                    } label: {
                        Text("Try Again")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded:
                mainContent
                    .transition(.opacity.animation(.easeIn(duration: 0.3)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: groupStore.detailState.isLoaded)
        .task { await groupStore.loadGroupDetail(id: groupId) }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack(alignment: .bottomTrailing) {
            // Full-screen background — image bleeds behind nav bar
            bannerBackground
                .ignoresSafeArea()

            // Nav + capsule tint — single Canvas, no overlap possible

            // Pages + single shared tab bar
            ZStack(alignment: .top) {
                // Measure where this ZStack starts in screen coordinates
                Color.clear.frame(height: 0)
                    .background {
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                contentTopY = geo.frame(in: .global).minY
                            }
                        }
                    }
                // Horizontal paging — tracks finger position for pill animation
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        pageScrollView(page: .members, scrollPos: $membersScrollPos) { membersPage }
                            .id(DetailPage.members)
                            .containerRelativeFrame(.horizontal)
                        pageScrollView(page: .activity, scrollPos: $activityScrollPos) {
                            summaryStrip
                                .padding(.bottom, 12)
                            activityContent
                        }
                        .id(DetailPage.activity)
                        .containerRelativeFrame(.horizontal)
                        pageScrollView(page: .balances, scrollPos: $balancesScrollPos) {
                            balancesContent
                        }
                        .id(DetailPage.balances)
                        .containerRelativeFrame(.horizontal)
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition($hScrollPosition)
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.x
                } action: { _, xOffset in
                    guard initialLayoutDone else { return }
                    horizontalOffset = xOffset
                    guard !isProgrammaticScroll else { return }
                    // Determine which page is currently visible
                    let pageWidth = UIScreen.main.bounds.width
                    let pageIndex = Int((xOffset + pageWidth / 2) / pageWidth)
                    let clamped = max(0, min(DetailPage.allCases.count - 1, pageIndex))
                    let newPage = DetailPage.allCases[clamped]
                    if newPage != selectedPage {
                        selectedPage = newPage
                        if !bannerCollapsed {
                            currentScrollOffset = 0
                        }
                    }
                }
                .onChange(of: selectedPage) { _, newPage in
                    isProgrammaticScroll = true
                    withAnimation(.snappy(duration: 0.25)) {
                        hScrollPosition.scrollTo(id: newPage, anchor: .center)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isProgrammaticScroll = false
                    }
                }
                .task {
                    // Ensure we start on Activity after layout is complete
                    isProgrammaticScroll = true
                    try? await Task.sleep(for: .milliseconds(50))
                    hScrollPosition.scrollTo(id: DetailPage.activity, anchor: .center)
                    try? await Task.sleep(for: .milliseconds(100))
                    isProgrammaticScroll = false
                    selectedPage = .activity
                    initialLayoutDone = true
                }

                // Style-specific backdrop behind pills
                if hasBanner {
                    let pillY = !hasBanner ? 0.0
                        : bannerCollapsed ? min(bannerSpacerHeight, overscrollAmount)
                        : max(0, bannerSpacerHeight - currentScrollOffset)

                    switch tabBarStyle {
                    case .materialStrip:
                        // Frosted strip that clips content behind pills
                        VStack(spacing: 0) {
                            Rectangle().fill(.ultraThinMaterial)
                                .frame(height: pillBarHeight + 12)
                            LinearGradient(colors: [Color.warmBackgroundBottom.opacity(0.5), .clear],
                                           startPoint: .top, endPoint: .bottom)
                                .frame(height: 10)
                        }
                        .offset(y: pillY - 2)
                        .allowsHitTesting(false)

                    case .softTintBar:
                        let scrollProgress = bannerCollapsed ? 1.0 : min(1, currentScrollOffset / bannerSpacerHeight)
                        let tintOpacity = 0.1 + scrollProgress * 0.1 // 0.1 at rest → 0.2 at nav bar
                        let fade: CGFloat = 20
                        Canvas { context, size in
                            let w = size.width
                            let navEnd = contentTopY
                            let pillTop = contentTopY + pillY
                            let pillH = pillBarHeight + 2
                            let pillBot = pillTop + pillH
                            let gap = pillTop - navEnd

                            // 1. Nav solid (screen top → start of fade/bridge)
                            let navSolidEnd = gap > fade * 2 ? navEnd : navEnd // full solid to edge
                            context.fill(Path(CGRect(x: 0, y: 0, width: w, height: navSolidEnd)),
                                         with: .color(bannerTint.opacity(0.2)))

                            // 2. Bridge / fades between nav and capsule
                            if gap > 20 {
                                // Large gap: independent fades, banner visible between
                                context.fill(
                                    Path(CGRect(x: 0, y: navEnd, width: w, height: fade)),
                                    with: .linearGradient(
                                        Gradient(colors: [bannerTint.opacity(0.2), .clear]),
                                        startPoint: CGPoint(x: 0, y: navEnd),
                                        endPoint: CGPoint(x: 0, y: navEnd + fade)))
                                context.fill(
                                    Path(CGRect(x: 0, y: pillTop - fade, width: w, height: fade)),
                                    with: .linearGradient(
                                        Gradient(colors: [.clear, bannerTint.opacity(tintOpacity)]),
                                        startPoint: CGPoint(x: 0, y: pillTop - fade),
                                        endPoint: CGPoint(x: 0, y: pillTop)))
                            } else if gap > 0 {
                                // Small gap: smooth gradient from nav opacity → capsule opacity
                                context.fill(
                                    Path(CGRect(x: 0, y: navEnd, width: w, height: gap)),
                                    with: .linearGradient(
                                        Gradient(colors: [bannerTint.opacity(0.2), bannerTint.opacity(tintOpacity)]),
                                        startPoint: CGPoint(x: 0, y: navEnd),
                                        endPoint: CGPoint(x: 0, y: pillTop)))
                            }
                            // gap == 0: they share the edge, nothing needed

                            // 3. Capsule solid
                            context.fill(Path(CGRect(x: 0, y: pillTop, width: w, height: pillH)),
                                         with: .color(bannerTint.opacity(tintOpacity)))

                            // 4. Capsule bottom fade
                            context.fill(
                                Path(CGRect(x: 0, y: pillBot, width: w, height: fade)),
                                with: .linearGradient(
                                    Gradient(colors: [bannerTint.opacity(tintOpacity), .clear]),
                                    startPoint: CGPoint(x: 0, y: pillBot),
                                    endPoint: CGPoint(x: 0, y: pillBot + fade)))
                        }
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    case .extendedGradient:
                        EmptyView() // Handled in bannerBackground gradient stops
                    }
                }

                // Single shared tab bar — moves with scroll, pins at top
                tabBar
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .offset(y: !hasBanner ? 0
                        : bannerCollapsed ? min(bannerSpacerHeight, overscrollAmount)
                        : max(0, bannerSpacerHeight - currentScrollOffset))
            }

            fab
                .padding(.trailing, 20)
                .padding(.bottom, 20)
        }
        .navigationTitle(groupName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(hasBanner && bannerTintIsDark ? .dark : .light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingEditGroup = true } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseScreen(groupId: groupId, memberList: detail?.members ?? [], currentUserId: authManager.currentUser?.id)
        }
        .sheet(isPresented: $showingInviteComposer) {
            InviteComposerSheet(groupId: groupId, groupName: groupName)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSettleUp) {
            SettleUpScreen(groupId: groupId, transfers: transfers)
                .presentationDetents([.medium, .fraction(0.6)])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedExpense) { expense in
            ExpenseDetailScreen(expense: expense, groupId: groupId) {
                highlightedExpenseId = expense.id
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { highlightedExpenseId = nil }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedSettlement) { settlement in
            SettlementDetailScreen(
                settlement: settlement,
                groupId: groupId,
                includedExpenses: detail?.expenses(for: settlement) ?? []
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedMember) { member in
            MemberDetailSheet(
                member: member,
                balance: balances.first { $0.memberId == member.id },
                expenses: expenses.filter { $0.paidByMemberId == member.id },
                isCurrentUser: authManager.currentUser?.id == member.userId
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: $showingEditGroup) {
            EditGroupScreen(groupId: groupId) {
                // Group was deleted — pop back to groups list
                dismiss()
            }
        }
        .onChange(of: showingAddExpense) { _, isShowing in
            if !isShowing {
                if let newest = expenses.first {
                    highlightedExpenseId = newest.id
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { highlightedExpenseId = nil }
                    }
                }
            }
        }
    }

    // MARK: - Banner Background

    @ViewBuilder
    private var bannerBackground: some View {
        if detail?.bannerUrl != nil {
            GeometryReader { geo in
                let bannerH = geo.size.height * 0.35

                ZStack {
                    // Base: always visible underneath
                    Color.warmBackgroundBottom

                    VStack(spacing: 0) {
                        if let urlString = detail?.bannerUrl, let url = URL(string: urlString) {
                            // Banner image + gradient overlays
                            ZStack {
                                CachedBannerImage(url: url, height: bannerH) { color in
                                    bannerTint = color
                                    // Compute luminance to decide light/dark text
                                    let uiColor = UIColor(color)
                                    var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0
                                    uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
                                    let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                                    bannerTintIsDark = luminance < 0.5
                                }
                                .frame(width: geo.size.width, height: bannerH)
                                .clipped()

                                // Top fade — darkens behind nav title for readability
                                LinearGradient(
                                    stops: [
                                        .init(color: .black.opacity(0.4), location: 0),
                                        .init(color: .black.opacity(0.15), location: 0.25),
                                        .init(color: .clear, location: 0.45),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: bannerH)

                                // Bottom fade — blends into tint color
                                // extendedGradient starts earlier for more tint coverage at pill area
                                LinearGradient(
                                    stops: tabBarStyle == .extendedGradient ? [
                                        .init(color: .clear, location: 0.5),
                                        .init(color: bannerTint.opacity(0.5), location: 0.7),
                                        .init(color: bannerTint.opacity(0.85), location: 0.85),
                                        .init(color: bannerTint, location: 1.0),
                                    ] : [
                                        .init(color: .clear, location: 0.65),
                                        .init(color: bannerTint.opacity(0.6), location: 0.85),
                                        .init(color: bannerTint, location: 1.0),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: bannerH)
                            }
                            .frame(height: bannerH)
                        }

                        // Tint → background gradient
                        LinearGradient(
                            stops: [
                                .init(color: bannerTint, location: 0),
                                .init(color: bannerTint.opacity(0.3), location: 0.4),
                                .init(color: Color.warmBackgroundBottom, location: 1.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: geo.size.height * 0.35)

                        Color.warmBackgroundBottom
                    }
                }
            }
        } else {
            WarmGradientBackground()
        }
    }

    // MARK: - Page ScrollView

    private let pillBarHeight: CGFloat = 44

    private let bannerSpacerHeight: CGFloat = 120

    private func pageScrollView<Content: View>(page: DetailPage, scrollPos: Binding<ScrollPosition>, @ViewBuilder content: @escaping () -> Content) -> some View {
        let topInset = (hasBanner && !bannerCollapsed ? bannerSpacerHeight : 0) + pillBarHeight + 16

        return ScrollView {
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 88)
        }
        .scrollPosition(scrollPos)
        .contentMargins(.top, topInset, for: .scrollContent)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top
        } action: { _, offset in
            if selectedPage == page {
                currentScrollOffset = max(0, offset)
            }
            if offset > bannerSpacerHeight && !bannerCollapsed {
                bannerCollapsed = true
                overscrollAmount = 0
            }
            // Track overscroll continuously for finger-tracking reveal
            if bannerCollapsed && selectedPage == page {
                overscrollAmount = max(0, -offset)
                // Commit reveal once pulled past threshold
                if overscrollAmount > bannerSpacerHeight * 0.7 {
                    bannerCollapsed = false
                    currentScrollOffset = 0
                    overscrollAmount = 0
                    membersScrollPos.scrollTo(edge: .top)
                    activityScrollPos.scrollTo(edge: .top)
                    balancesScrollPos.scrollTo(edge: .top)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .refreshable { await groupStore.loadGroupDetail(id: groupId, forceReload: true) }
    }

    // MARK: - Tab Bar
    //
    // Switch between options here:
    //   .materialStrip  — frosted material strip behind pills, content clips below
    //   .extendedGradient — banner gradient extends to cover pill area naturally
    //   .softTintBar — bannerTint bar with soft faded edges above and below
    //
    private let tabBarStyle: TabBarStyle = .softTintBar

    private enum TabBarStyle {
        case materialStrip, extendedGradient, softTintBar
    }

    private var navTextColor: Color {
        hasBanner && bannerTintIsDark ? .white : .primary
    }

    private var activePillColor: Color {
        navTextColor
    }

    private var inactivePillColor: Color {
        guard hasBanner else { return Color.secondary.opacity(0.5) }
        switch tabBarStyle {
        case .materialStrip:
            return Color.secondary.opacity(0.6)
        case .extendedGradient, .softTintBar:
            return bannerTintIsDark ? Color.white.opacity(0.7) : Color.primary.opacity(0.4)
        }
    }

    private var fractionalPage: CGFloat {
        let pageWidth = UIScreen.main.bounds.width
        guard pageWidth > 0 else { return CGFloat(selectedPage.rawValue) }
        return horizontalOffset / pageWidth
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(DetailPage.allCases, id: \.self) { page in
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        selectedPage = page
                    }
                } label: {
                    Text(page.title)
                        .font(.subheadline)
                        .fontWeight(selectedPage == page ? .semibold : .regular)
                        .foregroundStyle(selectedPage == page ? activePillColor : inactivePillColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            GeometryReader { geo in
                                Color.clear.onAppear {
                                    pillFrames[page] = geo.frame(in: .named("tabBarCoord"))
                                }
                                .onChange(of: geo.size) { _, _ in
                                    pillFrames[page] = geo.frame(in: .named("tabBarCoord"))
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .coordinateSpace(name: "tabBarCoord")
        .background(alignment: .topLeading) {
            // Sliding capsule behind text — tracks the finger
            if let pillFrame = interpolatedPillFrame {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    .frame(width: pillFrame.width, height: pillFrame.height)
                    .offset(x: pillFrame.minX, y: pillFrame.minY)
            }
        }
        .padding(.vertical, 6)
    }

    private var interpolatedPillFrame: CGRect? {
        let pages = DetailPage.allCases
        let progress = fractionalPage
        let clampedProgress = max(0, min(CGFloat(pages.count - 1), progress))

        let fromIndex = Int(clampedProgress)
        let toIndex = min(fromIndex + 1, pages.count - 1)
        let fraction = clampedProgress - CGFloat(fromIndex)

        guard let fromFrame = pillFrames[pages[fromIndex]],
              let toFrame = pillFrames[pages[toIndex]] else {
            return pillFrames[selectedPage]
        }

        return CGRect(
            x: fromFrame.minX + (toFrame.minX - fromFrame.minX) * fraction,
            y: fromFrame.minY + (toFrame.minY - fromFrame.minY) * fraction,
            width: fromFrame.width + (toFrame.width - fromFrame.width) * fraction,
            height: fromFrame.height + (toFrame.height - fromFrame.height) * fraction
        )
    }

    // MARK: - Summary Strip

    private var summaryStrip: some View {
        Button {
            if !isGroupSettled {
                showingSettleUp = true
            }
        } label: {
            HStack(spacing: 10) {
                if isGroupSettled {
                    Image(systemName: "checkmark")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.balancePositive)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("All settled up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("$0.00")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.balancePositive)
                    }
                } else if let entry = currentUserBalance, entry.balanceCents != 0 {
                    Image(systemName: entry.balanceCents > 0 ? "arrow.down" : "arrow.up")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(entry.balanceCents > 0 ? .primary : Color.balanceNegative)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.balanceCents > 0 ? "You are owed" : "You owe")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatCents(abs(entry.balanceCents)))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(entry.balanceCents > 0 ? Color.balancePositive : Color.balanceNegative)
                    }
                } else {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Balances")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(activeBalances.count) unsettled")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }
                }

                Spacer()

                if !transfers.isEmpty {
                    HStack(spacing: 4) {
                        Text("\(transfers.count) to settle")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(.background, in: .rect(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Members Page

    private var membersPage: some View {
        VStack(spacing: 16) {
            if let members = detail?.members, !members.isEmpty {
                VStack(spacing: 0) {
                    Button { showingInviteComposer = true } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandSecondary.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.brandSecondary)
                            }
                            Text("Invite by phone")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)

                    Divider().padding(.horizontal, 14)

                    ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                        Button { selectedMember = member } label: {
                            HStack(spacing: 12) {
                                MemberAvatar(name: member.name, imageUrl: member.imageUrl, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    if let userId = authManager.currentUser?.id, member.userId == userId {
                                        Text("You")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else if member.userId == nil {
                                        Text("Guest")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)

                        if index < members.count - 1 {
                            Divider().padding(.horizontal, 14)
                        }
                    }
                }
                .background(.background, in: .rect(cornerRadius: 14))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            }

            // Removed members
            if let removed = detail?.removedMembers, !removed.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("REMOVED")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(removed.enumerated()), id: \.element.id) { index, member in
                            HStack(spacing: 12) {
                                MemberAvatar(name: member.name, imageUrl: member.imageUrl, size: 40)
                                    .opacity(0.5)
                                Text(member.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)

                            if index < removed.count - 1 {
                                Divider().padding(.horizontal, 14)
                            }
                        }
                    }
                    .background(.background, in: .rect(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
                }
            }
        }
    }

    // MARK: - Activity Content

    private var activityContent: some View {
        VStack(spacing: 16) {
            expenseCards

            if !settlements.isEmpty {
                sectionLabel("SETTLEMENT HISTORY")
                    .padding(.bottom, -6)
                historyCard
            }
        }
    }

    // MARK: - Balances Content

    private var balancesContent: some View {
        VStack(spacing: 16) {
            if isGroupSettled {
                // Single unified settled card
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.balancePositive)
                    Text("All settled up")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Everyone has a balance of $0.00")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(.background, in: .rect(cornerRadius: 14))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            } else {
                // Active balances
                VStack(spacing: 0) {
                    ForEach(activeBalances) { entry in
                        balanceRow(entry)
                    }

                    if !settledMembers.isEmpty {
                        if showAllMembers {
                            ForEach(settledMembers) { entry in
                                balanceRow(entry)
                            }
                        }

                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                showAllMembers.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(showAllMembers
                                    ? "Show less"
                                    : "\(settledMembers.count) settled member\(settledMembers.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: showAllMembers ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(.background, in: .rect(cornerRadius: 14))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)

                // Settle up section
                if !transfers.isEmpty {
                    HStack {
                        sectionLabel("SETTLE UP")
                        Spacer()
                        Button {
                            showingSettleUp = true
                        } label: {
                            HStack(spacing: 5) {
                                Text("Settle Up")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.brandSecondary, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, -6)

                    VStack(spacing: 0) {
                        ForEach(Array(transfers.enumerated()), id: \.element.id) { index, transfer in
                            HStack(spacing: 12) {
                                MemberAvatar(name: transfer.fromName, imageUrl: transfer.fromImageUrl, size: 36)
                                Image(systemName: "arrow.right")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                MemberAvatar(name: transfer.toName, imageUrl: transfer.toImageUrl, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(transfer.fromName) pays \(transfer.toName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(formatCents(transfer.amount))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)

                            if index < transfers.count - 1 {
                                Divider().padding(.horizontal, 14)
                            }
                        }
                    }
                    .background(.background, in: .rect(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
                }
            }
        }
    }

    // MARK: - Balance Row

    private func balanceRow(_ entry: BalanceEntry) -> some View {
        HStack(spacing: 10) {
            MemberAvatar(name: entry.name, imageUrl: entry.imageUrl, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatCents(entry.balanceCents, showSign: true))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(entry.balanceCents > 0 ? Color.balancePositive : entry.balanceCents < 0 ? Color.balanceNegative : Color.secondary)
                    Text(entry.balanceCents > 0 ? "is owed" : entry.balanceCents < 0 ? "owes" : "settled")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                BalanceBar(balance: entry.balanceCents, maxAbsBalance: entry.maxAbsBalance)
            }
        }
    }

    // MARK: - Floating Action Button

    private var fab: some View {
        Button {
            showingAddExpense = true
        } label: {
            ZStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .offset(x: -1, y: 1)
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(Color.white.opacity(0.25), in: Circle())
                    .offset(x: 8, y: -8)
            }
            .frame(width: 56, height: 56)
            .background(Color.accentColor, in: Circle())
            .shadow(color: Color.accentColor.opacity(0.35), radius: 8, y: 4)
        }
    }

    // MARK: - Expense Cards

    private var expenseCards: some View {
        Group {
            if expenses.isEmpty {
                VStack(spacing: 8) {
                    Text("No expenses yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Tap + to add your first expense.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .foregroundStyle(.quaternary)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
                        let isFirst = index == 0
                        let isLast = index == expenses.count - 1
                        let isHighlighted = highlightedExpenseId == expense.id

                        Button { selectedExpense = expense } label: {
                            ExpenseRow(expense: expense)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 0)
                                .fill(isHighlighted ? Color.balancePositive.opacity(0.1) : .clear)
                                .clipShape(.rect(
                                    topLeadingRadius: isFirst ? 14 : 0,
                                    bottomLeadingRadius: isLast ? 14 : 0,
                                    bottomTrailingRadius: isLast ? 14 : 0,
                                    topTrailingRadius: isFirst ? 14 : 0
                                ))
                        )
                        .animation(.easeOut(duration: 1.5), value: highlightedExpenseId)

                        if index < expenses.count - 1 {
                            Divider().padding(.horizontal, 14)
                        }
                    }
                }
                .background(.background, in: .rect(cornerRadius: 14))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            }
        }
    }

    // MARK: - History Card

    private var historyCard: some View {
        VStack(spacing: 0) {
            let maxCents = settlements.map(\.totalCents).max() ?? 1
            ForEach(settlements) { settlement in
                Button { selectedSettlement = settlement } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(settlement.settledAt, format: .dateTime.month(.abbreviated).day().year())
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(formatCents(settlement.totalCents))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        HStack(spacing: 6) {
                            let fraction = CGFloat(settlement.totalCents) / CGFloat(maxCents)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.25))
                                .frame(width: 48 * fraction, height: 4)
                                .frame(width: 48, alignment: .leading)

                            Text("\(settlement.expenseCount) expenses")
                            Text("·")
                                .foregroundStyle(.quaternary)
                            Text(relativeTime(settlement.settledAt))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)

                if settlement.id != settlements.last?.id {
                    Divider().padding(.horizontal, 14)
                }
            }
        }
        .background(.background, in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }

    // MARK: - Section Label

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .tracking(0.5)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    // MARK: - Helpers

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Expense Row

private struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            MemberAvatar(name: expense.paidByName, imageUrl: expense.paidByImageUrl, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(expense.paidByName)
                        .fontWeight(.medium)
                    Text("paid")
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text(relativeTime(expense.createdAt))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatCents(expense.amount))
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Scroll Offset Tracking

// MARK: - Cached Banner Image

struct CachedBannerImage: View {
    let url: URL
    let height: CGFloat
    var onColorExtracted: ((Color) -> Void)?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height)
                    .clipped()
                    .transition(.opacity)
            }
        }
        .frame(height: height)
        .task(id: url) {
            if let cached = AvatarCache.shared.get(url) {
                image = cached
                if let color = cached.averageColor {
                    onColorExtracted?(Color(color))
                }
                return
            }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let uiImage = UIImage(data: data) else { return }
            AvatarCache.shared.set(url, image: uiImage)
            if let color = uiImage.averageColor {
                onColorExtracted?(Color(color))
            }
            withAnimation(.easeIn(duration: 0.3)) {
                image = uiImage
            }
        }
    }
}

// MARK: - Vibrant Color Extraction

private extension UIImage {
    /// Extracts the most vibrant (highest saturation) color from the image
    /// by sampling a grid of pixels and picking the one with the best saturation + brightness.
    var averageColor: UIColor? {
        guard let cgImage = self.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        // Render into a bitmap we can sample
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Sample a grid of pixels (skip edges, focus on center-ish area)
        let sampleStep = max(1, min(width, height) / 20) // ~20x20 grid
        var bestColor: (r: CGFloat, g: CGFloat, b: CGFloat) = (0.5, 0.5, 0.5)
        var bestScore: CGFloat = -1

        for y in stride(from: height / 6, to: height * 5 / 6, by: sampleStep) {
            for x in stride(from: width / 6, to: width * 5 / 6, by: sampleStep) {
                let offset = (y * width + x) * bytesPerPixel
                let r = CGFloat(pixelData[offset]) / 255
                let g = CGFloat(pixelData[offset + 1]) / 255
                let b = CGFloat(pixelData[offset + 2]) / 255

                // Convert to HSB to evaluate vibrancy
                let maxC = max(r, g, b)
                let minC = min(r, g, b)
                let delta = maxC - minC
                let saturation = maxC > 0 ? delta / maxC : 0
                let brightness = maxC

                // Score: prefer high saturation with reasonable brightness
                // Ignore very dark or very light pixels
                guard brightness > 0.15 && brightness < 0.9 else { continue }
                let score = saturation * 2.0 + brightness * 0.5

                if score > bestScore {
                    bestScore = score
                    bestColor = (r, g, b)
                }
            }
        }

        // If no vibrant color found (e.g., grayscale photo), fall back to average
        if bestScore < 0.3 {
            return fallbackAverageColor()
        }

        // Desaturate by 20% to tone it down
        let gray: CGFloat = (bestColor.r + bestColor.g + bestColor.b) / 3
        let mix: CGFloat = 0.2 // 20% toward gray
        let r = bestColor.r + (gray - bestColor.r) * mix
        let g = bestColor.g + (gray - bestColor.g) * mix
        let b = bestColor.b + (gray - bestColor.b) * mix

        return UIColor(red: r, green: g, blue: b, alpha: 1)
    }

    /// Fallback: CIAreaAverage for grayscale/low-saturation images
    private func fallbackAverageColor() -> UIColor? {
        guard let ciImage = CIImage(image: self) else { return nil }
        let extent = ciImage.extent
        let inputExtent = CIVector(x: extent.origin.x, y: extent.origin.y,
                                   z: extent.size.width, w: extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage",
                                    parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: inputExtent]),
              let output = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        let ctx = CIContext(options: [.workingColorSpace: kCFNull as Any])
        ctx.render(output, toBitmap: &bitmap, rowBytes: 4,
                   bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                   format: .RGBA8, colorSpace: nil)
        return UIColor(red: CGFloat(bitmap[0]) / 255,
                       green: CGFloat(bitmap[1]) / 255,
                       blue: CGFloat(bitmap[2]) / 255,
                       alpha: 1)
    }
}

#Preview {
    NavigationStack {
        GroupDetailScreen(groupId: "1")
            .environment(GroupStore())
            .environment(AuthManager())
    }
}
