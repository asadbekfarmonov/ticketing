import Foundation
import CoreData

@objc(NameEntity)
final class NameEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var firstName: String?
    @NSManaged var lastName: String?
    @NSManaged var fullNameNormalized: String
    @NSManaged var tags: [String]?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
}

extension NameEntity {
    var displayFullName: String {
        let components = [firstName, lastName].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if components.isEmpty {
            return "Unnamed"
        }
        return components.joined(separator: " ")
    }

    func updateFullNameCache() {
        fullNameNormalized = NormalizationUtilities.normalize(fullName: displayFullName)
    }

    func apply(record: NameRecord) {
        firstName = record.firstName
        lastName = record.lastName
        tags = record.tags
        updatedAt = Date()
        updateFullNameCache()
    }
}

struct NameRecord: Identifiable, Hashable {
    var id: UUID
    var firstName: String?
    var lastName: String?
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date

    var fullName: String {
        let components = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }

    var normalized: String {
        NormalizationUtilities.normalize(fullName: fullName)
    }

    init(entity: NameEntity) {
        id = entity.id
        firstName = entity.firstName
        lastName = entity.lastName
        tags = entity.tags ?? []
        createdAt = entity.createdAt
        updatedAt = entity.updatedAt
    }

    init(id: UUID = UUID(), firstName: String? = nil, lastName: String? = nil, tags: [String] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Array where Element == NameRecord {
    func sorted(by sortOrder: NamesSortOrder) -> [NameRecord] {
        switch sortOrder {
        case .ascending:
            return self.sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
        case .descending:
            return self.sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedDescending }
        }
    }
}
