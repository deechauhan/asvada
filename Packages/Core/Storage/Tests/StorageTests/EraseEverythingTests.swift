import Foundation
import Model
import SwiftData
import Testing
@testable import Storage

@MainActor
struct EraseEverythingTests {
    private func filledStore() throws -> (ModelContainer, Repository) {
        let container = try AsvadaStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        try PreviewData.fillBuiltIns(repository)
        let custom = ExperienceCollection(name: "Bakeries", kind: .custom)
        repository.context.insert(custom)
        let item = repository.upsertItem(named: "Gail's", externalRef: nil, in: custom)
        let entry = repository.addEntry(to: item, notes: "croissant")
        let tag = Model.Tag(name: "morning")
        let person = Person(name: "Ana")
        let trip = Trip(name: "Weekend")
        let photo = Photo(imageData: Data([1]), thumbnailData: Data([2]))
        for model in [tag, person, trip, photo] as [any PersistentModel] {
            repository.context.insert(model)
        }
        entry.tags = [tag]
        entry.people = [person]
        entry.trip = trip
        photo.entry = entry
        try repository.save()
        return (container, repository)
    }

    @Test func everythingGoesAndTheBuiltInsComeBackEmpty() throws {
        let (container, repository) = try filledStore()
        let context = container.mainContext
        let before = try BackupBundle.export(from: context)

        let deleted = try repository.eraseEverything()
        #expect(deleted.entries > 0)
        #expect(deleted.photos == 1)
        #expect(deleted.tags == 1)
        #expect(deleted.collections > BuiltInCollections.all.count)

        #expect(try context.fetchCount(FetchDescriptor<Entry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Photo>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Trip>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Model.Tag>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Person>()) == 0)
        // The app starts again from its built-in collections, all empty, and no custom ones.
        let collections = try repository.collections(includeHidden: true)
        #expect(collections.count == BuiltInCollections.all.count)
        #expect(collections.allSatisfy { ($0.items ?? []).isEmpty })
        #expect(!collections.contains { $0.name == "Bakeries" })
        #expect(try BackupBundle.export(from: context)[BackupBundle.dataPath] != before[BackupBundle.dataPath])
    }

    @Test func erasingAnEmptyStoreSaysNothingWasDeletedAndIsSafe() throws {
        let container = try AsvadaStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        let deleted = try repository.eraseEverything()
        #expect(deleted == BackupBundle.Counts())
        #expect(try repository.collections(includeHidden: true).count == BuiltInCollections.all.count)
    }
}
