import SwiftUI

struct GroupNameScreen: View {
    @Binding var path: NavigationPath
    @Environment(GroupStore.self) private var groupStore
    @State private var groupName = ""
    @State private var isCreating = false
    @State private var error: String?
    @State private var createdGroupId: String?
    @State private var showingAddMembers = false
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "person.3.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.4))
                .padding(.bottom, 16)

            Text("What's this group for?")
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text("Give it a name you'll remember")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            VStack(spacing: 0) {
                TextField("Trip to Berlin, Rent, Dinner...", text: $groupName)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        guard !groupName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        Task { await createGroup() }
                    }
                    .padding(.vertical, 12)

                Rectangle()
                    .fill(nameFieldFocused ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(height: nameFieldFocused ? 1.5 : 1)
                    .animation(.easeOut(duration: 0.2), value: nameFieldFocused)
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.balanceNegative)
                    .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await createGroup() }
            } label: {
                if isCreating {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Next")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
        .navigationTitle("New Group")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingAddMembers) {
            MemberPickerScreen(groupName: groupName, groupId: createdGroupId ?? "") {
                // Pop entire creation stack and navigate to the new group
                path = NavigationPath()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    path.append(createdGroupId ?? "")
                }
            }
        }
        .onAppear { nameFieldFocused = true }
    }

    private func createGroup() async {
        error = nil
        isCreating = true
        defer { isCreating = false }

        do {
            let groupId = try await groupStore.createGroup(name: groupName.trimmingCharacters(in: .whitespaces))
            createdGroupId = groupId
            showingAddMembers = true
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = "Failed to create group"
        }
    }
}

#Preview {
    @Previewable @State var path = NavigationPath()
    NavigationStack(path: $path) {
        GroupNameScreen(path: $path)
            .environment(GroupStore())
    }
}
