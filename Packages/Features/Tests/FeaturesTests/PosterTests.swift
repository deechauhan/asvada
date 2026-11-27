import Foundation
import Geo
import Model
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct PosterTests {
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try AsvadaStore.makeContainer(.inMemory)
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

    @discardableResult
    private func visit(_ name: String, at point: GeoPoint?, country: String?, on day: Date) throws -> Entry {
        let cafes = try #require(try repository.collections().first { $0.kind == .cafes })
        let item = repository.upsertItem(named: name, externalRef: nil, in: cafes)
        item.latitude = point?.latitude
        item.longitude = point?.longitude
        item.countryCode = country
        return repository.addEntry(to: item, date: day)
    }

    private let lisbon = GeoPoint(longitude: -9.14, latitude: 38.72)
    private let porto = GeoPoint(longitude: -8.61, latitude: 41.15)

    @Test func aTripsPosterHasItsPlacesInOrderOnce() throws {
        let first = try visit("A Brasileira", at: lisbon, country: "PT", on: date(2026, 6, 1))
        let again = try visit("A Brasileira", at: lisbon, country: "PT", on: date(2026, 6, 2))
        let north = try visit("Majestic", at: porto, country: "PT", on: date(2026, 6, 4))
        let nowhere = try visit("Somewhere", at: nil, country: nil, on: date(2026, 6, 5))
        let trip = try repository.createTrip(
            name: "Portugal",
            start: date(2026, 6, 1),
            end: date(2026, 6, 7),
            entries: [north, first, again, nowhere],
        )
        let subject = PosterSubject(trip: trip)
        #expect(subject.title == "Portugal")
        #expect(subject.subtitle.hasSuffix("4 keepsakes"))
        #expect(subject.points == [lisbon, porto])
        #expect(subject.photos.isEmpty)
    }

    @Test func aYearsPosterCountsItsCountries() throws {
        try visit("Lisbon café", at: lisbon, country: "PT", on: date(2026, 3))
        try visit("Tokyo café", at: GeoPoint(longitude: 139.69, latitude: 35.68), country: "JP", on: date(2026, 9))
        try visit("Last year", at: porto, country: "PT", on: date(2025, 9))
        let subject = try PosterSubject(year: 2026, collections: repository.collections(), calendar: utc)
        #expect(subject.title == "2026")
        #expect(subject.subtitle == "2 keepsakes · 2 countries")
        #expect(subject.points.count == 2)
    }

    @Test func theMapFitsItsPlacesWithRoomAround() {
        let region = PosterRegion.fitting([lisbon, porto])
        #expect(abs(region.centre.latitude - (38.72 + 41.15) / 2) < 0.0001)
        #expect(region.latitudeSpan > 41.15 - 38.72)
        #expect(region.longitudeSpan >= PosterRegion.minimumSpan)
        // One place isn't a street map.
        let single = PosterRegion.fitting([lisbon])
        #expect(single.latitudeSpan == PosterRegion.minimumSpan)
        // No places: the world.
        #expect(PosterRegion.fitting([]) == PosterRegion.world)
    }

    @Test func fileNamesAreSafe() {
        #expect(PosterText.fileName(for: "Lisbon / Porto: June?") == "Asvada poster · Lisbon  Porto June")
        #expect(PosterText.count(1) == "1 keepsake")
    }
}
