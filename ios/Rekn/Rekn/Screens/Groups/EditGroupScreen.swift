import SwiftUI
import PhotosUI

struct EditGroupScreen: View {
    let groupId: String
    @Environment(\.dismiss) private var dismiss
    @Environment(GroupStore.self) private var groupStore

    @State private var groupName = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var bannerData: Data?
    @State private var bannerPreview: Image?
    @State private var removeBannerFlag = false
    @State private var isSaving = false
    @State private var error: String?

    // Guest member adding
    @State private var guestName = ""
    @State private var addedGuests: [String] = []

    private var detail: GroupDetail? {
        if case .loaded(let d) = groupStore.detailState, d.id == groupId { return d }
        return nil
    }

    private var hasChanges: Bool {
        let nameChanged = groupName != (detail?.name ?? "")
        let bannerChanged = bannerData != nil || removeBannerFlag
        let hasGuests = !addedGuests.isEmpty
        return nameChanged || bannerChanged || hasGuests
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Banner section
                bannerSection

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

                // Add people section
                addPeopleSection

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
            .padding()
            .padding(.bottom, 48)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Edit Group")
        .navigationBarTitleDisplayMode(.inline)
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
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    // Convert to JPEG, downscale if needed
                    if let uiImage = UIImage(data: data) {
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
                        if let jpeg = scaled.jpegData(compressionQuality: 0.7) {
                            bannerData = jpeg
                            bannerPreview = Image(uiImage: scaled)
                            removeBannerFlag = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Banner Section

    private var bannerSection: some View {
        VStack(spacing: 10) {
            ZStack {
                if let bannerPreview {
                    bannerPreview
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 160)
                        .clipped()
                        .clipShape(.rect(cornerRadius: 14))
                } else if let urlString = detail?.bannerUrl, !removeBannerFlag, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 160)
                                .clipped()
                                .clipShape(.rect(cornerRadius: 14))
                        default:
                            bannerPlaceholder
                        }
                    }
                } else {
                    bannerPlaceholder
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)

            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label(hasBanner ? "Change Photo" : "Add Photo", systemImage: "photo")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                if hasBanner {
                    Button(role: .destructive) {
                        bannerData = nil
                        bannerPreview = nil
                        selectedItem = nil
                        removeBannerFlag = true
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }

    private var hasBanner: Bool {
        bannerPreview != nil || (detail?.bannerUrl != nil && !removeBannerFlag)
    }

    private var bannerPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("Add a banner image")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(Color(.systemGray6), in: .rect(cornerRadius: 14))
    }

    // MARK: - Add People Section

    private var addPeopleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ADD PEOPLE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(0.3)

            HStack(spacing: 8) {
                TextField("Guest name...", text: $guestName)
                    .submitLabel(.done)
                    .onSubmit { addGuest() }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6), in: .rect(cornerRadius: 10))

                Button {
                    addGuest()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .disabled(guestName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !addedGuests.isEmpty {
                ForEach(addedGuests, id: \.self) { name in
                    HStack(spacing: 10) {
                        MemberAvatar(name: name, size: 32)
                        Text(name)
                            .font(.subheadline)
                        Spacer()
                        Button {
                            addedGuests.removeAll { $0 == name }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Current members
            if let members = detail?.members, !members.isEmpty {
                Text("CURRENT MEMBERS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .tracking(0.3)
                    .padding(.top, 8)

                ForEach(members) { member in
                    HStack(spacing: 10) {
                        MemberAvatar(name: member.name, imageUrl: member.imageUrl, size: 32)
                        Text(member.name)
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Actions

    private func addGuest() {
        let name = guestName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        addedGuests.append(name)
        guestName = ""
    }

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
            if let bannerData {
                _ = try await groupStore.uploadBanner(groupId: groupId, imageData: bannerData)
            } else if removeBannerFlag {
                try await groupStore.removeBanner(groupId: groupId)
            }

            // Add guest members
            for name in addedGuests {
                try await groupStore.addMember(groupId: groupId, name: name)
            }

            // Refresh data
            await groupStore.loadGroupDetail(id: groupId, forceReload: true)
            await groupStore.loadGroups(forceReload: true)
            dismiss()
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = "Failed to save changes"
        }
    }
}

#Preview {
    NavigationStack {
        EditGroupScreen(groupId: "test")
            .environment(GroupStore())
    }
}
