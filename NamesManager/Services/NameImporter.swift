import Foundation
import CoreXLSX
import SwiftCSV
import UniformTypeIdentifiers

struct ImportFile: Identifiable {
    enum FileKind {
        case csv
        case xlsx
    }

    let id = UUID()
    let url: URL
    let kind: FileKind
    let sheets: [ImportSheet]
}

struct ImportSheet: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let columns: [ImportColumn]
    let rows: [[String]]
}

struct ImportColumn: Identifiable, Hashable {
    let id = UUID()
    let index: Int
    let title: String
    let sampleValues: [String]
}

struct ImportSelection: Equatable {
    var sheet: ImportSheet
    var firstNameColumn: ImportColumn?
    var lastNameColumn: ImportColumn?
    var fullNameColumn: ImportColumn?

    var selectedColumns: [ImportColumn] {
        [firstNameColumn, lastNameColumn, fullNameColumn].compactMap { $0 }
    }
}

struct ImportPreviewItem: Identifiable, Equatable {
    let id = UUID()
    let firstName: String?
    let lastName: String?
    let fullName: String
}

enum NameImporterError: Error {
    case unsupportedFileType
    case invalidSelection
}

extension NameImporterError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "The selected file is not a supported CSV or Excel document."
        case .invalidSelection:
            return "Select at least one column that contains name data before importing."
        }
    }
}

struct NameImporter {
    func loadFile(at url: URL) async throws -> ImportFile {
        if url.conforms(to: .commaSeparatedText) || url.pathExtension.lowercased() == "csv" {
            return try await loadCSV(at: url)
        }
        if url.conforms(to: .spreadsheet) || url.pathExtension.lowercased() == "xlsx" {
            return try await loadXLSX(at: url)
        }
        throw NameImporterError.unsupportedFileType
    }

    private func loadCSV(at url: URL) async throws -> ImportFile {
        let csv = try CSV<Named>(url: url, delimiter: ",", encoding: .utf8)
        let headers = csv.header
        let rows = csv.namedRows
        let orderedRows: [[String]] = rows.map { row in
            headers.map { row[$0] ?? "" }
        }
        let columns: [ImportColumn] = headers.enumerated().map { index, title in
            let sample = orderedRows.prefix(5).map { $0[index] }
            return ImportColumn(index: index, title: title, sampleValues: sample)
        }
        let sheet = ImportSheet(name: url.lastPathComponent, columns: columns, rows: orderedRows)
        return ImportFile(url: url, kind: .csv, sheets: [sheet])
    }

    private func loadXLSX(at url: URL) async throws -> ImportFile {
        let file = try XLSXFile(filepath: url.path)
        let sharedStrings = try file.parseSharedStrings()
        let styles = try file.parseStyles()
        let paths = try file.parseWorksheetPaths()

        let sheets: [ImportSheet] = try paths.compactMap { path in
            let worksheet = try file.parseWorksheet(at: path)
            let name = path.name
            let rows = worksheet.data?.rows ?? []
            var header: [String] = []
            var body: [[String]] = []
            for (rowIndex, row) in rows.enumerated() {
                let values = row.cells.map { cell -> String in
                    cell.stringValue(sharedStrings, styles: styles) ?? ""
                }
                if rowIndex == 0 {
                    header = values
                } else {
                    body.append(values)
                }
            }
            guard !header.isEmpty else { return nil }
            let normalizedBody = body.map { row -> [String] in
                var buffer = row
                if buffer.count < header.count {
                    buffer += Array(repeating: "", count: header.count - buffer.count)
                }
                return Array(buffer.prefix(header.count))
            }
            let columns = header.enumerated().map { index, title in
                let sample = normalizedBody.prefix(5).map { row -> String in
                    guard index < row.count else { return "" }
                    return row[index]
                }
                return ImportColumn(index: index, title: title.isEmpty ? "Column \(index + 1)" : title, sampleValues: sample)
            }
            return ImportSheet(name: name, columns: columns, rows: normalizedBody)
        }
        return ImportFile(url: url, kind: .xlsx, sheets: sheets)
    }

    func makePreview(for selection: ImportSelection) -> [ImportPreviewItem] {
        selection.sheet.rows.prefix(20).map { row in
            let first: String? = selection.firstNameColumn.map { column in
                guard column.index < row.count else { return nil }
                return row[column.index]
            }
            let last: String? = selection.lastNameColumn.map { column in
                guard column.index < row.count else { return nil }
                return row[column.index]
            }
            let full: String
            if let column = selection.fullNameColumn, column.index < row.count {
                full = row[column.index]
            } else {
                let components = [first, last].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                full = components.joined(separator: " ")
            }
            return ImportPreviewItem(firstName: first, lastName: last, fullName: full)
        }
    }

    func materialize(selection: ImportSelection, tags: [String]) throws -> [NameRecord] {
        guard selection.firstNameColumn != nil || selection.lastNameColumn != nil || selection.fullNameColumn != nil else {
            throw NameImporterError.invalidSelection
        }
        return selection.sheet.rows.map { row in
            var first: String?
            var last: String?
            if let column = selection.firstNameColumn, column.index < row.count {
                first = row[column.index]
            }
            if let column = selection.lastNameColumn, column.index < row.count {
                last = row[column.index]
            }
            var record = NameRecord(firstName: first, lastName: last, tags: tags)
            if let column = selection.fullNameColumn, column.index < row.count {
                let full = row[column.index]
                if first == nil || first?.isEmpty == true || last == nil || last?.isEmpty == true {
                    let components = full.split(separator: " ")
                    if first == nil && !components.isEmpty {
                        first = String(components.first!)
                    }
                    if last == nil && components.count > 1 {
                        last = components.dropFirst().joined(separator: " ")
                    }
                    record.firstName = first
                    record.lastName = last
                }
            }
            return record
        }
    }
}

private extension URL {
    func conforms(to type: UTType) -> Bool {
        guard let fileType = UTType(filenameExtension: pathExtension) else { return false }
        return fileType.conforms(to: type)
    }
}
