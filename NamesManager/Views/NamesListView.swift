import SwiftUI
import UIKit

struct NamesListView: View {
    @EnvironmentObject private var namesStore: NamesStore
    @State private var isPresentingEditor = false
    @State private var editingRecord: NameRecord?
    @State private var exportURL: URL?
    private let exporter = NameExporter()

    var body: some View {
        VStack {
            searchBar
            letterFilter
            list
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                sortMenu
                transliterationMenu
                quickFixMenu
                exportMenu
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            NameEditorView(record: editingRecord) { record in
                Task {
                    if editingRecord == nil {
                        try? await namesStore.add(record: record)
                    } else {
                        try? await namesStore.update(record: record)
                    }
                }
            }
        }
        .sheet(isPresented: Binding(get: { exportURL != nil }, set: { newValue in
            if !newValue { exportURL = nil }
        })) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .overlay(alignment: .bottom) {
            if let deleted = namesStore.recentlyDeleted {
                UndoBanner(name: deleted.fullName) {
                    Task { await namesStore.undoDelete() }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding()
            }
        }
        .animation(.easeInOut, value: namesStore.recentlyDeleted)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Search", text: $namesStore.searchQuery)
                .textFieldStyle(.plain)
            if !namesStore.searchQuery.isEmpty {
                Button {
                    namesStore.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var letterFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button(action: { namesStore.selectedFirstLetter = nil }) {
                    Text("All")
                        .padding(8)
                        .background(namesStore.selectedFirstLetter == nil ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                }
                ForEach(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ"), id: \.self) { character in
                    Button(action: { namesStore.selectedFirstLetter = character }) {
                        Text(String(character))
                            .padding(8)
                            .background(namesStore.selectedFirstLetter == character ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var list: some View {
        List {
            ForEach(namesStore.filteredNames) { record in
                Button {
                    editingRecord = record
                    isPresentingEditor = true
                } label: {
                    VStack(alignment: .leading) {
                        Text(displayName(for: record))
                            .font(.headline)
                        if !record.tags.isEmpty {
                            Text(record.tags.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { try? await namesStore.delete(record: record) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay(Group {
            if namesStore.filteredNames.isEmpty {
                ContentUnavailableView("No names", systemImage: "person.fill.questionmark", description: Text("Import or add new names to get started."))
            }
        })
        .safeAreaInset(edge: .bottom) {
            Button {
                editingRecord = nil
                isPresentingEditor = true
            } label: {
                Label("Add name", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort order", selection: $namesStore.sortOrder) {
                ForEach(NamesSortOrder.allCases) { order in
                    Label(order.title, systemImage: order.iconName).tag(order)
                }
            }
        } label: {
            Image(systemName: namesStore.sortOrder.iconName)
        }
    }

    private var transliterationMenu: some View {
        Menu {
            Picker("Transliteration", selection: $namesStore.transliterationMode) {
                ForEach(TransliterationMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        } label: {
            Image(systemName: "character.bubble")
        }
    }

    private var quickFixMenu: some View {
        Menu("Quick Fixes", systemImage: "wand.and.stars") {
            ForEach(QuickFix.allCases) { fix in
                Button(fix.title) {
                    Task { await namesStore.applyQuickFix(fix) }
                }
            }
        }
    }

    private var exportMenu: some View {
        Menu("Export", systemImage: "square.and.arrow.up") {
            Button("Export CSV") { export(format: .csv) }
            Button("Export XLSX") { export(format: .xlsx) }
        }
    }

    private func export(format: ExportFormat) {
        let records = namesStore.filteredNames
        Task {
            let url: URL?
            switch format {
            case .csv:
                if let data = try? exporter.exportCSV(records: records) {
                    url = writeTemporary(data: data, extension: "csv")
                } else {
                    url = nil
                }
            case .xlsx:
                let tempURL = temporaryFileURL(extension: "xlsx")
                do {
                    try exporter.exportXLSX(records: records, to: tempURL)
                    url = tempURL
                } catch {
                    url = nil
                }
            }
            await MainActor.run {
                exportURL = url
            }
        }
    }

    private func writeTemporary(data: Data, extension ext: String) -> URL? {
        let url = temporaryFileURL(extension: ext)
        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            return nil
        }
    }

    private func temporaryFileURL(extension ext: String) -> URL {
        let filename = "Names-\(UUID().uuidString).\(ext)"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    private func displayName(for record: NameRecord) -> String {
        let base = record.fullName
        return NormalizationUtilities.transliterate(base, mode: namesStore.transliterationMode)
    }
}

private enum ExportFormat {
    case csv
    case xlsx
}

private struct UndoBanner: View {
    let name: String
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text("Deleted \(name)")
            Spacer()
            Button("Undo", action: onUndo)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .shadow(radius: 4)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
