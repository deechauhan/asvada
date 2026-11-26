import Foundation
import Geo
import Model
import SwiftData
import Testing
@testable import Storage

@MainActor
struct VisitSuggestionsTests {
    let container: ModelContainer
    let repository: Repository
    var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    init() throws {
        container = try AsvadaStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
    }

    private func date(_ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)) ?? .now
    }

    private func visit(
        _ id: String,
        country: String? = "PT",
        from start: Date,
        to end: Date,
    ) -> VisitCluster {
        let name = country.flatMap { CountryCatalog.shared.country(code: $0)?.name }
        return VisitCluster(
            id: id,
            start: start,
            end: end,
            centre: GeoPoint(longitude: -9.14, latitude: 38.72),
            photoCount: 20,
            sampleIDs: ["a", "b"],
            countryCode: country,
            countryName: name,
        )
    }

    private func defaults() throws -> UserDefaults {
        let name = "visit-tests-\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: name))
    }

    @Test func acceptingAVisitStampsTheCountryAndMakesATrip() throws {
        let lisbon = visit("v1", from: date(6, 1), to: date(6, 7))
        let entry = try #require(try repository.acceptVisit(lisbon, calendar: utc))
        #expect(entry.item?.name == "Portugal")
        #expect(entry.item?.collection?.kind == .countries)
        #expect(entry.item?.countryCode == "PT")
        #expect(entry.date == lisbon.start)
        let trip = try #require(entry.trip)
        #expect(trip.name == "Portugal")
        #expect(trip.start == lisbon.start)
        #expect(trip.end == lisbon.end)
    }

    @Test func aSecondVisitToTheSameCountryAddsAnotherEntryAndTripNotAnotherStamp() throws {
        try repository.acceptVisit(visit("v1", from: date(6, 1), to: date(6, 7)), calendar: utc)
        try repository.acceptVisit(visit("v2", from: date(9, 10), to: date(9, 14)), calendar: utc)
        let countries = try #require(try repository.collections(includeHidden: true).first { $0.kind == .countries })
        let portugal = (countries.items ?? []).filter { $0.countryCode == "PT" }
        #expect(portugal.count == 1)
        #expect(portugal.first?.entries?.count == 2)
        #expect(try repository.trips().count == 2)
    }

    @Test func aVisitWithNoCountryAddsNothing() throws {
        let sea = visit("v1", country: nil, from: date(6, 1), to: date(6, 2))
        #expect(try repository.acceptVisit(sea, calendar: utc) == nil)
        #expect(try repository.trips().isEmpty)
    }

    @Test func handledVisitsAndVisitsAtSeaAreNotSuggested() {
        let one = visit("v1", from: date(6, 1), to: date(6, 7))
        let two = visit("v2", from: date(8, 1), to: date(8, 3))
        let sea = visit("v3", country: nil, from: date(9, 1), to: date(9, 3))
        let pending = repository.pendingVisits(from: [one, two, sea], handled: ["v1"], calendar: utc)
        #expect(pending.map(\.id) == ["v2"])
    }

    @Test func aVisitAlreadyInTheKeepsakesIsNotSuggestedAgain() throws {
        // Portugal already has an entry on the day the visit ended.
        try repository.acceptVisit(visit("old", from: date(6, 7), to: date(6, 7)), calendar: utc)
        let overlapping = visit("v1", from: date(6, 5), to: date(6, 8))
        let elsewhere = visit("v2", from: date(7, 20), to: date(7, 22))
        let pending = repository.pendingVisits(from: [overlapping, elsewhere], handled: [], calendar: utc)
        #expect(pending.map(\.id) == ["v2"])
    }

    @Test func decisionsAreRememberedAndCanBeForgotten() throws {
        let store = try defaults()
        let decisions = VisitDecisions(defaults: store)
        #expect(decisions.handled.isEmpty)
        decisions.markHandled("b")
        decisions.markHandled("a")
        decisions.markHandled("a")
        #expect(decisions.handled == ["a", "b"])
        decisions.reset()
        #expect(decisions.handled.isEmpty)
    }
}
