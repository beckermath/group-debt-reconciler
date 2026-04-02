import SwiftUI

struct SettingsScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile card
                HStack(spacing: 14) {
                    MemberAvatar(name: "Alice Johnson", size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Alice Johnson")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("+1 (212) 555-1234")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(.background, in: .rect(cornerRadius: 12))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                // Account section
                SectionCard(header: "Account") {
                    SettingsRow(title: "Edit name", showChevron: true) {}
                    Divider().padding(.leading)
                    SettingsRow(title: "Sign out", isDestructive: true) {}
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

// MARK: - Section Card

struct SectionCard<Content: View>: View {
    let header: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header)
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 4)
            .background(.background, in: .rect(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let title: String
    var detail: String? = nil
    var showChevron: Bool = false
    var isDestructive: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isDestructive ? .red : .primary)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SettingsScreen()
    }
}
