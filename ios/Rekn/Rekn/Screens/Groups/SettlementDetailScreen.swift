import SwiftUI

struct SettlementDetailScreen: View {
    let settlement: Settlement

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary card
                VStack(spacing: 8) {
                    Text(formatCents(settlement.totalCents))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("\(settlement.expenseCount) expenses settled")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("by \(settlement.settledByName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)

                // Details card
                SectionCard(header: "Summary") {
                    VStack(spacing: 0) {
                        detailRow(label: "Date", value: settlement.settledAt.formatted(.dateTime.month(.abbreviated).day().year()))
                        Divider().padding(.horizontal, 12)
                        detailRow(label: "Settled by", value: settlement.settledByName)
                        Divider().padding(.horizontal, 12)
                        detailRow(label: "Expenses included", value: "\(settlement.expenseCount)")
                        Divider().padding(.horizontal, 12)
                        detailRow(label: "Total amount", value: formatCents(settlement.totalCents))
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle(settlement.settledAt.formatted(.dateTime.month(.abbreviated).day().year()))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

#Preview {
    NavigationStack {
        SettlementDetailScreen(settlement: Settlement.previews[0])
    }
}
