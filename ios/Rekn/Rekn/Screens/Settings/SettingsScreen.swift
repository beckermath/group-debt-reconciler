import SwiftUI

struct SettingsScreen: View {
    @Environment(AuthManager.self) private var authManager

    private var userName: String { authManager.currentUser?.name ?? "User" }
    private var userPhone: String { authManager.currentUser?.phoneNumber ?? "No phone" }
    private var isGuest: Bool { authManager.isGuest }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile card
                HStack(spacing: 14) {
                    MemberAvatar(name: userName, size: 48)
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
                    }
                    Spacer()
                }
                .padding(16)
                .background(.background, in: .rect(cornerRadius: 14))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)

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
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsScreen()
            .environment(AuthManager())
    }
}
