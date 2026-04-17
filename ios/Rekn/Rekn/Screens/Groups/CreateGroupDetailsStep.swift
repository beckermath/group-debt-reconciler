import SwiftUI

struct CreateGroupDetailsStep: View {
    @Bindable var model: CreateGroupModel
    @Binding var path: NavigationPath
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Heading
                    VStack(spacing: 8) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.4))

                        Text("What's this group for?")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Give it a name you'll remember")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    // Name field
                    VStack(spacing: 8) {
                        TextField("Trip to Berlin, Rent, Dinner...", text: $model.groupName)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .focused($nameFieldFocused)
                            .submitLabel(.done)
                            .onSubmit { createAndProceed() }

                        Rectangle()
                            .fill(nameFieldFocused ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(height: nameFieldFocused ? 1.5 : 1)
                            .animation(.easeOut(duration: 0.2), value: nameFieldFocused)
                    }
                    .padding(.horizontal, 32)

                    if let error = model.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.balanceNegative)
                    }
                }
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)

            // Next button
            VStack(spacing: 0) {
                Divider()
                Button {
                    createAndProceed()
                } label: {
                    Text("Next")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.isNameValid || model.isCreating)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .background(.background)
        }
        .navigationTitle("New Group")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { nameFieldFocused = true }
    }

    private func createAndProceed() {
        guard model.isNameValid else { return }
        path.append(CreateGroupStep.addMembers)
    }
}
