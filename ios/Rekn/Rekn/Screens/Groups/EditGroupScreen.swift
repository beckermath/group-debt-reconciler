import SwiftUI
import PhotosUI

struct EditGroupScreen: View {
    let groupId: String
    var onGroupDeleted: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(GroupStore.self) private var groupStore

    @State private var groupName = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var bannerData: Data?
    @State private var bannerUIImage: UIImage?
    @State private var removeBannerFlag = false
    @State private var isSaving = false
    @State private var isUploading = false
    @State private var error: String?
    @State private var showDeleteGroupConfirmation = false
    @State private var memberToRemove: GroupMember?
    @State private var isDeleting = false
    @State private var memberActionInProgress: String? // memberId being removed/restored

    // Crop gesture state
    @State private var cropScale: CGFloat = 1.0
    @State private var cropOffset: CGSize = .zero
    @State private var gestureScale: CGFloat = 1.0
    @State private var gestureOffset: CGSize = .zero
    @State private var isGesturing = false

    private let bannerHeight: CGFloat = UIScreen.main.bounds.height * 0.35

    private var detail: GroupDetail? {
        if case .loaded(let d) = groupStore.detailState, d.id == groupId { return d }
        return nil
    }

    private var hasChanges: Bool {
        let nameChanged = groupName != (detail?.name ?? "")
        let bannerChanged = bannerData != nil || removeBannerFlag
        return nameChanged || bannerChanged
    }

    private var hasBanner: Bool {
        bannerUIImage != nil || (detail?.bannerUrl != nil && !removeBannerFlag)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Banner at top, edge-to-edge
                bannerArea
                    .padding(.horizontal, -16) // counteract parent padding to bleed edge-to-edge

                // Group name
                VStack(alignment: .leading, spacing: 6) {
                    Text("GROUP NAME")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .tracking(0.3)
                    TextField("Group name", text: $groupName)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6), in: .rect(cornerRadius: 10))
                }

                // Active members
                if let members = detail?.members, !members.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("MEMBERS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .tracking(0.3)

                        VStack(spacing: 0) {
                            ForEach(members) { member in
                                HStack(spacing: 10) {
                                    MemberAvatar(name: member.name, imageUrl: member.imageUrl, size: 36)
                                    Text(member.name)
                                        .font(.subheadline)
                                    Spacer()
                                    if memberActionInProgress == member.id {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else if members.count > 1 {
                                        Button {
                                            memberToRemove = member
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(.secondary.opacity(0.5))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 6)
                                .opacity(memberActionInProgress == member.id ? 0.5 : 1)
                            }
                        }
                    }
                }

                // Removed members
                if let removed = detail?.removedMembers, !removed.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("REMOVED")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .tracking(0.3)

                        VStack(spacing: 0) {
                            ForEach(removed) { member in
                                HStack(spacing: 10) {
                                    MemberAvatar(name: member.name, imageUrl: member.imageUrl, size: 36)
                                        .opacity(0.5)
                                    Text(member.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    if memberActionInProgress == member.id {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Button {
                                            Task { await restoreMember(member) }
                                        } label: {
                                            Text("Restore")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.brandPrimary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 6)
                                .opacity(memberActionInProgress == member.id ? 0.5 : 1)
                            }
                        }
                    }
                }

                // Delete group
                Button(role: .destructive) {
                    showDeleteGroupConfirmation = true
                } label: {
                    if isDeleting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Group")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isDeleting || isSaving)
                .padding(.top, 8)

                if let error {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.balanceNegative)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.balanceNegative)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.balanceNegative.opacity(0.08), in: .rect(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(WarmGradientBackground().ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .top)
        .navigationTitle("Edit Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(hasBanner ? .dark : .light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges || isSaving)
                }
            }
        }
        .onAppear {
            groupName = detail?.name ?? ""
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    let maxWidth: CGFloat = 1200
                    let scaled: UIImage
                    if uiImage.size.width > maxWidth {
                        let scale = maxWidth / uiImage.size.width
                        let newSize = CGSize(width: maxWidth, height: uiImage.size.height * scale)
                        let renderer = UIGraphicsImageRenderer(size: newSize)
                        scaled = renderer.image { _ in uiImage.draw(in: CGRect(origin: .zero, size: newSize)) }
                    } else {
                        scaled = uiImage
                    }
                    bannerUIImage = scaled
                    bannerData = scaled.jpegData(compressionQuality: 0.7)
                    removeBannerFlag = false
                    // Reset crop
                    cropScale = 1.0
                    cropOffset = .zero
                }
            }
        }
        .confirmationDialog(
            "Delete this group?",
            isPresented: $showDeleteGroupConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Group", role: .destructive) {
                Task { await deleteGroup() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the group and all its expenses, settlements, and members. This cannot be undone.")
        }
        .confirmationDialog(
            "Remove \(memberToRemove?.name ?? "member")?",
            isPresented: Binding(
                get: { memberToRemove != nil },
                set: { if !$0 { memberToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let member = memberToRemove {
                    Task { await removeMember(member) }
                }
            }
            Button("Cancel", role: .cancel) { memberToRemove = nil }
        } message: {
            Text("This member will be removed from the group. Their expense history will be preserved.")
        }
    }

    // MARK: - Banner Area

    private var bannerArea: some View {
        ZStack {
            // Layer 1: Image (no hit testing) or empty state (tappable)
            if let bannerUIImage {
                croppableImageView(Image(uiImage: bannerUIImage))
                    .allowsHitTesting(false)

                // Gesture catcher for crop (sits below buttons)
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(cropGesture)
            } else if let urlString = detail?.bannerUrl, !removeBannerFlag, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: bannerHeight)
                            .clipped()
                    default:
                        Color(.systemGray6)
                    }
                }
                .allowsHitTesting(false)
            } else {
                // Empty state — tappable PhotosPicker
                emptyBanner
            }

            // Top gradient for nav bar readability
            if hasBanner {
                VStack {
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.45), location: 0),
                            .init(color: .clear, location: 0.40),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: bannerHeight * 0.5)
                    Spacer()
                }
                .allowsHitTesting(false)

                // Bottom gradient for button readability
                VStack {
                    Spacer()
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.5), location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: bannerHeight * 0.4)
                }
                .allowsHitTesting(false)
            }

            // Upload overlay
            if isUploading {
                Color.black.opacity(0.4)
                    .allowsHitTesting(false)
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text("Uploading...")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                .allowsHitTesting(false)
            }

            // Crop grid overlay during gesture
            if isGesturing && bannerUIImage != nil {
                cropGrid
                    .allowsHitTesting(false)
            }

            // Action buttons (bottom-right)
            if hasBanner && !isUploading && !isGesturing {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 10) {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                HStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14))
                                    Text("Change")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial.opacity(0.8))
                                .background(Color.black.opacity(0.3))
                                .clipShape(.capsule)
                            }

                            Button {
                                bannerData = nil
                                bannerUIImage = nil
                                selectedItem = nil
                                removeBannerFlag = true
                                cropScale = 1.0
                                cropOffset = .zero
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.balanceNegative)
                                    .padding(10)
                                    .background(.ultraThinMaterial.opacity(0.8))
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .frame(height: bannerHeight)
        .clipped()
    }

    // MARK: - Croppable Image

    private func croppableImageView(_ image: Image) -> some View {
        let totalScale = cropScale * gestureScale
        let totalOffset = CGSize(
            width: cropOffset.width + gestureOffset.width,
            height: cropOffset.height + gestureOffset.height
        )

        return image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: bannerHeight)
            .scaleEffect(totalScale)
            .offset(totalOffset)
            .clipped()
    }

    private var cropGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                isGesturing = true
                gestureScale = value
            }
            .onEnded { value in
                let newScale = min(max(cropScale * value, 1.0), 3.0)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    cropScale = newScale
                    gestureScale = 1.0
                    cropOffset = clampedOffset(cropOffset, scale: newScale)
                    isGesturing = false
                }
            }
            .simultaneously(with:
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        isGesturing = true
                        gestureOffset = value.translation
                    }
                    .onEnded { value in
                        let newOffset = CGSize(
                            width: cropOffset.width + value.translation.width,
                            height: cropOffset.height + value.translation.height
                        )
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            cropOffset = clampedOffset(newOffset, scale: cropScale)
                            gestureOffset = .zero
                            isGesturing = false
                        }
                    }
            )
    }

    private func clampedOffset(_ offset: CGSize, scale: CGFloat) -> CGSize {
        guard scale > 1.0 else { return .zero }
        let screenWidth = UIScreen.main.bounds.width
        let maxX = (screenWidth * (scale - 1)) / 2
        let maxY = (bannerHeight * (scale - 1)) / 2
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    // MARK: - Crop Grid

    private var cropGrid: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { path in
                // Vertical lines
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                // Horizontal lines
                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
            }
            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Empty Banner

    private var emptyBanner: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Color(.systemGray6)
                .frame(height: bannerHeight)
                .overlay(alignment: .center) {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.brandSecondary.opacity(0.5))
                        Text("Add a banner photo")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 70) // offset down to center in visible area below nav bar
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private func save() async {
        error = nil
        isSaving = true
        defer { isSaving = false }

        do {
            // Rename if changed
            if groupName != (detail?.name ?? "") {
                try await groupStore.renameGroup(id: groupId, name: groupName)
            }

            // Upload or remove banner
            if let bannerUIImage {
                isUploading = true
                // Apply crop before upload
                let cropped = applyCrop(to: bannerUIImage)
                if let jpeg = cropped.jpegData(compressionQuality: 0.7) {
                    _ = try await groupStore.uploadBanner(groupId: groupId, imageData: jpeg)
                }
                isUploading = false
            } else if removeBannerFlag {
                try await groupStore.removeBanner(groupId: groupId)
            }

            // Refresh data
            await groupStore.loadGroupDetail(id: groupId, forceReload: true)
            await groupStore.loadGroups(forceReload: true)
            dismiss()
        } catch let apiError as APIError {
            isUploading = false
            error = apiError.errorDescription
        } catch {
            isUploading = false
            self.error = "Failed to save changes"
        }
    }

    private func deleteGroup() async {
        isDeleting = true
        error = nil
        do {
            try await groupStore.deleteGroup(id: groupId)
            await groupStore.loadGroups(forceReload: true)
            dismiss()
            onGroupDeleted?()
        } catch let apiError as APIError {
            error = apiError.errorDescription
            isDeleting = false
        } catch {
            self.error = "Failed to delete group"
            isDeleting = false
        }
    }

    private func removeMember(_ member: GroupMember) async {
        error = nil
        memberToRemove = nil
        memberActionInProgress = member.id
        do {
            try await groupStore.removeMember(groupId: groupId, memberId: member.id)
            await groupStore.loadGroupDetail(id: groupId, forceReload: true)
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = "Failed to remove member"
        }
        memberActionInProgress = nil
    }

    private func restoreMember(_ member: GroupMember) async {
        error = nil
        memberActionInProgress = member.id
        do {
            try await groupStore.restoreMember(groupId: groupId, memberId: member.id)
            await groupStore.loadGroupDetail(id: groupId, forceReload: true)
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = "Failed to restore member"
        }
        memberActionInProgress = nil
    }

    @MainActor
    private func applyCrop(to image: UIImage) -> UIImage {
        guard cropScale > 1.0 || cropOffset != .zero else { return image }

        let outputWidth: CGFloat = 1200
        let frameWidth = UIScreen.main.bounds.width
        let frameHeight = bannerHeight
        let outputHeight = outputWidth * (frameHeight / frameWidth)
        let outputSize = CGSize(width: outputWidth, height: outputHeight)

        // Render exactly what the user sees by drawing the image
        // with the same aspect-fill + scale + offset transforms
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        let result = renderer.image { _ in
            let imageSize = image.size
            let imageAspect = imageSize.width / imageSize.height
            let frameAspect = frameWidth / frameHeight

            // Compute aspect-fill draw size (in frame coordinates)
            let drawWidth: CGFloat
            let drawHeight: CGFloat
            if imageAspect > frameAspect {
                drawHeight = frameHeight
                drawWidth = frameHeight * imageAspect
            } else {
                drawWidth = frameWidth
                drawHeight = frameWidth / imageAspect
            }

            // Scale everything to output resolution
            let renderScale = outputWidth / frameWidth

            // The image is centered, then scaled by cropScale, then offset
            let scaledW = drawWidth * cropScale * renderScale
            let scaledH = drawHeight * cropScale * renderScale
            let x = (outputWidth - scaledW) / 2 + cropOffset.width * renderScale
            let y = (outputHeight - scaledH) / 2 + cropOffset.height * renderScale

            image.draw(in: CGRect(x: x, y: y, width: scaledW, height: scaledH))
        }
        return result
    }
}

#Preview {
    NavigationStack {
        EditGroupScreen(groupId: "test")
            .environment(GroupStore())
    }
}
