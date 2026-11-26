import Foundation
import Model
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct SpreadOptionsTests {
    private struct Store {
        let container: ModelContainer
        let repository: Repository
        let collection: ExperienceCollection
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private func store(_ mode: RatingMode) throws -> Store {
        let container = try AsvadaStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        let collection = ExperienceCollection(name: "Things", ratingMode: mode)
        repository.context.insert(collection)
        return Store(container: container, repository: repository, collection: collection)
    }

    private func date(_ year: Int, _ month: Int = 6) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: 1, hour: 12)) ?? .now
    }

    @discardableResult
    private func add(
        _ name: String,
        to store: Store,
        on day: Date,
        rating: Double? = nil,
        rank: Double? = nil,
        country: String? = nil,
    ) -> Item {
        let item = store.repository.upsertItem(named: name, externalRef: nil, in: store.collection)
        item.rankScore = rank
        item.countryCode = country
        store.repository.addEntry(to: item, date: day, rating: rating)
        return item
    }

    @Test func eachModeHasItsSpread() {
        #expect(SpreadKind(mode: .ranked) == .menu)
        #expect(SpreadKind(mode: .log) == .ticketBox)
        #expect(SpreadKind(mode: .checklist) == .passport)
        #expect(SpreadKind(mode: .stars) == .pinboard)
        #expect(SpreadKind.menu.title == "The Menu")
        #expect(SpreadKind.ticketBox.title == "Ticket box")
    }

    @Test func theDrawerOrderOfARankedDrawerIsBestFirst() throws {
        let store = try store(.ranked)
        add("Second", to: store, on: date(2026), rank: 1000)
        add("First", to: store, on: date(2020), rank: 2000)
        let items = SpreadOptions().apply(to: store.collection.items ?? [], mode: .ranked, calendar: utc)
        #expect(items.map(\.name) == ["First", "Second"])
    }

    @Test func itemsSortByDateRatingOrName() throws {
        let store = try store(.stars)
        add("Banana", to: store, on: date(2024), rating: 5)
        add("apple", to: store, on: date(2026), rating: 2)
        add("Cherry", to: store, on: date(2025))
        let all = store.collection.items ?? []
        func names(_ sort: SpreadOptions.Sort) -> [String] {
            SpreadOptions(sort: sort).apply(to: all, mode: .stars, calendar: utc).map(\.name)
        }
        #expect(names(.newest) == ["apple", "Cherry", "Banana"])
        #expect(names(.rating) == ["Banana", "apple", "Cherry"])
        #expect(names(.name) == ["apple", "Banana", "Cherry"])
    }

    @Test func filtersKeepOneYearOrOneCountry() throws {
        let store = try store(.stars)
        add("Lisbon café", to: store, on: date(2025), country: "PT")
        add("Porto café", to: store, on: date(2026), country: "pt")
        add("Tokyo café", to: store, on: date(2026), country: "JP")
        let all = store.collection.items ?? []

        let in2026 = SpreadOptions(year: 2026).apply(to: all, mode: .stars, calendar: utc)
        #expect(Set(in2026.map(\.name)) == ["Porto café", "Tokyo café"])
        let inPortugal = SpreadOptions(country: "PT").apply(to: all, mode: .stars, calendar: utc)
        #expect(Set(inPortugal.map(\.name)) == ["Lisbon café", "Porto café"])
        let both = SpreadOptions(year: 2026, country: "PT").apply(to: all, mode: .stars, calendar: utc)
        #expect(both.map(\.name) == ["Porto café"])
        #expect(SpreadOptions(year: 2026).isFiltered)
        #expect(!SpreadOptions(sort: .name).isFiltered)
    }

    @Test func theFiltersOfferTheYearsAndCountriesThereAre() throws {
        let store = try store(.stars)
        add("A", to: store, on: date(2024), country: "PT")
        add("B", to: store, on: date(2026), country: "JP")
        add("C", to: store, on: date(2026))
        let all = store.collection.items ?? []
        #expect(SpreadOptions.years(in: all, calendar: utc) == [2026, 2024])
        #expect(SpreadOptions.countries(in: all).map(\.code) == ["JP", "PT"])
    }

    @Test func aTicketBoxIsSplitIntoYearsKeepingTheOrder() throws {
        let store = try store(.log)
        add("New", to: store, on: date(2026, 9))
        add("Also new", to: store, on: date(2026, 2))
        add("Old", to: store, on: date(2023))
        let ordered = SpreadOptions().apply(to: store.collection.items ?? [], mode: .log, calendar: utc)
        let years = SpreadYear.group(ordered, calendar: utc)
        #expect(years.map(\.year) == [2026, 2023])
        #expect(years.first?.items.map(\.name) == ["New", "Also new"])
    }

    @Test func averageRatingIgnoresUnratedEntries() throws {
        let store = try store(.stars)
        let item = add("A", to: store, on: date(2026), rating: 4)
        store.repository.addEntry(to: item, date: date(2026, 7), rating: 2)
        store.repository.addEntry(to: item, date: date(2026, 8))
        #expect(item.averageRating == 3)
        let unrated = add("B", to: store, on: date(2026))
        #expect(unrated.averageRating == nil)
    }
}

struct SpreadTextTests {
    @Test func pagesAreCutEvenlyWithTheRestOnTheLast() {
        #expect(SpreadText.pages(of: Array(1 ... 13), perPage: 6) == [[1, 2, 3, 4, 5, 6], [7, 8, 9, 10, 11, 12], [13]])
        #expect(SpreadText.pages(of: [Int](), perPage: 6).isEmpty)
    }

    @Test func aPinLeansTheSameWayEveryTime() {
        let id = UUID()
        let tilt = SpreadText.tilt(for: id)
        #expect(tilt == SpreadText.tilt(for: id))
        #expect((-3 ... 3).contains(tilt))
    }

    @Test func countsReadInWords() {
        #expect(SpreadText.count(1) == "1 keepsake")
        #expect(SpreadText.count(4) == "4 keepsakes")
    }
}
