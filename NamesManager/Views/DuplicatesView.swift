import SwiftUI

struct DuplicatesView: View {
    @EnvironmentObject private var namesStore: NamesStore
    @State private var selectedCluster: DuplicateCluster?
    @State private var selectedRecord: NameRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if namesStore.duplicateClusters.isEmpty {
                ContentUnavailableView("No duplicates", systemImage: "checkmark.seal", description: Text("Tap Find duplicates to refresh."))
            } else {
                List(namesStore.duplicateClusters) { cluster in
                    Section(header: Text(clusterTitle(cluster))) {
                        ForEach(cluster.records) { record in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(record.fullName)
                                        .font(.headline)
                                    if !record.tags.isEmpty {
                                        Text(record.tags.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Button("Merge") {
                                    selectedCluster = cluster
                                    selectedRecord = record
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            Spacer()
            Button {
                namesStore.refreshFromStore()
            } label: {
                Label("Find duplicates", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .sheet(item: $selectedRecord) { record in
            if let cluster = selectedCluster {
                DuplicateMergeSheet(cluster: cluster, primaryRecord: record) { winner, mergedTags in
                    Task {
                        try? await namesStore.merge(cluster: cluster, keeping: winner, mergedTags: mergedTags)
                    }
                }
            }
        }
    }

    private func clusterTitle(_ cluster: DuplicateCluster) -> String {
        "\(cluster.records.count) matches • \(cluster.records.first?.fullName ?? "")"
    }
}

private struct DuplicateMergeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let cluster: DuplicateCluster
    @State private var winner: NameRecord
    @State private var tagsSelection: [String]
    let onMerge: (NameRecord, [String]) -> Void

    init(cluster: DuplicateCluster, primaryRecord: NameRecord, onMerge: @escaping (NameRecord, [String]) -> Void) {
        self.cluster = cluster
        _winner = State(initialValue: primaryRecord)
        let uniqueTags = Set(cluster.records.flatMap { $0.tags })
        _tagsSelection = State(initialValue: Array(uniqueTags).sorted())
        self.onMerge = onMerge
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Keep") {
                    Picker("Winner", selection: $winner) {
                        ForEach(cluster.records) { record in
                            Text(record.fullName).tag(record)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Tags") {
                    ForEach(cluster.records.flatMap { $0.tags }, id: \.self) { tag in
                        Toggle(tag, isOn: Binding(get: {
                            tagsSelection.contains(tag)
                        }, set: { isOn in
                            if isOn {
                                tagsSelection.append(tag)
                            } else {
                                tagsSelection.removeAll { $0 == tag }
                            }
                        }))
                    }
                }
            }
            .navigationTitle("Merge duplicates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Merge") {
                        onMerge(winner, Array(Set(tagsSelection)))
                        dismiss()
                    }
                }
            }
        }
    }
}
