import SwiftUI

struct GroupDetailScreen: View {
    let groupId: String
    @Environment(GroupStore.self) private var groupStore
    @Environment(AuthManager.self) private var authManager
    @State private var showingAddExpense = false
    @State private var showingEditGroup = false
    @State private var showingSettleUp = false
    @State private var highlightedExpenseId: String?
    @State private var selectedPage: DetailPage = .activity
    @State private var showAllMembers = false
    @State private var bannerTint: Color = Color(.systemBackground)
    @State private var bannerCollapsed = false
    @State private var currentScrollOffset: CGFloat = 0
    @State private var overscrollAmount: CGFloat = 0
    @State private var membersScrollPos = ScrollPosition(edge: .top)
    @State private var activityScrollPos = ScrollPosition(edge: .top)
    @State private var balancesScrollPos = ScrollPosition(edge: .top)
    private let maxBannerHeight: CGFloat = 200

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
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            }
        }
        .task { await groupStore.loadGroupDetail(id: groupId) }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack(alignment: .bottomTrailing) {
            // Full-screen background — image bleeds behind nav bar
            bannerBackground
                .ignoresSafeArea()

            // Pages + single shared tab bar
            ZStack(alignment: .top) {
                TabView(selection: $selectedPage) {
                    pageScrollView(page: .members, scrollPos: $membersScrollPos) { membersPage }
                        .tag(DetailPage.members)
                    pageScrollView(page: .activity, scrollPos: $activityScrollPos) {
                        summaryStrip
                            .padding(.bottom, 12)
                        activityContent
                    }
                    .tag(DetailPage.activity)
                    pageScrollView(page: .balances, scrollPos: $balancesScrollPos) {
                        summaryStrip
                            .padding(.bottom, 12)
                        balancesContent
                    }
                    .tag(DetailPage.balances)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: selectedPage) { _, _ in
                    // Reset so pills match the new page's position
                    if !bannerCollapsed {
                        currentScrollOffset = 0
                    }
                }

                // Single shared tab bar — moves with scroll, pins at top
                tabBar
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .offset(y: bannerCollapsed
                        ? min(bannerSpacerHeight, overscrollAmount)
                        : max(0, bannerSpacerHeight - currentScrollOffset))
            }

            fab
                .padding(.trailing, 20)
                .padding(.bottom, 20)
        }
        .navigationTitle(groupName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.automatic, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditGroup = true
                } label: {
                    Image(systemName: "pencil.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseScreen(groupId: groupId, memberList: detail?.members ?? [], currentUserId: authManager.currentUser?.id)
        }
        .navigationDestination(isPresented: $showingEditGroup) {
            EditGroupScreen(groupId: groupId)
        }
        .navigationDestination(isPresented: $showingSettleUp) {
            SettleUpScreen(groupId: groupId, transfers: transfers)
        }
        .navigationDestination(for: Expense.self) { expense in
            ExpenseDetailScreen(expense: expense, groupId: groupId)
        }
        .navigationDestination(for: Settlement.self) { settlement in
            SettlementDetailScreen(settlement: settlement)
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
                    Color(.systemBackground)

                    VStack(spacing: 0) {
                        if let urlString = detail?.bannerUrl, let url = URL(string: urlString) {
                            // Banner image + gradient overlay
                            ZStack {
                                CachedBannerImage(url: url, height: bannerH) { color in
                                    bannerTint = color
                                }
                                .frame(width: geo.size.width, height: bannerH)
                                .clipped()

                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.4),
                                        .init(color: bannerTint.opacity(0.8), location: 0.7),
                                        .init(color: bannerTint, location: 1.0),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: bannerH)
                            }
                            .frame(height: bannerH)
                        }

                        // Tint → systemBackground gradient (always present)
                        LinearGradient(
                            colors: [bannerTint, Color(.systemBackground)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: geo.size.height * 0.25)

                        Color(.systemBackground)
                    }
                }
            }
        } else {
            Color(.systemBackground)
        }
    }

    // MARK: - Page ScrollView

    private let pillBarHeight: CGFloat = 44

    private let bannerSpacerHeight: CGFloat = 120

    private func pageScrollView<Content: View>(page: DetailPage, scrollPos: Binding<ScrollPosition>, @ViewBuilder content: @escaping () -> Content) -> some View {
        let topInset = (hasBanner && !bannerCollapsed ? bannerSpacerHeight : 0) + pillBarHeight + 4

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
                        .fontWeight(selectedPage == page ? .semibold : .medium)
                        .foregroundStyle(selectedPage == page ? Color.primary : Color.secondary.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background {
                            if selectedPage == page {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
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
        .disabled(isGroupSettled)
    }

    // MARK: - Members Page

    private var membersPage: some View {
        VStack(spacing: 16) {
            if let members = detail?.members, !members.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
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
            sectionLabel("BALANCES")
                .padding(.bottom, -6)

            VStack(spacing: 0) {
                if activeBalances.isEmpty && !settledMembers.isEmpty {
                    ForEach(settledMembers) { entry in
                        balanceRow(entry)
                    }
                } else {
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
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(.background, in: .rect(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 3)

            if !transfers.isEmpty {
                HStack {
                    sectionLabel("\(transfers.count) PAYMENT\(transfers.count == 1 ? "" : "S") TO SETTLE")
                    Spacer()
                    Button {
                        showingSettleUp = true
                    } label: {
                        Text("Settle Up")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.12), in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, -6)

                VStack(spacing: 0) {
                    ForEach(transfers) { transfer in
                        HStack(spacing: 8) {
                            MemberAvatar(name: transfer.fromName, imageUrl: transfer.fromImageUrl, size: 24)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.quaternary)
                            MemberAvatar(name: transfer.toName, imageUrl: transfer.toImageUrl, size: 24)
                            Text("\(transfer.fromName) pays \(transfer.toName)")
                                .font(.caption)
                            Spacer()
                            Text(formatCents(transfer.amount))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.1), in: .capsule)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)

                        if transfer.id != transfers.last?.id {
                            Divider().padding(.horizontal, 14)
                        }
                    }
                }
                .background(.background, in: .rect(cornerRadius: 14))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            } else if isGroupSettled {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.balancePositive.opacity(0.5))
                    Text("No payments needed")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Everyone is settled up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
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
                        NavigationLink(value: expense) {
                            ExpenseRow(expense: expense)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(
                            highlightedExpenseId == expense.id
                                ? Color.brandSecondary.opacity(0.15)
                                : Color.clear
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
                NavigationLink(value: settlement) {
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

            HStack(spacing: 6) {
                Text(formatCents(expense.amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
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

private struct CachedBannerImage: View {
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

// MARK: - Average Color Extraction

private extension UIImage {
    var averageColor: UIColor? {
        guard let ciImage = CIImage(image: self) else { return nil }
        let extent = ciImage.extent
        let inputExtent = CIVector(x: extent.origin.x, y: extent.origin.y,
                                   z: extent.size.width, w: extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage",
                                    parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: inputExtent]),
              let output = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(output, toBitmap: &bitmap, rowBytes: 4,
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
