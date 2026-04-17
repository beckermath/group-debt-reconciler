import SwiftUI

struct CreateGroupMembersStep: View {
    @Bindable var model: CreateGroupModel
    let onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(GroupStore.self) private var groupStore
    @State private var searchQuery = ""
    @State private var showShareSheet = false

    private var showGuestFallback: Bool {
        searchQuery.trimmingCharacters(in: .whitespaces).count >= 2
    }

    private var inviteURL: String? {
        guard let code = model.inviteCode else { return nil }
        return "https://group-debt-reconciler.vercel.app/invite/\(code)"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Type a name to add as guest...", text: $searchQuery)
                            .submitLabel(.done)
                            .onSubmit { addGuestFromSearch() }
                        if !searchQuery.isEmpty {
                            Button { searchQuery = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6), in: .rect(cornerRadius: 10))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Selected chips
                    if !model.addedGuests.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(model.addedGuests, id: \.self) { name in
                                    HStack(spacing: 6) {
                                        MemberAvatar(name: name, size: 24)
                                        Text(name)
                                            .font(.subheadline)
                                        Button {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                model.addedGuests.removeAll { $0 == name }
                                            }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray6), in: .capsule)
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 12)
                    }

                    // Guest fallback
                    if showGuestFallback {
                        Button {
                            addGuestFromSearch()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill.badge.plus")
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                Text("Add \"\(searchQuery.trimmingCharacters(in: .whitespaces))\" as guest")
                                    .font(.body)
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }

                    // Added members list
                    if !model.addedGuests.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("ADDED")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 8)

                            ForEach(model.addedGuests, id: \.self) { name in
                                HStack(spacing: 12) {
                                    MemberAvatar(name: name, size: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name)
                                            .font(.body)
                                        Text("Guest")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color.balancePositive)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                Divider().padding(.leading, 68)
                            }
                        }
                    }

                    // Empty state
                    if model.addedGuests.isEmpty && searchQuery.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.2")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary.opacity(0.3))
                            Text("No members yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Type a name to add guests")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    }
                }
                .padding(.bottom, 80)
            }
            .scrollDismissesKeyboard(.interactively)

            // Done button
            VStack(spacing: 0) {
                Divider()
                Button {
                    Task { await submitAndClose() }
                } label: {
                    if model.isSubmitting || model.isCreating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 22)
                    } else {
                        Text(model.addedGuests.isEmpty ? "Skip for now" : "Done (\(model.addedGuests.count) \(model.addedGuests.count == 1 ? "person" : "people"))")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.isSubmitting || model.isCreating)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .background(.background)

            if let error = model.error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(Color.balanceNegative)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.balanceNegative.opacity(0.08))
            }
        }
        .navigationTitle("Add Members")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await generateAndShare() }
                } label: {
                    if model.isGeneratingLink {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(model.isGeneratingLink)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = inviteURL {
                ShareSheet(items: [url])
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Actions

    private func addGuestFromSearch() {
        let name = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !model.addedGuests.contains(name) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            model.addedGuests.append(name)
        }
        searchQuery = ""
    }

    private func generateAndShare() async {
        // Create group first if needed
        if model.groupId == nil {
            guard await createGroup() else { return }
        }
        guard let groupId = model.groupId else { return }

        if model.inviteCode == nil {
            model.isGeneratingLink = true
            do {
                let code = try await groupStore.createInviteLink(groupId: groupId)
                model.inviteCode = code
            } catch let apiError as APIError {
                model.error = apiError.errorDescription
                model.isGeneratingLink = false
                return
            } catch {
                model.error = "Failed to generate link"
                model.isGeneratingLink = false
                return
            }
            model.isGeneratingLink = false
        }
        showShareSheet = true
    }

    private func submitAndClose() async {
        model.isSubmitting = true
        model.error = nil

        // Create group if not yet created
        if model.groupId == nil {
            guard await createGroup() else {
                model.isSubmitting = false
                return
            }
        }
        guard let groupId = model.groupId else { return }

        do {
            for name in model.addedGuests {
                try await groupStore.addMember(groupId: groupId, name: name)
            }
            await groupStore.loadGroups(forceReload: true)
            onComplete(groupId)
        } catch let apiError as APIError {
            model.error = apiError.errorDescription
            model.isSubmitting = false
        } catch {
            model.error = "Failed to add members"
            model.isSubmitting = false
        }
    }

    /// Creates the group on the server. Returns true on success.
    private func createGroup() async -> Bool {
        model.isCreating = true
        model.error = nil
        do {
            let groupId = try await groupStore.createGroup(name: model.trimmedName)
            model.groupId = groupId
            model.isCreating = false
            return true
        } catch let apiError as APIError {
            model.error = apiError.errorDescription
            model.isCreating = false
            return false
        } catch {
            model.error = "Failed to create group"
            model.isCreating = false
            return false
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
