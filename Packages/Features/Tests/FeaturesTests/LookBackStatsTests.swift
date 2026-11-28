import Foundation
import Model
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct LookBackStatsTests {
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try ArtifactsStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int = 10) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .now
    }

    private func collection(_ kind: CollectionKind) throws -> ExperienceCollection {
        try #require(try repository.collections().first { $0.kind == kind })
    }

    @discardableResult
    private func add(
        _ name: String,
        to collection: ExperienceCollection,
        on days: [Date],
        country: String? = nil,
        rank: Double? = nil,
    ) -> Item {
        let item = repository.upsertItem(named: name, externalRef: nil, in: collection)
        item.countryCode = country
        item.rankScore = rank
        for day in days {
            repository.addEntry(to: item, date: day)
        }
        return item
    }

    @Test func overallCountsEntriesItemsAndTheFavourite() throws {
        let films = try collection(.films)
        add("Perfect Days", to: films, on: [date(2026, 1), date(2026, 3), date(2026, 9)])
        add("Aftersun", to: films, on: [date(2026, 2)])
        let stats = try LookBackStats(collections: repository.collections(), now: date(2026, 11), calendar: utc)
        #expect(stats.entries == 4)
        #expect(stats.items == 2)
        #expect(stats.favourite?.name == "Perfect Days")
        #expect(stats.favourite?.count == 3)
    }

    @Test func theMonthsAreTheLastTwelveOldestFirst() throws {
        let films = try collection(.films)
        add("A", to: films, on: [date(2026, 11, 2), date(2026, 11, 20), date(2025, 12), date(2025, 11)])
        let stats = try LookBackStats(collections: repository.collections(), now: date(2026, 11, 25), calendar: utc)
        #expect(stats.months.count == 12)
        #expect(stats.months.first?.start == utc.date(from: DateComponents(year: 2025, month: 12)))
        #expect(stats.months.first?.count == 1)
        #expect(stats.months.last?.count == 2)
        // November 2025 is thirteen months back: not shown.
        #expect(stats.months.reduce(0) { $0 + $1.count } == 3)
    }

    @Test func countriesAreCountedAgainstTheWorld() throws {
        let countries = try collection(.countries)
        add("Japan", to: countries, on: [date(2026, 1)], country: "JP")
        add("Portugal", to: countries, on: [date(2026, 2)], country: "PT")
        let stats = try LookBackStats(collections: repository.collections(), now: date(2026, 11), calendar: utc)
        #expect(stats.countries == 2)
        #expect(stats.worldShare > 0 && stats.worldShare < 0.02)
        let drawer = try #require(stats.drawers.first { $0.collection.kind == .countries })
        #expect(drawer.standout == "2 of 195 countries")
    }

    @Test func eachDrawerHasItsStandout() throws {
        let cafes = try collection(.cafes)
        add("Monmouth", to: cafes, on: [date(2026, 1)], rank: 1000)
        add("Prufrock", to: cafes, on: [date(2026, 2)], rank: 2000)
        let airlines = try collection(.airlines)
        add("British Airways", to: airlines, on: [date(2026, 1), date(2026, 5)])
        add("TAP", to: airlines, on: [date(2026, 3)])
        let stats = try LookBackStats(collections: repository.collections(), now: date(2026, 11), calendar: utc)
        #expect(stats.drawers.first { $0.collection.kind == .cafes }?.standout == "No. 1 Prufrock")
        #expect(stats.drawers.first { $0.collection.kind == .airlines }?.standout == "Most flown: British Airways ×2")
        let cities = try collection(.cities)
        add("Lisbon", to: cities, on: [date(2026, 4)])
        add("Porto", to: cities, on: [date(2026, 5)])
        let withCities = try LookBackStats(collections: repository.collections(), now: date(2026, 11), calendar: utc)
        #expect(withCities.drawers.first { $0.collection.kind == .cities }?.standout == "2 ticked off")
        // Empty drawers have nothing to stand out.
        #expect(stats.drawers.first { $0.collection.kind == .restaurants }?.standout == nil)
    }

    @Test func rankedDrawersNameTheBestInEachCountry() throws {
        let cafes = try collection(.cafes)
        add("Prufrock", to: cafes, on: [date(2026, 1)], country: "GB", rank: 4000)
        add("Monmouth", to: cafes, on: [date(2026, 1)], country: "GB", rank: 3000)
        add("A Brasileira", to: cafes, on: [date(2026, 1)], country: "PT", rank: 2000)
        add("Unplaced", to: cafes, on: [date(2026, 1)], rank: 1000)
        let stats = try LookBackStats(collections: repository.collections(), now: date(2026, 11), calendar: utc)
        let leaders = try #require(stats.drawers.first { $0.collection.kind == .cafes }).leadersByCountry
        #expect(leaders.map(\.itemName) == ["Prufrock", "A Brasileira"])
        #expect(leaders.map(\.countryName) == ["United Kingdom", "Portugal"])
    }

    @Test func theChartSummarySaysTheTotalAndTheBusiestMonth() {
        let empty = [MonthCount(start: date(2026, 1, 1), count: 0)]
        #expect(LookBackStats.chartSummary(empty) == "Nothing savoured in the last twelve months")
        let months = [MonthCount(start: date(2026, 1, 1), count: 2), MonthCount(start: date(2026, 2, 1), count: 5)]
        let summary = LookBackStats.chartSummary(months)
        #expect(summary.hasPrefix("7 in the last twelve months."))
        #expect(summary.hasSuffix("with 5."))
    }

    @Test func holdingsReadInWords() {
        #expect(StatsText.holds(items: 1, entries: 1) == "1 thing · 1 entry")
        #expect(StatsText.holds(items: 4, entries: 6) == "4 things · 6 entries")
    }
}
