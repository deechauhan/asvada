import Foundation
import Geo
import Model
import SwiftData
import Testing
@testable import Storage

@MainActor
struct TripTests {
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

    private func date(_ month: Int, _ day: Int, hour: Int = 12) -> Date {
        utc.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)) ?? .now
    }

    @discardableResult
    private func visit(_ name: String, in kind: CollectionKind, on date: Date, at point: GeoPoint? = nil) throws -> Entry {
        let collection = try #require(try repository.collections().first { $0.kind == kind })
        let item = repository.upsertItem(named: name, externalRef: nil, in: collection)
        if let point {
            item.latitude = point.latitude
            item.longitude = point.longitude
        }
        return repository.addEntry(to: item, date: date)
    }

    @Test func suggestionsAreTheUntripedEntriesInTheDatesBothDaysIncluded() throws {
        let before = try visit("Before", in: .cafes, on: date(5, 31, hour: 23))
        let first = try visit("First day", in: .cafes, on: date(6, 1, hour: 0))
        let middle = try visit("Middle", in: .restaurants, on: date(6, 3))
        let last = try visit("Last day", in: .cafes, on: date(6, 5, hour: 23))
        let after = try visit("After", in: .cafes, on: date(6, 6, hour: 0))
        // One that already belongs to another trip is left out.
        let taken = try visit("Taken", in: .cafes, on: date(6, 2))
        try repository.createTrip(name: "Other", start: date(6, 2), end: date(6, 2), entries: [taken])

        let found = try repository.suggestedEntries(from: date(6, 1), to: date(6, 5), calendar: utc)
        #expect(found.map(\.id) == [first.id, middle.id, last.id])
        #expect(!found.contains { $0.id == before.id || $0.id == after.id || $0.id == taken.id })
    }

    @Test func creatingATripGroupsItsEntriesAndFixesBackwardsDates() throws {
        let one = try visit("One", in: .cafes, on: date(6, 2))
        let trip = try repository.createTrip(name: "  Lisbon ", start: date(6, 5), end: date(6, 1), entries: [one])
        #expect(trip.name == "Lisbon")
        #expect(trip.end == trip.start)
        #expect(one.trip?.id == trip.id)
        #expect(trip.entries?.count == 1)
    }

    @Test func editingAddsAndRemovesEntriesAndOwnEntriesAreStillOffered() throws {
        let one = try visit("One", in: .cafes, on: date(6, 2))
        let two = try visit("Two", in: .cafes, on: date(6, 3))
        let trip = try repository.createTrip(name: "Trip", start: date(6, 1), end: date(6, 5), entries: [one])

        // While editing, its own entry is offered along with the free ones.
        let offered = try repository.suggestedEntries(from: date(6, 1), to: date(6, 5), excluding: trip, calendar: utc)
        #expect(Set(offered.map(\.id)) == [one.id, two.id])

        try repository.update(trip, name: "Renamed", start: date(6, 1), end: date(6, 4), entries: [two])
        #expect(trip.name == "Renamed")
        #expect(one.trip == nil)
        #expect(two.trip?.id == trip.id)
    }

    @Test func deletingATripKeepsItsEntries() throws {
        let one = try visit("One", in: .cafes, on: date(6, 2))
        let trip = try repository.createTrip(name: "Trip", start: date(6, 1), end: date(6, 5), entries: [one])
        try repository.deleteTrip(trip)
        #expect(try repository.trips().isEmpty)
        #expect(one.trip == nil)
        #expect(one.item != nil)
    }

    @Test func tripsListTheMostRecentFirst() throws {
        try repository.createTrip(name: "Older", start: date(3, 1), end: date(3, 5), entries: [])
        try repository.createTrip(name: "Newer", start: date(9, 1), end: date(9, 5), entries: [])
        #expect(try repository.trips().map(\.name) == ["Newer", "Older"])
    }

    @Test func aTripIsLaidOutByDayWithItsRouteInOrder() throws {
        let lisbon = GeoPoint(longitude: -9.14, latitude: 38.72)
        let porto = GeoPoint(longitude: -8.61, latitude: 41.15)
        let flight = try visit("TAP", in: .airlines, on: date(6, 1, hour: 8))
        let cafe = try visit("Café A Brasileira", in: .cafes, on: date(6, 1, hour: 15), at: lisbon)
        let lunch = try visit("Cervejaria", in: .restaurants, on: date(6, 1, hour: 20), at: lisbon)
        let train = try visit("Porto stop", in: .cafes, on: date(6, 3, hour: 11), at: porto)
        // Handed over out of order.
        let summary = TripSummary.make(entries: [train, lunch, flight, cafe], calendar: utc)

        #expect(summary.days.count == 2)
        #expect(summary.days[0].entries.map(\.id) == [flight.id, cafe.id, lunch.id])
        #expect(summary.days[1].entries.map(\.id) == [train.id])
        #expect(summary.entryCount == 4)
        // The flight has no place; Lisbon twice in a row counts once; then Porto.
        #expect(summary.route == [lisbon, porto])
    }

    @Test func anEmptyTripHasNoDaysAndNoRoute() {
        let summary = TripSummary.make(entries: [], calendar: utc)
        #expect(summary.days.isEmpty)
        #expect(summary.route.isEmpty)
        #expect(summary.entryCount == 0)
    }
}
