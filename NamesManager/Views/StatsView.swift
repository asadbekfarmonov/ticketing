import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var namesStore: NamesStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StatCard(title: "Total names", value: namesStore.stats.total)
                StatCard(title: "Unique", value: namesStore.stats.unique)
                StatCard(title: "Duplicates", value: namesStore.stats.duplicates)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Tips")
                        .font(.title2)
                    TipRow(title: "Use the Import tab", description: "Bring in names from CSV or Excel, map the correct columns, and preview before committing.")
                    TipRow(title: "Merge duplicates", description: "Review duplicates and merge them to maintain a clean list.")
                    TipRow(title: "Export anytime", description: "Share your curated list as CSV or Excel from the Names tab.")
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(.thinMaterial))
            }
            .padding()
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(.thickMaterial))
    }
}

private struct TipRow: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(description)
                .foregroundColor(.secondary)
        }
    }
}
