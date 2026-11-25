import Foundation
import Model
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct ItemStatsTests {
    @Test(arguments: [
        (CollectionKind.cafes, 1, "1 visit"),
        (CollectionKind.restaurants, 3, "3 visits"),
        (CollectionKind.airlines, 1, "1 flight"),
        (CollectionKind.airlines, 4, "4 flights"),
        (CollectionKind.films, 1, "Watched once"),
        (CollectionKind.films, 2, "Watched twice"),
        (CollectionKind.films, 5, "Watched 5 times"),
        (CollectionKind.countries, 0, "Not savoured yet"),
    ])
    func countsSayVisitsFlightsOrWatches(kind: CollectionKind, count: Int, line: String) {
        #expect(ItemStats.countLine(count, kind: kind) == line)
    }

    @Test func rankedItemsSayWhereTheyRank() {
        let cafes = ExperienceCollection(name: "Cafés", kind: .cafes, ratingMode: .ranked)
        let item = Item(name: "Prufrock")
        #expect(ItemStats(item: item, collection: cafes, rank: 1).rankLine == "No. 2 in Cafés")
        #expect(ItemStats(item: item, collection: cafes, rank: nil).rankLine == nil)
        #expect(ItemStats(item: item, collection: cafes, rank: 0).relish == nil)
    }

    @Test func starItemsAverageTheirRelish() throws {
        let container = try AsvadaStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        let concerts = ExperienceCollection(name: "Concerts", kind: .custom, ratingMode: .stars)
        container.mainContext.insert(concerts)
        let item = repository.upsertItem(named: "Phoebe Bridgers", externalRef: nil, in: concerts)
        for rating in [4.0, 5, 4] {
            repository.addEntry(to: item, rating: rating)
        }
        let stats = ItemStats(item: item, collection: concerts, rank: nil)
        #expect(stats.count == 3)
        #expect(stats.relish == "Lovely · 4.3")
        #expect(stats.rankLine == nil)
    }

    @Test func entriesComeNewestFirst() throws {
        let container = try AsvadaStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        let films = ExperienceCollection(name: "Films", kind: .films, ratingMode: .log)
        container.mainContext.insert(films)
        let item = repository.upsertItem(named: "Perfect Days", externalRef: nil, in: films)
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = Date(timeIntervalSince1970: 1_790_000_000)
        repository.addEntry(to: item, date: older)
        repository.addEntry(to: item, date: newer)
        #expect(item.entriesNewestFirst.map(\.date) == [newer, older])
    }
}
