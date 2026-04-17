import SwiftUI

struct InviteComposerSheet: View {
    let groupId: String
    let groupName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(InviteStore.self) private var inviteStore

    @State private var query = ""
    @State private var results: [UserSearchResult] = []
    @State private var searchState: SearchState = .idle
    @State private var sendState: SendState = .idle
    @State private var searchTask: Task<Void, Never>?

    private enum SearchState: Equatable {
        case idle
        case searching
        case loaded
        case failed(String)
    }

    private enum SendState: Equatable {
        case idle
        case sending(userId: String)
        case sent(userId: String, name: String)
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                headerCaption
                searchField
                resultsList
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .navigationTitle("Invite to \(groupName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: query) { _, newValue in
                searchTask?.cancel()
                sendState = .idle
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                guard trimmed.count >= 3 else {
                    results = []
                    searchState = .idle
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                    if Task.isCancelled { return }
                    await runSearch(trimmed)
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerCaption: some View {
        Text("Search by phone number or name to send an invite.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Phone or name", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6), in: .rect(cornerRadius: 10))
    }

    @ViewBuilder
    private var resultsList: some View {
        switch searchState {
        case .idle:
            if query.isEmpty {
                EmptyView()
            } else if query.trimmingCharacters(in: .whitespaces).count < 3 {
                centeredHint("Keep typing…")
            } else {
                EmptyView()
            }
        case .searching:
            HStack { Spacer(); ProgressView(); Spacer() }
                .padding(.top, 12)
        case .failed(let msg):
            centeredHint(msg, tone: .error)
        case .loaded:
            if results.isEmpty {
                centeredHint("No users match that search.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        resultRow(for: result)
                        if index < results.count - 1 {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
                .background(.background, in: .rect(cornerRadius: 12))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            }
        }
    }

    private func resultRow(for result: UserSearchResult) -> some View {
        let rowState = stateFor(userId: result.id)
        return HStack(spacing: 12) {
            MemberAvatar(name: result.name, imageUrl: nil, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(result.maskedPhone)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            inviteButton(for: result, rowState: rowState)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func inviteButton(for result: UserSearchResult, rowState: RowState) -> some View {
        switch rowState {
        case .idle:
            Button { send(to: result) } label: {
                Text("Invite").font(.caption).fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(Color.brandSecondary)
        case .sending:
            ProgressView().controlSize(.small)
        case .sent:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                Text("Sent").font(.caption).fontWeight(.semibold)
            }
            .foregroundStyle(Color.balancePositive)
        }
    }

    @ViewBuilder
    private func centeredHint(_ text: String, tone: HintTone = .neutral) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.subheadline)
                .foregroundStyle(tone == .error ? Color.balanceNegative : .secondary)
            Spacer()
        }
        .padding(.top, 24)
    }

    private enum HintTone { case neutral, error }

    private enum RowState { case idle, sending, sent }

    private func stateFor(userId: String) -> RowState {
        switch sendState {
        case .sending(let id) where id == userId: return .sending
        case .sent(let id, _) where id == userId: return .sent
        default: return .idle
        }
    }

    // MARK: - Actions

    private func runSearch(_ trimmed: String) async {
        await MainActor.run { searchState = .searching }
        do {
            let found = try await inviteStore.searchUsers(query: trimmed, groupId: groupId)
            if Task.isCancelled { return }
            await MainActor.run {
                results = found
                searchState = .loaded
            }
        } catch let error as APIError {
            await MainActor.run { searchState = .failed(error.errorDescription ?? "Search failed") }
        } catch {
            await MainActor.run { searchState = .failed("Search failed") }
        }
    }

    private func send(to result: UserSearchResult) {
        sendState = .sending(userId: result.id)
        Task {
            do {
                try await inviteStore.sendDirectInvite(groupId: groupId, invitedUserId: result.id)
                sendState = .sent(userId: result.id, name: result.name)
            } catch let error as APIError {
                sendState = .failed(error.errorDescription ?? "Couldn't send invite")
            } catch {
                sendState = .failed("Couldn't send invite")
            }
        }
    }
}

#Preview {
    InviteComposerSheet(groupId: "g1", groupName: "Weekend Trip")
        .environment(InviteStore())
}
