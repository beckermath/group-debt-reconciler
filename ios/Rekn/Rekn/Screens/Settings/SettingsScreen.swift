import SwiftUI
import PhotosUI

struct SettingsScreen: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(GroupStore.self) private var groupStore

    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var error: String?

    private var userName: String { authManager.currentUser?.name ?? "User" }
    private var userPhone: String { authManager.currentUser?.phoneNumber ?? "No phone" }
    private var isGuest: Bool { authManager.isGuest }
    private var userImageUrl: String? { authManager.currentUser?.imageUrl }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 20) {
                // Profile card with photo
                profileCard

                // Guest upgrade prompt
                if isGuest {
                    SectionCard(header: "Upgrade") {
                        VStack(spacing: 8) {
                            Text("Sign up to save your data and invite friends")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button {
                                // TODO: navigate to phone entry for upgrade
                            } label: {
                                Text("Sign up with phone")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                        }
                        .padding(12)
                    }
                }

                // Account section
                SectionCard(header: "Account") {
                    if !isGuest {
                        SettingsRow(title: "Edit name", showChevron: true) {}
                        Divider().padding(.leading)
                    }
                    SettingsRow(title: "Sign out", isDestructive: true) {
                        Task { await authManager.signOut() }
                    }
                }

                // App section
                SectionCard(header: "App") {
                    SettingsRow(title: "Version", detail: "1.0.0")
                    Divider().padding(.leading)
                    SettingsRow(title: "Send feedback", showChevron: true) {}
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(WarmGradientBackground().ignoresSafeArea())
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task { await uploadPhoto(item: newItem) }
        }
        } // NavigationStack
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        HStack(spacing: 14) {
            // Avatar with photo picker overlay
            ZStack(alignment: .bottomTrailing) {
                MemberAvatar(name: userName, imageUrl: userImageUrl, size: 56)

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.accentColor, in: Circle())
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                }
                .offset(x: 2, y: 2)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(userName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if isGuest {
                    Text("Guest account")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(userPhone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if isUploading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Uploading...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if let error {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(Color.balanceNegative)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }

    // MARK: - Upload

    private func uploadPhoto(item: PhotosPickerItem) async {
        error = nil
        isUploading = true
        defer { isUploading = false }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            error = "Couldn't load image"
            return
        }

        // Compress and resize
        guard let uiImage = UIImage(data: data) else {
            error = "Invalid image"
            return
        }

        let maxWidth: CGFloat = 512
        let scaled: UIImage
        if uiImage.size.width > maxWidth {
            let scale = maxWidth / uiImage.size.width
            let newSize = CGSize(width: maxWidth, height: uiImage.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            scaled = renderer.image { _ in uiImage.draw(in: CGRect(origin: .zero, size: newSize)) }
        } else {
            scaled = uiImage
        }

        guard let jpeg = scaled.jpegData(compressionQuality: 0.7) else {
            error = "Couldn't compress image"
            return
        }

        do {
            let imageUrl = try await groupStore.uploadAvatar(imageData: jpeg)
            authManager.updateImageUrl(imageUrl)
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = "Upload failed"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsScreen()
            .environment(AuthManager())
            .environment(GroupStore())
    }
}
