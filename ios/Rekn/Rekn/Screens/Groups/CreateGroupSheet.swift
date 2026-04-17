import SwiftUI

struct CreateGroupSheet: View {
    let onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var model = CreateGroupModel()
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            CreateGroupDetailsStep(model: model, path: $path)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .navigationDestination(for: CreateGroupStep.self) { step in
                    switch step {
                    case .addMembers:
                        CreateGroupMembersStep(model: model) { groupId in
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onComplete(groupId)
                            }
                        }
                    }
                }
        }
        .interactiveDismissDisabled(model.isCreating || model.isSubmitting)
    }
}
