import SwiftUI

struct GroupSetupScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var searchQuery = ""
    @State private var guestName = ""
    @State private var addedMembers: [(name: String, type: String)] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Group name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Trip to Berlin, Rent, Dinner...", text: $groupName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Add people
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Who's splitting expenses?")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        // Search
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search by name or phone...", text: $searchQuery)
                        }
                        .padding(10)
                        .background(Color(.systemGray6), in: .rect(cornerRadius: 10))

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
                                    if !guestName.trimmingCharacters(in: .whitespaces).isEmpty {
                                        addedMembers.append((name: guestName.trimmingCharacters(in: .whitespaces), type: "guest"))
                                        guestName = ""
                                    }
                                }
                                .disabled(guestName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }

                        // Added members list
                        if !addedMembers.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(Array(addedMembers.enumerated()), id: \.offset) { index, member in
                                    HStack {
                                        MemberAvatar(name: member.name, size: 28)
                                        Text(member.name)
                                            .font(.subheadline)
                                        Text(member.type)
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                member.type == "invited"
                                                    ? Color.accentColor.opacity(0.1)
                                                    : Color(.systemGray5),
                                                in: .capsule
                                            )
                                            .foregroundStyle(
                                                member.type == "invited" ? Color.accentColor : .secondary
                                            )
                                        Spacer()
                                        Button {
                                            addedMembers.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                    if index < addedMembers.count - 1 {
                                        Divider().padding(.leading, 48)
                                    }
                                }
                            }
                            .background(Color(.systemGray6), in: .rect(cornerRadius: 10))

                            Text("\(addedMembers.count) \(addedMembers.count == 1 ? "person" : "people") added")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Start button
                    Button {
                        dismiss()
                    } label: {
                        Text(addedMembers.isEmpty ? "Skip for now" : "Start splitting expenses")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    // Invite link
                    dividerWithText("or share a link")

                    Button {} label: {
                        Label("Generate invite link", systemImage: "link")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Create your group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
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
    GroupSetupScreen()
}
