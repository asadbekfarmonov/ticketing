import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @EnvironmentObject private var viewModel: ImportViewModel
    @EnvironmentObject private var namesStore: NamesStore
    @State private var isImporterPresented = false
    @State private var selection: ImportSelection?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Import names from CSV or Excel")
                    .font(.headline)
                Text("Use Files, iCloud Drive or other providers to load your spreadsheet. Select the sheet and columns containing names before importing.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)

            Button {
                isImporterPresented = true
            } label: {
                Label("Pick a file", systemImage: "doc")
                    .font(.title3)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isImporting)

            switch viewModel.step {
            case .idle:
                Spacer()
            case let .selectingSheet(file):
                sheetSelectionView(file: file)
            case let .selectingColumns(currentSelection):
                columnSelectionView(selection: currentSelection)
            case let .preview(selection, previewItems):
                previewView(selection: selection, items: previewItems)
            case .completed:
                completionView
            }

            Spacer()
        }
        .padding()
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.commaSeparatedText, .spreadsheet, .data], allowsMultipleSelection: false) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                viewModel.handlePickedFile(url: url)
            case let .failure(error):
                print("Failed to import file: \(error)")
            }
        }
        .onChange(of: viewModel.step) { _, newValue in
            switch newValue {
            case let .selectingColumns(newSelection):
                selection = newSelection
            case let .preview(newSelection, _):
                selection = newSelection
            default:
                break
            }
        }
        .alert("Import Error", isPresented: Binding(get: { viewModel.error != nil }, set: { _ in viewModel.error = nil })) {
            Button("OK", role: .cancel) { }
        } message: {
            if let message = viewModel.error?.errorDescription {
                Text(message)
            } else {
                Text("Something went wrong while importing the file.")
            }
        }
    }

    @ViewBuilder
    private func sheetSelectionView(file: ImportFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a sheet")
                .font(.title3)
            List(file.sheets) { sheet in
                Button(sheet.name) {
                    viewModel.selectSheet(sheet)
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func columnSelectionView(selection: ImportSelection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Map the columns")
                .font(.title3)
            if selection.sheet.columns.isEmpty {
                Text("No columns detected in this sheet.")
                    .foregroundColor(.secondary)
            } else {
                ColumnPicker(selection: selection, onChange: { updated in
                    viewModel.updateSelection(updated)
                })
            }
        }
    }

    @ViewBuilder
    private func previewView(selection: ImportSelection, items: [ImportPreviewItem]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ColumnPicker(selection: selection, onChange: { updated in
                viewModel.updateSelection(updated)
            })

            Text("Tag imported names (optional, comma separated)")
                .font(.subheadline)
            TextField("Tags", text: Binding(
                get: { viewModel.selectedTags.joined(separator: ", ") },
                set: { newValue in
                    let trimmed = newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    viewModel.selectedTags = trimmed
                }
            ))
            .textFieldStyle(.roundedBorder)

            Text("Preview")
                .font(.title3)
            List(items) { item in
                VStack(alignment: .leading) {
                    Text(item.fullName)
                        .font(.headline)
                    HStack {
                        if let first = item.firstName {
                            Label(first, systemImage: "person")
                                .labelStyle(.titleAndIcon)
                        }
                        if let last = item.lastName {
                            Label(last, systemImage: "person.fill")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .frame(maxHeight: 220)

            Button {
                Task {
                    await viewModel.confirmImport(into: namesStore)
                }
            } label: {
                Label("Import \(items.count) rows", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var completionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text("Import complete!")
                .font(.title2)
            Button("Import another file") {
                viewModel.reset()
            }
        }
    }
}

private struct ColumnPicker: View {
    let selection: ImportSelection
    @State private var workingSelection: ImportSelection
    var onChange: (ImportSelection) -> Void

    init(selection: ImportSelection, onChange: @escaping (ImportSelection) -> Void) {
        self.selection = selection
        _workingSelection = State(initialValue: selection)
        self.onChange = onChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            columnMenu(title: "First name", selection: $workingSelection.firstNameColumn)
            columnMenu(title: "Last name", selection: $workingSelection.lastNameColumn)
            columnMenu(title: "Full name", selection: $workingSelection.fullNameColumn)
        }
        .onChange(of: workingSelection) { _, newValue in
            onChange(newValue)
        }
        .onChange(of: selection) { _, newValue in
            workingSelection = newValue
        }
    }

    private func columnMenu(title: String, selection: Binding<ImportColumn?>) -> some View {
        Menu {
            Button("None") {
                selection.wrappedValue = nil
            }
            ForEach(workingSelection.sheet.columns) { column in
                Button(column.title) {
                    selection.wrappedValue = column
                }
            }
        } label: {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(selection.wrappedValue?.title ?? "None")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3)))
        }
    }
}
