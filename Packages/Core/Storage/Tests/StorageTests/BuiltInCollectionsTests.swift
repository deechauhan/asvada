import Foundation
import Model
import SwiftData
import Testing
@testable import Storage

@MainActor
struct BuiltInCollectionsTests {
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try AsvadaStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
    }

    @Test func seedsSixBuiltInsInOrder() throws {
        let created = try BuiltInCollections.seedIfNeeded(in: repository.context)
        #expect(created == 6)
        let collections = try repository.collections()
        #expect(collections.map(\.name) == ["Cafés", "Restaurants", "Countries", "Cities", "Airlines", "Films"])
        // Evaluated outside #expect: the macro mis-handles rethrowing calls like allSatisfy.
        let allBuiltIn = collections.allSatisfy(\.isBuiltIn)
        #expect(allBuiltIn)
    }

    @Test func builtInsHaveSensibleModes() throws {
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        let byKind = try Dictionary(uniqueKeysWithValues: repository.collections().map { ($0.kind, $0) })
        #expect(byKind[.cafes]?.ratingMode == .ranked)
        #expect(byKind[.restaurants]?.ratingMode == .ranked)
        #expect(byKind[.countries]?.ratingMode == .checklist)
        #expect(byKind[.countries]?.defaultView == .progress)
        #expect(byKind[.countries]?.itemSource == .countryCatalog)
        #expect(byKind[.cities]?.defaultView == .map)
        #expect(byKind[.airlines]?.ratingMode == .log)
        #expect(byKind[.airlines]?.itemSource == .airlineCatalog)
        #expect(byKind[.films]?.ratingMode == .log)
        #expect(byKind[.films]?.itemSource == .tmdb)
    }

    @Test func seedingIsIdempotent() throws {
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        let second = try BuiltInCollections.seedIfNeeded(in: repository.context)
        #expect(second == 0)
        #expect(try repository.collections(includeHidden: true).count == 6)
    }

    @Test func hiddenBuiltInStaysHiddenAndIsNotDuplicated() throws {
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        let airlines = try #require(try repository.collections().first { $0.kind == .airlines })
        airlines.isHidden = true
        try repository.save()

        try BuiltInCollections.seedIfNeeded(in: repository.context)

        let all = try repository.collections(includeHidden: true)
        let airlinesCount = all.count { $0.kind == .airlines }
        #expect(airlinesCount == 1)
        #expect(all.first { $0.kind == .airlines }?.isHidden == true)
        #expect(try !repository.collections().contains { $0.kind == .airlines })
    }

    @Test func customCollectionsAreLeftAlone() throws {
        let hikes = ExperienceCollection(name: "Hikes", kind: .custom)
        repository.context.insert(hikes)
        try repository.save()
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        let all = try repository.collections(includeHidden: true)
        #expect(all.count == 7)
        #expect(all.contains { $0.name == "Hikes" && !$0.isBuiltIn })
    }

    @Test func onlyMissingBuiltInsAreRestored() throws {
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        let films = try #require(try repository.collections().first { $0.kind == .films })
        repository.delete(films)
        try repository.save()

        #expect(try BuiltInCollections.seedIfNeeded(in: repository.context) == 1)
        #expect(try repository.collections(includeHidden: true).count == 6)
    }

    @Test func specsCoverEveryBuiltInKindOnce() {
        let kinds = BuiltInCollections.all.map(\.kind)
        #expect(Set(kinds) == Set(CollectionKind.allCases.filter { $0 != .custom }))
        #expect(kinds.count == Set(kinds).count)
    }

    @Test func sampleDataFillsSomeBuiltInsAndLeavesOthersEmpty() throws {
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        try PreviewData.fillBuiltIns(repository)
        let byKind = try Dictionary(uniqueKeysWithValues: repository.collections().map { ($0.kind, $0) })
        #expect(byKind[.cafes]?.items?.count == 4)
        #expect(byKind[.countries]?.items?.count == 4)
        #expect(byKind[.films]?.items?.count == 3)
        #expect(byKind[.airlines]?.items?.first?.entries?.count == 2)
        #expect(byKind[.restaurants]?.items?.isEmpty == true)
        #expect(byKind[.cities]?.items?.isEmpty == true)
    }
}

