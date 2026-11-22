import SwiftData
import Testing
@testable import Model

/// Enforces the CloudKit-compatibility rules from docs/ARCHITECTURE.md on the real schema.
struct ModelSchemaTests {
    let schema = Schema(ModelModule.models)

    @Test func hasAllSevenEntities() {
        let names = Set(schema.entities.map(\.name))
        #expect(names == ["ExperienceCollection", "Item", "Entry", "Photo", "Trip", "Tag", "Person"])
    }

    @Test func noUniqueAttributes() {
        for entity in schema.entities {
            for attribute in entity.attributes {
                #expect(!attribute.isUnique, "\(entity.name).\(attribute.name) is unique")
            }
        }
    }

    @Test func everyRelationshipIsOptional() {
        for entity in schema.entities {
            for relationship in entity.relationships {
                #expect(relationship.isOptional, "\(entity.name).\(relationship.name) is not optional")
            }
        }
    }

    @Test func everyRelationshipHasAnInverse() {
        for entity in schema.entities {
            for relationship in entity.relationships {
                #expect(relationship.inverseKeyPath != nil, "\(entity.name).\(relationship.name) has no inverse")
            }
        }
    }

    @Test func photoDataUsesExternalStorage() throws {
        let photo = try #require(schema.entities.first { $0.name == "Photo" })
        for name in ["imageData", "thumbnailData"] {
            let attribute = try #require(photo.attributes.first { $0.name == name })
            #expect(attribute.options.contains(.externalStorage), "Photo.\(name) is not external storage")
        }
    }

    /// Attributes are either optional or have a default: every model must be constructible with no arguments.
    @Test func everyModelHasDefaults() {
        let collection = ExperienceCollection()
        #expect(collection.kind == .custom)
        #expect(collection.ratingMode == .stars)
        #expect(collection.defaultView == .list)
        #expect(collection.itemSource == .manual)
        #expect(Item().externalRef == nil)
        #expect(Entry().notes.isEmpty)
        #expect(Photo().imageData == nil)
        #expect(Trip().entries?.isEmpty == true)
        #expect(ModelTag().name.isEmpty)
        #expect(Person().name.isEmpty)
    }
}
