import Foundation
import Model
import SwiftData
import Testing
@testable import Storage

@MainActor
struct EditDeleteCollectionTests {
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try ArtifactsStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
    }

    private func makeConcerts() throws -> ExperienceCollection {
        var draft = CollectionDraft()
        draft.name = "Concerts"
        draft.icon = "music.note"
        return try repository.createCollection(from: draft)
    }

    @Test func editingUpdatesNameIconColourAndModes() throws {
        let concerts = try makeConcerts()
        var draft = CollectionDraft(editing: concerts)
        draft.name = "Gigs"
        draft.icon = "guitars.fill"
        draft.accentName = "film"
        draft.ratingMode = .ranked
        draft.defaultView = .grid
        draft.itemSource = .mapkit
        try repository.update(concerts, from: draft)
        #expect(concerts.name == "Gigs")
        #expect(concerts.icon == "guitars.fill")
        #expect(concerts.accentName == "film")
        #expect(concerts.ratingMode == .ranked)
        #expect(concerts.defaultView == .grid)
        #expect(concerts.itemSource == .mapkit)
    }

    @Test func editingBuiltInKeepsKindAndSource() throws {
        let films = try #require(try repository.collections().first { $0.kind == .films })
        var draft = CollectionDraft(editing: films)
        #expect(draft.isValid)
        draft.name = "Movies"
        draft.itemSource = .manual
        try repository.update(films, from: draft)
        #expect(films.name == "Movies")
        #expect(films.kind == .films)
        #expect(films.itemSource == .tmdb)
    }

    @Test func emptyNameIsRejectedOnEdit() throws {
        let concerts = try makeConcerts()
        var draft = CollectionDraft(editing: concerts)
        draft.name = " "
        #expect(throws: CollectionDraftError.invalid) {
            try repository.update(concerts, from: draft)
        }
        #expect(concerts.name == "Concerts")
    }

    @Test func deletionImpactCountsItemsAndEntries() throws {
        let concerts = try makeConcerts()
        let gig = repository.upsertItem(named: "Radiohead", externalRef: nil, in: concerts)
        repository.addEntry(to: gig)
        repository.addEntry(to: gig)
        repository.upsertItem(named: "Bon Iver", externalRef: nil, in: concerts)
        try repository.save()
        let impact = repository.deletionImpact(of: concerts)
        #expect(impact == DeletionImpact(items: 2, entries: 2))
        #expect(impact.summary == "This deletes 2 items and 2 entries. This can't be undone.")
        #expect(DeletionImpact(items: 0, entries: 0).summary == "This collection is empty.")
        #expect(DeletionImpact(items: 1, entries: 1).summary == "This deletes 1 item and 1 entry. This can't be undone.")
    }

    @Test func deletingCustomCollectionRemovesItsContents() throws {
        let concerts = try makeConcerts()
        let gig = repository.upsertItem(named: "Radiohead", externalRef: nil, in: concerts)
        repository.addEntry(to: gig)
        try repository.save()
        try repository.deleteCollection(concerts)
        #expect(try repository.collections(includeHidden: true).count == 6)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Entry>()) == 0)
    }

    @Test func builtInsCannotBeDeleted() throws {
        let cafes = try #require(try repository.collections().first { $0.kind == .cafes })
        #expect(throws: CollectionDraftError.cannotDeleteBuiltIn) {
            try repository.deleteCollection(cafes)
        }
        #expect(try repository.collections().contains { $0.kind == .cafes })
    }
}
