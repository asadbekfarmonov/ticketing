import Foundation
import CoreData

@MainActor
final class NamesStore: ObservableObject {
    @Published private(set) var names: [NameRecord] = []
    @Published var searchQuery: String = "" { didSet { refreshVisibleNames() } }
    @Published var sortOrder: NamesSortOrder = .ascending { didSet { refreshVisibleNames() } }
    @Published var selectedFirstLetter: Character? { didSet { refreshVisibleNames() } }
    @Published var transliterationMode: TransliterationMode = .none
    @Published private(set) var filteredNames: [NameRecord] = []
    @Published private(set) var duplicateClusters: [DuplicateCluster] = []
    @Published private(set) var stats: NamesStatistics = .empty
    @Published var recentlyDeleted: NameRecord?

    let persistence: PersistenceController
    private let viewContext: NSManagedObjectContext
    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        self.viewContext = persistence.container.viewContext
        refreshFromStore()
    }

    func refreshFromStore() {
        let request: NSFetchRequest<NameEntity> = NameEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NameEntity.fullNameNormalized, ascending: true)]
        do {
            let entities = try viewContext.fetch(request)
            names = entities.map(NameRecord.init(entity:))
            recalculateDerivedValues()
        } catch {
            print("Failed to fetch names: \(error)")
        }
    }

    func refreshVisibleNames() {
        let base = applySearchAndFilters(to: names)
        filteredNames = base.sorted(by: sortOrder)
    }

    private func recalculateDerivedValues() {
        refreshVisibleNames()
        duplicateClusters = DuplicateCluster.build(from: names)
        let duplicateCount = duplicateClusters.reduce(0) { $0 + $1.duplicatesCount }
        let uniqueCount = max(names.count - duplicateCount, 0)
        stats = NamesStatistics(total: names.count, unique: uniqueCount, duplicates: duplicateCount)
    }

    private func applySearchAndFilters(to names: [NameRecord]) -> [NameRecord] {
        names.filter { record in
            var matches = true
            if !searchQuery.isEmpty {
                let normalizedQuery = NormalizationUtilities.normalize(fullName: searchQuery)
                matches = record.normalized.contains(normalizedQuery) || record.fullName.localizedCaseInsensitiveContains(searchQuery)
            }
            if let letter = selectedFirstLetter {
                let upperLetter = String(letter).uppercased().first
                matches = matches && record.fullName.uppercased().first == upperLetter
            }
            return matches
        }
    }

    func add(record: NameRecord) async throws {
        let entity = NameEntity(context: viewContext)
        entity.id = record.id
        entity.firstName = record.firstName
        entity.lastName = record.lastName
        entity.tags = record.tags
        entity.createdAt = record.createdAt
        entity.updatedAt = Date()
        entity.updateFullNameCache()
        try save()
    }

    func update(record: NameRecord) async throws {
        let request: NSFetchRequest<NameEntity> = NameEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
        request.fetchLimit = 1
        if let entity = try viewContext.fetch(request).first {
            entity.apply(record: record)
            try save()
        }
    }

    func delete(record: NameRecord) async throws {
        let request: NSFetchRequest<NameEntity> = NameEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
        request.fetchLimit = 1
        if let entity = try viewContext.fetch(request).first {
            recentlyDeleted = record
            viewContext.delete(entity)
            try save()
        }
    }

    func undoDelete() async {
        guard let record = recentlyDeleted else { return }
        let entity = NameEntity(context: viewContext)
        entity.id = record.id
        entity.firstName = record.firstName
        entity.lastName = record.lastName
        entity.tags = record.tags
        entity.createdAt = record.createdAt
        entity.updatedAt = Date()
        entity.updateFullNameCache()
        try? save()
        recentlyDeleted = nil
    }

    func merge(cluster: DuplicateCluster, keeping record: NameRecord, mergedTags: [String]) async throws {
        var surviving = record
        surviving.tags = mergedTags
        try await update(record: surviving)

        let duplicates = cluster.records.filter { $0.id != record.id }
        for duplicate in duplicates {
            try await delete(record: duplicate)
        }
        refreshFromStore()
    }

    func importRecords(_ records: [NameRecord]) async throws {
        for record in records {
            let request: NSFetchRequest<NameEntity> = NameEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
            request.fetchLimit = 1
            if let existing = try viewContext.fetch(request).first {
                existing.apply(record: record)
            } else {
                let entity = NameEntity(context: viewContext)
                entity.id = record.id
                entity.firstName = record.firstName
                entity.lastName = record.lastName
                entity.tags = record.tags
                entity.createdAt = record.createdAt
                entity.updatedAt = record.updatedAt
                entity.updateFullNameCache()
            }
        }
        try save()
    }

    func applyQuickFix(_ fix: QuickFix) async {
        let request: NSFetchRequest<NameEntity> = NameEntity.fetchRequest()
        do {
            let entities = try viewContext.fetch(request)
            entities.forEach { entity in
                if let first = entity.firstName {
                    entity.firstName = NormalizationUtilities.applyQuickFix(fix, to: first)
                }
                if let last = entity.lastName {
                    entity.lastName = NormalizationUtilities.applyQuickFix(fix, to: last)
                }
                entity.updateFullNameCache()
                entity.updatedAt = Date()
            }
            try save()
        } catch {
            print("Quick fix failed: \(error)")
        }
    }

    func exportRecords() -> [NameRecord] {
        filteredNames
    }

    private func save() throws {
        if viewContext.hasChanges {
            try viewContext.save()
            refreshFromStore()
        }
    }
}

struct NamesStatistics {
    var total: Int
    var unique: Int
    var duplicates: Int

    static let empty = NamesStatistics(total: 0, unique: 0, duplicates: 0)
}

struct DuplicateCluster: Identifiable, Hashable {
    let id: UUID
    var normalized: String
    var records: [NameRecord]

    var duplicatesCount: Int { max(records.count - 1, 0) }

    static func build(from records: [NameRecord]) -> [DuplicateCluster] {
        let grouped = Dictionary(grouping: records, by: { $0.normalized })
        return grouped.compactMap { normalized, records in
            guard records.count > 1 else { return nil }
            return DuplicateCluster(id: UUID(), normalized: normalized, records: records)
        }.sorted { $0.records.count > $1.records.count }
    }
}

extension NameEntity {
    @nonobjc class func fetchRequest() -> NSFetchRequest<NameEntity> {
        return NSFetchRequest<NameEntity>(entityName: "NameEntity")
    }
}
