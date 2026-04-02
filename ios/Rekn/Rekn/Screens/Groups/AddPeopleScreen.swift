import SwiftUI

struct AddPeopleScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var guestName = ""
    @State private var addedGuests: [String] = []
    @State private var showSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Search
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search existing users")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search by name or phone...", text: $searchQuery)
                    }
                    .padding(10)
                    .background(Color(.systemGray6), in: .rect(cornerRadius: 10))

                    if searchQuery.count >= 3 {
                        Text("No users found for \"\(searchQuery)\"")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                }

                // Divider
                dividerWithText("or")

                // Guest input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add someone without a Rekn account")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("Guest name", text: $guestName)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            let trimmed = guestName.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                addedGuests.append(trimmed)
                                guestName = ""
                            }
                        }
                        .disabled(guestName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                // Added list
                if !addedGuests.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(addedGuests.enumerated()), id: \.offset) { index, name in
                            HStack {
                                MemberAvatar(name: name, size: 28)
                                Text(name)
                                    .font(.subheadline)
                                Text("guest")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray5), in: .capsule)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    addedGuests.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            if index < addedGuests.count - 1 {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }
                    .background(Color(.systemGray6), in: .rect(cornerRadius: 10))

                    Text("\(addedGuests.count) \(addedGuests.count == 1 ? "person" : "people") added")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Divider
                dividerWithText("or")

                // Invite link
                Button {} label: {
                    Label("Generate invite link", systemImage: "link")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Add People")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dividerWithText(_ text: String) -> some View {
        HStack {
            Rectangle().fill(Color(.separator)).frame(height: 0.5)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle().fill(Color(.separator)).frame(height: 0.5)
        }
    }
}

#Preview {
    NavigationStack {
        AddPeopleScreen()
    }
}
