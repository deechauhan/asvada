import Foundation
import Model
import Ranking
import SwiftData
import Testing
@testable import Storage

@MainActor
struct RankingStorageTests {
    let container: ModelContainer
    let repository: Repository
    let cafes: ExperienceCollection

    init() throws {
        container = try ArtifactsStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        let match = try repository.collections().first { $0.kind == .cafes }
        cafes = try #require(match)
    }

    private func cafe(_ name: String) -> Item {
        repository.upsertItem(named: name, externalRef: "mk:\(name)", in: cafes)
    }

    private func names() -> [String] {
        repository.ranking(of: cafes).map(\.name)
    }

    /// Ranks `name` by answering each question from `taste` (higher is better).
    private func rank(_ name: String, taste: [String: Int]) throws {
        let newcomer = cafe(name)
        let ranked = repository.ranking(of: cafes).filter { $0.id != newcomer.id }
        var insertion = BinaryInsertion(count: ranked.count)
        while let index = insertion.comparisonIndex {
            let mine = try #require(taste[name])
            let theirs = try #require(taste[ranked[index].name])
            insertion.record(mine > theirs ? .better : .worse)
        }
        let position = try #require(insertion.position)
        repository.place(newcomer, at: position, in: cafes)
        try repository.save()
    }

    @Test func rankingFollowsTheAnswers() throws {
        let taste = ["Prufrock": 9, "Monmouth": 7, "Kaffeine": 8, "Workshop": 3, "Origin": 5, "Attendant": 6]
        for name in ["Monmouth", "Workshop", "Prufrock", "Origin", "Kaffeine", "Attendant"] {
            try rank(name, taste: taste)
        }
        #expect(names() == ["Prufrock", "Kaffeine", "Monmouth", "Attendant", "Origin", "Workshop"])
    }

    @Test func unrankedItemsStayOutOfTheRanking() {
        repository.place(cafe("Prufrock"), at: 0, in: cafes)
        _ = cafe("Not yet ranked")
        #expect(names() == ["Prufrock"])
    }

    @Test func placingMovesAnAlreadyRankedItem() {
        for (index, name) in ["A", "B", "C"].enumerated() {
            repository.place(cafe(name), at: index, in: cafes)
        }
        repository.place(cafe("C"), at: 0, in: cafes)
        #expect(names() == ["C", "A", "B"])
        repository.unrank(cafe("A"))
        #expect(names() == ["C", "B"])
    }

    @Test func crowdedScoresAreRebalancedInPlace() {
        // Scores as the old sample data had them: too close for a midpoint.
        let scored = [("Prufrock", 0.92), ("Monmouth", 0.81), ("Kaffeine", 0.74)]
        for (name, score) in scored {
            cafe(name).rankScore = score
        }
        repository.place(cafe("Origin"), at: 1, in: cafes)
        #expect(names() == ["Prufrock", "Origin", "Monmouth", "Kaffeine"])
        let scores = repository.ranking(of: cafes).compactMap(\.rankScore)
        #expect(scores == [4000, 3000, 2000, 1000])
    }
}

@MainActor
struct StressItemsTests {
    @Test func stressItemsRankBelowTheSamples() throws {
        let container = try ArtifactsStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        try PreviewData.fillBuiltIns(repository)
        try PreviewData.addStressItems(50, to: repository)
        let match = try repository.collections().first { $0.kind == .cafes }
        let cafes = try #require(match)
        let ranked = repository.ranking(of: cafes)
        #expect(ranked.count == 54)
        #expect(ranked.first?.name == "Prufrock Coffee")
        #expect(ranked[4].name == "Café 1")
        #expect(ranked.last?.name == "Café 50")
    }
}

@MainActor
struct PlaceStorageTests {
    @Test func aFoundPlaceIsKeptWithItsWhereabouts() throws {
        let container = try ArtifactsStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        let match = try repository.collections().first { $0.kind == .cafes }
        let cafes = try #require(match)
        let place = PlaceDetails(
            name: "Prufrock Coffee",
            externalRef: "mk:I1234",
            latitude: 51.5204,
            longitude: -0.1094,
            countryCode: "GB",
            address: "23-25 Leather Ln, London",
        )
        let item = repository.upsertPlace(place, in: cafes)
        #expect(item.latitude == 51.5204 && item.longitude == -0.1094)
        #expect(item.countryCode == "GB")
        #expect(item.placeAddress == "23-25 Leather Ln, London")
        // Finding it again updates the same item.
        let renamed = PlaceDetails(
            name: "Prufrock",
            externalRef: "mk:I1234",
            latitude: 51.5204,
            longitude: -0.1094,
            countryCode: nil,
            address: nil,
        )
        let again = repository.upsertPlace(renamed, in: cafes)
        #expect(again.id == item.id)
        #expect(again.name == "Prufrock")
        #expect(again.countryCode == "GB", "a missing code doesn't erase a known one")
        #expect(again.placeAddress == "23-25 Leather Ln, London")
    }
}

@MainActor
struct StressPlacesTests {
    /// A store and its repository; the container is held so the models outlive the call.
    private struct Store {
        let container: ModelContainer
        let repository: Repository
    }

    private func makeStore() throws -> Store {
        let container = try ArtifactsStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        return Store(container: container, repository: repository)
    }

    @Test func placesAreScatteredWithEntriesAndTheirCountriesAreStamped() throws {
        let store = try makeStore()
        try withExtendedLifetime(store) {
            try PreviewData.addStressPlaces(400, to: store.repository)
            let items = try store.repository.context.fetch(FetchDescriptor<Item>())
            let places = items.filter { $0.externalRef?.hasPrefix("stress-place:") == true }
            #expect(places.count == 400)
            #expect(places.allSatisfy { $0.latitude != nil && $0.longitude != nil && !($0.entries ?? []).isEmpty })
            // Three collections share them.
            #expect(Set(places.compactMap { $0.collection?.kind }).count == 3)
            // Their countries are stamped, as for real places (28 cities in about 25 countries).
            let stamps = items.filter { $0.collection?.kind == .countries }
            #expect(stamps.count > 15)
        }
    }

    @Test func theSameCountMakesTheSamePlaces() throws {
        func positions() throws -> [Double] {
            let store = try makeStore()
            return try withExtendedLifetime(store) {
                try PreviewData.addStressPlaces(60, to: store.repository)
                let items = try store.repository.context.fetch(FetchDescriptor<Item>())
                return items
                    .filter { $0.externalRef?.hasPrefix("stress-place:") == true }
                    .sorted { ($0.externalRef ?? "") < ($1.externalRef ?? "") }
                    .compactMap(\.latitude)
            }
        }
        let first = try positions()
        let second = try positions()
        #expect(first == second)
        #expect(first.count == 60)
    }

    @Test func noCountMakesNothing() throws {
        let store = try makeStore()
        try withExtendedLifetime(store) {
            try PreviewData.addStressPlaces(0, to: store.repository)
            let items = try store.repository.context.fetch(FetchDescriptor<Item>())
            #expect(items.isEmpty)
        }
    }
}
