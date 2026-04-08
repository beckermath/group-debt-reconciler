import SwiftUI

struct MemberPickerScreen: View {
    let groupName: String
    let groupId: String
    var onComplete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(GroupStore.self) private var groupStore
    @State private var searchQuery = ""
    @State private var guestName = ""
    @State private var addedMembers: [PickedMember] = []
    @State private var isSubmitting = false
    @State private var error: String?

    private var showGuestFallback: Bool {
        searchQuery.trimmingCharacters(in: .whitespaces).count >= 2
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // Selected chips
            if !addedMembers.isEmpty {
                selectedChips
                    .padding(.top, 12)
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.balanceNegative)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            // Content
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Guest add — type name and add
                    if showGuestFallback {
                        guestFallbackRow
                    }

                    // Already added members
                    if !addedMembers.isEmpty {
                        Text("ADDED")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                        ForEach(addedMembers) { member in
                            HStack(spacing: 12) {
                                MemberAvatar(name: member.name, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.name)
                                        .font(.body)
                                    if member.isGuest {
                                        Text("Guest")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.green)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            Divider().padding(.leading, 68)
                        }
                    }
                }
                .padding(.bottom, 80)
            }
        }
        .navigationTitle("Add People")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            doneButton
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Type a name to add as guest...", text: $searchQuery)
                .font(.body)
                .submitLabel(.done)
                .onSubmit {
                    addGuestFromSearch()
                }
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6), in: .rect(cornerRadius: 10))
    }

    // MARK: - Selected Chips

    private var selectedChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(addedMembers) { member in
                    PickedMemberChip(member: member) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            addedMembers.removeAll { $0.id == member.id }
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 36)
    }

    // MARK: - Guest Fallback Row

    private var guestFallbackRow: some View {
        Button {
            addGuestFromSearch()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.fill.badge.plus")
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .foregroundStyle(Color.accentColor)

                Text("Add \"\(searchQuery.trimmingCharacters(in: .whitespaces))\" as guest")
                    .font(.body)
                    .foregroundStyle(Color.accentColor)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Done Button

    private var doneButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Task { await submitMembers() }
            } label: {
                if isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(addedMembers.isEmpty
                         ? "Skip for now"
                         : "Done (\(addedMembers.count) \(addedMembers.count == 1 ? "person" : "people"))")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isSubmitting)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(.background)
    }

    // MARK: - Actions

    private func addGuestFromSearch() {
        let name = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            addedMembers.append(PickedMember(
                id: UUID().uuidString,
                name: name,
                isGuest: true
            ))
        }
        searchQuery = ""
    }

    private func submitMembers() async {
        error = nil
        isSubmitting = true
        defer { isSubmitting = false }

        // Add each guest member via API
        for member in addedMembers where member.isGuest {
            do {
                try await groupStore.addMember(groupId: groupId, name: member.name)
            } catch let apiError as APIError {
                error = apiError.errorDescription
                return
            } catch {
                self.error = "Failed to add \(member.name)"
                return
            }
        }

        // Refresh groups list and navigate back
        await groupStore.loadGroups(forceReload: true)
        if let onComplete {
            onComplete()
        } else {
            dismiss()
        }
    }
}

// MARK: - Member Chip

private struct PickedMemberChip: View {
    let member: PickedMember
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            MemberAvatar(name: member.name, size: 24)
            Text(member.name.components(separatedBy: " ").first ?? member.name)
                .font(.subheadline)
                .lineLimit(1)
            if member.isGuest {
                Text("guest")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(.systemGray5), in: .capsule)
            }
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .background(Color(.systemGray6), in: .capsule)
    }
}

// MARK: - Supporting Types

struct PickedMember: Identifiable {
    let id: String
    let name: String
    let isGuest: Bool
}

#Preview {
    NavigationStack {
        MemberPickerScreen(groupName: "Ski Trip", groupId: "test-id")
            .environment(GroupStore())
    }
}
