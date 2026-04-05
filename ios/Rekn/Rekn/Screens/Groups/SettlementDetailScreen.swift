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

                // Placeholder for detailed table
                SectionCard(header: "Expenses Included") {
                    VStack(spacing: 0) {
                        ForEach(0..<settlement.expenseCount, id: \.self) { i in
                            HStack {
                                Text("Expense \(i + 1)")
                                    .font(.subheadline)
                                Spacer()
                                Text("$--")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            if i < settlement.expenseCount - 1 {
                                Divider().padding(.leading)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle(settlement.settledAt.formatted(.dateTime.month(.abbreviated).day().year()))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettlementDetailScreen(settlement: Settlement.previews[0])
    }
}
