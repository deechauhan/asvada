import Foundation
import Model
import SwiftData
import Testing
@testable import Storage

@MainActor
struct DeleteEntryTests {
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try ArtifactsStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
    }

    private func cafe(_ name: String) throws -> Item {
        let cafes = try #require(try repository.collections().first { $0.kind == .cafes })
        return try repository.addManualItem(ManualItemDraft(name: name), in: cafes)
    }

    @Test func deletingAnEntryTakesItsPhotosButKeepsTheItemAndItsRank() throws {
        let prufrock = try cafe("Prufrock")
        try repository.savour(prufrock, Savouring(note: "first", rankPosition: 0))
        let shot = try PhotoProcessor.process(TestImage.make(width: 800, height: 600))
        let second = try repository.savour(prufrock, Savouring(note: "second", photos: [shot]))
        let rank = prufrock.rankScore

        let deleted = try repository.deleteEntry(second)

        #expect(deleted.itemName == "Prufrock")
        #expect(repository.entry(id: deleted.id) == nil)
        #expect(prufrock.entries?.map(\.notes) == ["first"])
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Photo>()) == 0)
        #expect(prufrock.rankScore == rank)
    }

    @Test func undoPutsTheEntryBackExactlyAsItWas() throws {
        let prufrock = try cafe("Prufrock")
        let lastYear = Date(timeIntervalSince1970: 1_760_000_000)
        let shot = try PhotoProcessor.process(TestImage.make(width: 800, height: 600))
        let entry = try repository.savour(
            prufrock,
            Savouring(date: lastYear, rating: 4, note: "flat white", people: ["Ana", "Ben"], tags: ["rainy"], photos: [shot]),
        )
        let photoID = try #require(entry.photos?.first?.id)
        let before = EntryDetails(entry)

        let deleted = try repository.deleteEntry(entry)
        let restored = try #require(try repository.restore(deleted))

        #expect(restored.id == deleted.id)
        #expect(restored.item?.id == prufrock.id)
        #expect(restored.rating == 4)
        #expect(EntryDetails(restored) == before)
        let photos = repository.photos(of: restored)
        #expect(photos.map(\.id) == [photoID])
        #expect(photos.first?.imageData == shot.imageData)
        #expect(photos.first?.thumbnailData == shot.thumbnailData)
        #expect(repository.entry(id: deleted.id) != nil)
    }

    @Test func undoReusesThePeopleAndTagsAlreadyThere() throws {
        let entry = try repository.savour(cafe("Prufrock"), Savouring(people: ["Ana"], tags: ["rainy"]))
        try repository.savour(cafe("Monmouth"), Savouring(people: ["Ana"], tags: ["rainy"]))

        try repository.restore(repository.deleteEntry(entry))

        #expect(try container.mainContext.fetchCount(FetchDescriptor<Model.Person>()) == 1)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Model.Tag>()) == 1)
        #expect(repository.peopleNames() == ["Ana"])
    }

    @Test func undoFindsNothingToGoBackToOnceTheItemIsGone() throws {
        let prufrock = try cafe("Prufrock")
        let deleted = try repository.deleteEntry(repository.savour(prufrock, Savouring()))
        repository.delete(prufrock)
        try repository.save()

        #expect(try repository.restore(deleted) == nil)
    }
}
