import SwiftUI

struct NameEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String
    @State private var lastName: String
    @State private var tagsText: String
    let onSave: (NameRecord) -> Void
    var record: NameRecord?

    init(record: NameRecord? = nil, onSave: @escaping (NameRecord) -> Void) {
        self.record = record
        _firstName = State(initialValue: record?.firstName ?? "")
        _lastName = State(initialValue: record?.lastName ?? "")
        _tagsText = State(initialValue: record?.tags.joined(separator: ", ") ?? "")
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                }

                Section("Tags") {
                    TextField("Comma separated tags", text: $tagsText)
                }
            }
            .navigationTitle(record == nil ? "New Name" : "Edit Name")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = record ?? NameRecord()
                        updated.firstName = firstName.isEmpty ? nil : firstName
                        updated.lastName = lastName.isEmpty ? nil : lastName
                        let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        updated.tags = tags
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
