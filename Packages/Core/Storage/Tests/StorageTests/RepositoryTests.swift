import Foundation
import Model
import SwiftData
import Testing
@testable import Storage

@MainActor
struct RepositoryTests {
    /// Keep the container alive for the whole test: a context doesn't retain it.
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try ArtifactsStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
    }

    private func makeCollection(_ name: String, kind: CollectionKind = .custom) -> ExperienceCollection {
        let collection = ExperienceCollection(name: name, kind: kind)
        repository.context.insert(collection)
        return collection
    }

    @Test func upsertInsertsNewItem() throws {
        let countries = makeCollection("Countries", kind: .countries)
        let japan = repository.upsertItem(named: "Japan", externalRef: "iso:JP", in: countries)
        try repository.save()
        #expect(japan.collection === countries)
        #expect(repository.items(in: countries).map(\.name) == ["Japan"])
    }

    @Test func upsertDedupesByExternalRefWithinCollection() throws {
        let countries = makeCollection("Countries", kind: .countries)
        let first = repository.upsertItem(named: "Japan", externalRef: "iso:JP", in: countries)
        let second = repository.upsertItem(named: "Japan (日本)", externalRef: "iso:JP", in: countries)
        try repository.save()
        #expect(first === second)
        #expect(repository.items(in: countries).count == 1)
        #expect(first.name == "Japan (日本)")
    }

    @Test func sameExternalRefInDifferentCollectionsIsSeparate() throws {
        let films = makeCollection("Films", kind: .films)
        let watchlist = makeCollection("Watch again")
        let inFilms = repository.upsertItem(named: "Spirited Away", externalRef: "tmdb:129", in: films)
        let inWatchlist = repository.upsertItem(named: "Spirited Away", externalRef: "tmdb:129", in: watchlist)
        try repository.save()
        #expect(inFilms !== inWatchlist)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Item>()) == 2)
    }

    @Test func manualItemsWithoutExternalRefAreAlwaysNew() throws {
        let hikes = makeCollection("Hikes")
        repository.upsertItem(named: "Scafell Pike", externalRef: nil, in: hikes)
        repository.upsertItem(named: "Scafell Pike", externalRef: nil, in: hikes)
        try repository.save()
        #expect(repository.items(in: hikes).count == 2)
    }

    @Test func deletingCollectionCascades() throws {
        let cafes = makeCollection("Cafés", kind: .cafes)
        let cafe = repository.upsertItem(named: "Prufrock", externalRef: "mk:1", in: cafes)
        repository.addEntry(to: cafe, rating: 4)
        try repository.save()

        repository.delete(cafes)
        try repository.save()

        #expect(try repository.collections(includeHidden: true).isEmpty)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Item>()) == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Entry>()) == 0)
    }

    @Test func collectionsAreOrderedAndHiddenOnesExcluded() throws {
        let second = makeCollection("Films")
        second.sortIndex = 2
        let first = makeCollection("Cafés")
        first.sortIndex = 1
        let hidden = makeCollection("Airlines")
        hidden.isHidden = true
        try repository.save()
        #expect(try repository.collections().map(\.name) == ["Cafés", "Films"])
        #expect(try repository.collections(includeHidden: true).count == 3)
    }

    @Test func recentEntriesAreNewestFirst() throws {
        let films = makeCollection("Films")
        let film = repository.upsertItem(named: "Paterson", externalRef: "tmdb:370755", in: films)
        repository.addEntry(to: film, date: Date(timeIntervalSince1970: 1000), notes: "old")
        repository.addEntry(to: film, date: Date(timeIntervalSince1970: 2000), notes: "new")
        try repository.save()
        #expect(try repository.recentEntries().map(\.notes) == ["new", "old"])
        #expect(try repository.recentEntries(limit: 1).count == 1)
    }

    @Test func previewDataHasSampleContent() throws {
        let preview = try PreviewData.makeContainer()
        let previewRepository = Repository(context: preview.mainContext)
        #expect(try previewRepository.collections().map(\.name) == ["Cafés", "Countries", "Films"])
        #expect(try previewRepository.recentEntries().count == 3)
    }
}
