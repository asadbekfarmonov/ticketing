import Foundation
import CoreXLSX

struct NameExporter {
    func exportCSV(records: [NameRecord]) throws -> Data {
        var lines: [String] = []
        let header = ["First Name", "Last Name", "Full Name", "Tags", "Created At", "Updated At"]
        lines.append(header.joined(separator: ","))
        let formatter = ISO8601DateFormatter()
        for record in records {
            let fields: [String] = [
                record.firstName ?? "",
                record.lastName ?? "",
                record.fullName,
                record.tags.joined(separator: ";"),
                formatter.string(from: record.createdAt),
                formatter.string(from: record.updatedAt)
            ].map { escapeCSVField($0) }
            lines.append(fields.joined(separator: ","))
        }
        let csvString = lines.joined(separator: "\n")
        guard let data = csvString.data(using: .utf8) else {
            throw NSError(domain: "NamesManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode CSV"])
        }
        return data
    }

    func exportXLSX(records: [NameRecord], to url: URL) throws {
        let formatter = ISO8601DateFormatter()
        let headers = ["First Name", "Last Name", "Full Name", "Tags", "Created At", "Updated At"]
        var rows: [Worksheet.Row] = []
        let headerCells: [Cell] = headers.enumerated().map { columnIndex, header in
            let reference = "\(columnLetter(for: columnIndex))1"
            return Cell(reference: reference, type: .inlineString, inlineString: InlineString(text: header))
        }
        rows.append(Worksheet.Row(cells: headerCells))

        for (index, record) in records.enumerated() {
            var cells: [Cell] = []
            let rowIndex = index + 2
            let values = [
                record.firstName ?? "",
                record.lastName ?? "",
                record.fullName,
                record.tags.joined(separator: ";"),
                formatter.string(from: record.createdAt),
                formatter.string(from: record.updatedAt)
            ]
            for (columnIndex, value) in values.enumerated() {
                let reference = "\(columnLetter(for: columnIndex))\(rowIndex)"
                let cell = Cell(reference: reference, type: .inlineString, inlineString: InlineString(text: value))
                cells.append(cell)
            }
            rows.append(Worksheet.Row(cells: cells))
        }

        let sheetData = Worksheet.Data(rows: rows)
        let worksheet = Worksheet(data: sheetData)
        let workbook = Workbook(workSheets: [WorksheetFile(name: "Names", worksheet: worksheet)])
        try XLSXFile.create(workbook: workbook, sharedStrings: SharedStrings(), to: url.path)
    }

    private func escapeCSVField(_ value: String) -> String {
        if value.contains(",") || value.contains("\n") || value.contains("\"") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    private func columnLetter(for index: Int) -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        var result = ""
        var value = index
        repeat {
            let remainder = value % 26
            let letter = letters[letters.index(letters.startIndex, offsetBy: remainder)]
            result = String(letter) + result
            value = (value / 26) - 1
        } while value >= 0
        return result
    }
}
