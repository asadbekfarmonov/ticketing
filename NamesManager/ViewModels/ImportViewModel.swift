import Foundation
import SwiftUI

@MainActor
final class ImportViewModel: ObservableObject {
    enum Step: Equatable {
        case idle
        case selectingSheet(ImportFile)
        case selectingColumns(ImportSelection)
        case preview(ImportSelection, [ImportPreviewItem])
        case completed
    }

    @Published var step: Step = .idle
    @Published var selectedTags: [String] = []
    @Published var error: LocalizedError?
    @Published var isImporting: Bool = false

    private let importer = NameImporter()

    func reset() {
        step = .idle
        selectedTags = []
        error = nil
    }

    func handlePickedFile(url: URL) {
        Task {
            await loadFile(url: url)
        }
    }

    private func loadFile(url: URL) async {
        isImporting = true
        defer { isImporting = false }
        do {
            let file = try await importer.loadFile(at: url)
            if file.sheets.count == 1, let sheet = file.sheets.first {
                await MainActor.run {
                    step = .selectingColumns(ImportSelection(sheet: sheet, firstNameColumn: nil, lastNameColumn: nil, fullNameColumn: nil))
                }
            } else {
                await MainActor.run {
                    step = .selectingSheet(file)
                }
            }
        } catch {
            await MainActor.run {
                self.error = error as? LocalizedError
            }
        }
    }

    func selectSheet(_ sheet: ImportSheet) {
        let selection = ImportSelection(sheet: sheet, firstNameColumn: nil, lastNameColumn: nil, fullNameColumn: nil)
        step = .selectingColumns(selection)
    }

    func updateSelection(_ selection: ImportSelection) {
        let preview = importer.makePreview(for: selection)
        step = .preview(selection, preview)
    }

    func confirmImport(into store: NamesStore) async {
        guard case let .preview(selection, _) = step else { return }
        do {
            let records = try importer.materialize(selection: selection, tags: selectedTags)
            try await store.importRecords(records)
            step = .completed
        } catch {
            self.error = error as? LocalizedError
        }
    }
}
