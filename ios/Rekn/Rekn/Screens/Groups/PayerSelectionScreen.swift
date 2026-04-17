import SwiftUI

struct PayerSelectionScreen: View {
    var model: AddExpenseModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(model.memberList) { member in
            Button {
                model.paidByMemberId = member.id
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    MemberAvatar(name: member.name, imageUrl: member.imageUrl, size: 36)
                    Text(model.displayName(for: member))
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    if model.paidByMemberId == member.id {
                        Image(systemName: "checkmark")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(WarmGradientBackground().ignoresSafeArea())
        .navigationTitle("Who paid?")
        .navigationBarTitleDisplayMode(.inline)
    }
}
