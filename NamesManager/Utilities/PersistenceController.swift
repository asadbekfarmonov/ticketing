import Foundation
import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    private init(inMemory: Bool = false) {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "NamesManager", managedObjectModel: model)

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unresolved error \(error)")
            }
            description.shouldInferMappingModelAutomatically = true
            description.shouldMigrateStoreAutomatically = true
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    static func preview() -> PersistenceController {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        for index in 0..<10 {
            let name = NameEntity(context: context)
            name.id = UUID()
            name.firstName = "First \(index)"
            name.lastName = "Last \(index)"
            name.tags = ["VIP", "Sample"]
            name.createdAt = Date()
            name.updatedAt = Date()
            name.fullNameNormalized = NormalizationUtilities.normalize(fullName: name.displayFullName)
        }
        try? context.save()
        return controller
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "NameEntity"
        entity.managedObjectClassName = NSStringFromClass(NameEntity.self)

        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = false

        let firstNameAttribute = NSAttributeDescription()
        firstNameAttribute.name = "firstName"
        firstNameAttribute.attributeType = .stringAttributeType
        firstNameAttribute.isOptional = true

        let lastNameAttribute = NSAttributeDescription()
        lastNameAttribute.name = "lastName"
        lastNameAttribute.attributeType = .stringAttributeType
        lastNameAttribute.isOptional = true

        let fullNameAttribute = NSAttributeDescription()
        fullNameAttribute.name = "fullNameNormalized"
        fullNameAttribute.attributeType = .stringAttributeType
        fullNameAttribute.isOptional = false

        let tagsAttribute = NSAttributeDescription()
        tagsAttribute.name = "tags"
        tagsAttribute.attributeType = .transformableAttributeType
        tagsAttribute.attributeValueClassName = NSStringFromClass(NSArray.self)
        tagsAttribute.valueTransformerName = NSValueTransformerName.secureUnarchiveFromDataTransformerName
        tagsAttribute.isOptional = true

        let createdAtAttribute = NSAttributeDescription()
        createdAtAttribute.name = "createdAt"
        createdAtAttribute.attributeType = .dateAttributeType
        createdAtAttribute.isOptional = false

        let updatedAtAttribute = NSAttributeDescription()
        updatedAtAttribute.name = "updatedAt"
        updatedAtAttribute.attributeType = .dateAttributeType
        updatedAtAttribute.isOptional = false

        entity.properties = [
            idAttribute,
            firstNameAttribute,
            lastNameAttribute,
            fullNameAttribute,
            tagsAttribute,
            createdAtAttribute,
            updatedAtAttribute
        ]

        let identifier = NSFetchIndexDescription(name: "fullName_index", elements: [NSFetchIndexElementDescription(property: fullNameAttribute, collationType: .binary)])
        entity.indexes = [identifier]

        model.entities = [entity]
        return model
    }
}
