import CoreLocation
import Foundation
import Geo
import Model
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct AtlasTests {
    private struct Store {
        let container: ModelContainer
        let repository: Repository
        let cafes: ExperienceCollection
        let countries: ExperienceCollection
    }

    private func store() throws -> Store {
        let container = try ArtifactsStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        let cafes = ExperienceCollection(name: "Cafés", kind: .cafes, ratingMode: .ranked)
        let countries = ExperienceCollection(name: "Countries", kind: .countries, ratingMode: .checklist)
        repository.context.insert(cafes)
        repository.context.insert(countries)
        return Store(container: container, repository: repository, cafes: cafes, countries: countries)
    }

    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSinceReferenceDate: 1_000_000).addingTimeInterval(Double(offset) * 86400)
    }

    /// An entry made directly, without `addEntry` also stamping the item's country.
    @discardableResult
    private func log(_ item: Item, on date: Date, in store: Store) -> Entry {
        let entry = Entry(date: date)
        store.repository.context.insert(entry)
        entry.item = item
        return entry
    }

    @Test func visitedCountriesAreTheStampedOnesAndNothingElse() throws {
        let store = try store()
        try store.repository.setStamped(["pt", "JP"], in: store.countries)
        let cafe = store.repository.upsertItem(named: "Pastéis", externalRef: nil, in: store.cafes)
        cafe.countryCode = "FR"
        let items = try store.repository.context.fetch(FetchDescriptor<Item>())
        #expect(AtlasLogic.visitedCodes(items: items) == ["PT", "JP"])
    }

    @Test func aPlaceStampsItsCountryForTheAtlas() throws {
        let store = try store()
        let cafe = store.repository.upsertItem(named: "Pastéis", externalRef: nil, in: store.cafes)
        cafe.latitude = 38.7
        cafe.longitude = -9.14
        store.repository.stampCountry(of: cafe)
        let items = try store.repository.context.fetch(FetchDescriptor<Item>())
        #expect(AtlasLogic.visitedCodes(items: items) == ["PT"])
    }

    @Test func aCountrysEntriesIncludeItsStampAndThePlacesInIt_NewestFirst() throws {
        let store = try store()
        let repository = store.repository
        try repository.setStamped(["PT"], in: store.countries)
        let stamp = try #require(store.countries.items?.first)
        let stampEntry = log(stamp, on: day(0), in: store)
        let lisbon = repository.upsertItem(named: "Pastéis", externalRef: nil, in: store.cafes)
        lisbon.countryCode = "PT"
        let cafeEntry = log(lisbon, on: day(3), in: store)
        let paris = repository.upsertItem(named: "Café de Flore", externalRef: nil, in: store.cafes)
        paris.countryCode = "FR"
        log(paris, on: day(5), in: store)

        let all = try repository.context.fetch(FetchDescriptor<Entry>())
        let found = AtlasLogic.entries(inCountry: "pt", from: all)
        #expect(found.map(\.id) == [cafeEntry.id, stampEntry.id])
        #expect(AtlasLogic.entries(inCountry: "FR", from: all).count == 1)
        #expect(AtlasLogic.entries(inCountry: "JP", from: all).isEmpty)
    }

    @Test func theHeadlineIsAGhostLineUntilTheFirstStamp() {
        #expect(AtlasLogic.headline(visited: 0) == "Your countries will fill with ink here")
        #expect(AtlasLogic.headline(visited: 8, worldTotal: 200) == "8 countries · 4% of the world")
        #expect(!AtlasLogic.headline(visited: 0).contains("0"))
    }

    @Test func aCountryTurnsIntoCoordinateRings() throws {
        let japan = try #require(CountryCatalog.shared.country(code: "JP"))
        let rings = AtlasLogic.rings(of: japan)
        #expect(rings.count > 1)
        #expect(rings.allSatisfy { $0.count > 2 })
        let first = try #require(japan.outlines.first?.first)
        #expect(rings.first?.first?.latitude == first.latitude)
        #expect(rings.first?.first?.longitude == first.longitude)
    }

    @Test func aTapFindsTheCountryUnderIt() {
        #expect(AtlasLogic.country(at: CLLocationCoordinate2D(latitude: 38.7, longitude: -9.14))?.code == "PT")
        #expect(AtlasLogic.country(at: CLLocationCoordinate2D(latitude: 36, longitude: 139))?.code == "JP")
        // Mid-Atlantic.
        #expect(AtlasLogic.country(at: CLLocationCoordinate2D(latitude: 30, longitude: -40)) == nil)
    }

    @Test func theSheetSaysWhatIsMissingNotAZero() throws {
        let portugal = try #require(CountryCatalog.shared.country(code: "PT"))
        #expect(AtlasLogic.entryCount(1) == "1 entry")
        #expect(AtlasLogic.entryCount(3) == "3 entries")
        #expect(AtlasLogic.emptyLine(for: portugal, isVisited: true).contains("Stamped"))
        #expect(AtlasLogic.emptyLine(for: portugal, isVisited: false).contains("Not stamped yet"))
    }
}

// MARK: - Pins (#51)

@MainActor
struct AtlasPinTests {
    private func place(
        _ name: String,
        at latitude: Double,
        _ longitude: Double,
        entries: Int = 1,
        in collection: ExperienceCollection,
    ) -> Item {
        let item = Item(name: name)
        item.latitude = latitude
        item.longitude = longitude
        item.collection = collection
        item.entries = (0 ..< entries).map { _ in Entry() }
        return item
    }

    private let london = AtlasRegion(centreLatitude: 51.5, centreLongitude: -0.1, latitudeSpan: 1, longitudeSpan: 1.5)

    private func cafes() -> ExperienceCollection {
        ExperienceCollection(name: "Cafés", kind: .cafes, ratingMode: .ranked)
    }

    @Test func pinsOnlyShowOnceZoomedIn() {
        #expect(!AtlasLogic.showsPins(latitudeSpan: 110))
        #expect(!AtlasLogic.showsPins(latitudeSpan: 30.1))
        #expect(AtlasLogic.showsPins(latitudeSpan: 30))
        #expect(AtlasLogic.showsPins(latitudeSpan: 0.05))
        #expect(!AtlasLogic.showsPins(latitudeSpan: 0))
    }

    @Test func aRegionHoldsWhatIsInViewIncludingAcrossTheDateLine() {
        #expect(london.contains(latitude: 51.5, longitude: -0.1))
        #expect(!london.contains(latitude: 53, longitude: -0.1))
        #expect(!london.contains(latitude: 51.5, longitude: 2))
        let fiji = AtlasRegion(centreLatitude: -17, centreLongitude: 179.5, latitudeSpan: 4, longitudeSpan: 4)
        #expect(fiji.contains(latitude: -17, longitude: -179.5))
        #expect(!fiji.contains(latitude: -17, longitude: -170))
    }

    @Test func aPinNeedsAPositionAndAnEntryAndIsNeverACountry() {
        let cafes = cafes()
        let countries = ExperienceCollection(name: "Countries", kind: .countries, ratingMode: .checklist)
        let shown = place("Monmouth", at: 51.51, -0.09, in: cafes)
        let unvisited = place("Wishlist", at: 51.52, -0.1, entries: 0, in: cafes)
        let stamp = place("United Kingdom", at: 51.5, -0.1, in: countries)
        let unplaced = Item(name: "No position")
        unplaced.collection = cafes
        unplaced.entries = [Entry()]
        let far = place("Paris café", at: 48.85, 2.35, in: cafes)
        let found = AtlasLogic.pins(items: [shown, unvisited, stamp, unplaced, far], in: london)
        #expect(found.map(\.name) == ["Monmouth"])
    }

    @Test func theNearestPinsComeFirstAndTheListIsCapped() {
        let cafes = cafes()
        let near = place("Near", at: 51.5, -0.1, in: cafes)
        let middling = place("Middling", at: 51.6, -0.2, in: cafes)
        let edge = place("Edge", at: 51.95, 0.6, in: cafes)
        let everything = [edge, middling, near]
        #expect(AtlasLogic.pins(items: everything, in: london).map(\.name) == ["Near", "Middling", "Edge"])
        #expect(AtlasLogic.pins(items: everything, in: london, limit: 2).map(\.name) == ["Near", "Middling"])
    }

    @Test func theCardSaysHowOftenAndWhen() {
        let when = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let text = when.formatted(date: .abbreviated, time: .omitted)
        #expect(AtlasLogic.visitLine(entryDates: []) == "Nothing savoured here yet.")
        #expect(AtlasLogic.visitLine(entryDates: [when]) == "Savoured once, \(text)")
        let earlier = when.addingTimeInterval(-86400 * 30)
        #expect(AtlasLogic.visitLine(entryDates: [when, earlier]) == "Savoured 2 times, last \(text)")
    }

    @Test func eachSheetHasItsOwnId() {
        let id = UUID()
        #expect(AtlasSheet.country("PT").id != AtlasSheet.place(id).id)
        #expect(AtlasSheet.place(id) == AtlasSheet.place(id))
    }
}

// MARK: - Filters (#52)

@MainActor
struct AtlasFilterTests {
    private struct Rig {
        let cafes = ExperienceCollection(name: "Cafés", kind: .cafes, ratingMode: .ranked)
        let films = ExperienceCollection(name: "Films", kind: .films, ratingMode: .log)
        let trip = Trip(name: "Japan 2025")
    }

    private func year(_ year: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: 6, day: 15, hour: 12)) ?? .now
    }

    private func entry(
        _ name: String,
        in collection: ExperienceCollection,
        year: Int,
        country: String?,
        trip: Trip? = nil,
    ) -> Entry {
        let item = Item(name: name)
        item.collection = collection
        item.countryCode = country
        let entry = Entry(date: self.year(year))
        entry.item = item
        entry.trip = trip
        item.entries = [entry]
        return entry
    }

    @Test func noFilterPassesEverythingAndCountsNothing() {
        let rig = Rig()
        let any = entry("A", in: rig.cafes, year: 2024, country: "PT")
        #expect(!AtlasFilter().isActive)
        #expect(AtlasFilter().partsOn == 0)
        #expect(AtlasFilter().apply(to: [any]).count == 1)
    }

    @Test func collectionsYearsAndTripEachNarrowTheEntries() {
        let rig = Rig()
        let cafe2025 = entry("Lisbon café", in: rig.cafes, year: 2025, country: "PT")
        let cafe2023 = entry("Old café", in: rig.cafes, year: 2023, country: "PT")
        let film2025 = entry("Perfect Days", in: rig.films, year: 2025, country: "JP", trip: rig.trip)
        let all = [cafe2025, cafe2023, film2025]

        var filter = AtlasFilter()
        filter.toggle(collection: rig.cafes.id)
        #expect(filter.apply(to: all).count == 2)

        filter.setFromYear(2025)
        #expect(filter.apply(to: all).map { $0.item?.name } == ["Lisbon café"])

        var onTrip = AtlasFilter()
        onTrip.trip = rig.trip.id
        #expect(onTrip.apply(to: all).map { $0.item?.name } == ["Perfect Days"])
        #expect(filter.partsOn == 2 && onTrip.partsOn == 1)
    }

    @Test func theYearRangeKeepsItsEndsInOrder() {
        var filter = AtlasFilter()
        filter.setFromYear(2024)
        filter.setToYear(2022)
        #expect(filter.fromYear == 2022 && filter.toYear == 2022)
        filter.setToYear(2025)
        filter.setFromYear(2026)
        #expect(filter.fromYear == 2026 && filter.toYear == 2026)
        filter.setFromYear(nil)
        #expect(filter.toYear == 2026 && filter.isActive)
    }

    @Test func aCollectionCanBeTakenOutAgain() {
        let id = UUID()
        var filter = AtlasFilter()
        filter.toggle(collection: id)
        #expect(filter.isActive)
        filter.toggle(collection: id)
        #expect(!filter.isActive)
    }

    @Test func theInkFollowsTheMatchingEntries() {
        let rig = Rig()
        let lisbon = entry("Lisbon café", in: rig.cafes, year: 2025, country: "pt")
        let tokyo = entry("Perfect Days", in: rig.films, year: 2024, country: "JP")
        let stamp = Item(name: "France")
        stamp.countryCode = "FR"
        let countries = ExperienceCollection(name: "Countries", kind: .countries, ratingMode: .checklist)
        stamp.collection = countries
        let items = [lisbon.item, tokyo.item, stamp].compactMap(\.self)

        // Nothing filtered: the stamped countries, whatever has or hasn't been logged.
        #expect(AtlasLogic.inkedCodes(items: items, entries: [lisbon, tokyo], filter: AtlasFilter()) == ["FR"])
        var films = AtlasFilter()
        films.toggle(collection: rig.films.id)
        #expect(AtlasLogic.inkedCodes(items: items, entries: [lisbon, tokyo], filter: films) == ["JP"])
        var nothing = AtlasFilter()
        nothing.setFromYear(2030)
        #expect(AtlasLogic.inkedCodes(items: items, entries: [lisbon, tokyo], filter: nothing).isEmpty)
    }

    @Test func pinsFollowTheFilterToo() {
        let rig = Rig()
        let old = entry("Old café", in: rig.cafes, year: 2022, country: "GB")
        let recent = entry("New café", in: rig.cafes, year: 2025, country: "GB")
        for entry in [old, recent] {
            entry.item?.latitude = 51.5
            entry.item?.longitude = -0.1
        }
        let region = AtlasRegion(centreLatitude: 51.5, centreLongitude: -0.1, latitudeSpan: 1, longitudeSpan: 1.5)
        let items = [old.item, recent.item].compactMap(\.self)
        #expect(AtlasLogic.pins(items: items, in: region).count == 2)
        var from2024 = AtlasFilter()
        from2024.setFromYear(2024)
        #expect(AtlasLogic.pins(items: items, in: region, filter: from2024).map(\.name) == ["New café"])
    }

    @Test func theYearsAreNewestFirstWithoutRepeats() {
        let rig = Rig()
        let entries = [
            entry("A", in: rig.cafes, year: 2023, country: nil),
            entry("B", in: rig.cafes, year: 2025, country: nil),
            entry("C", in: rig.cafes, year: 2023, country: nil),
        ]
        #expect(AtlasLogic.years(of: entries) == [2025, 2023])
    }

    @Test func theWordsNeverSayZero() {
        #expect(AtlasFilterText.footer(count: 0) == "Showing everything.")
        #expect(AtlasFilterText.footer(count: 1) == "1 filter on.")
        #expect(AtlasFilterText.footer(count: 3) == "3 filters on.")
        #expect(AtlasFilterText.buttonValue(count: 0) == "Off")
        #expect(AtlasLogic.headline(visited: 0, isFiltered: true) == "Nothing matches these filters")
        #expect(AtlasLogic.headline(visited: 0, isFiltered: false) == "Your countries will fill with ink here")
    }
}

// MARK: - Performance (#53)

@MainActor
struct AtlasRingCacheTests {
    @Test func aCountrysRingsAreBuiltOnceAndKept() throws {
        AtlasRingCache.clear()
        let japan = try #require(CountryCatalog.shared.country(code: "JP"))
        #expect(AtlasRingCache.countriesHeld == 0)
        let first = AtlasRingCache.rings(of: japan)
        #expect(AtlasRingCache.countriesHeld == 1)
        let second = AtlasRingCache.rings(of: japan)
        #expect(AtlasRingCache.countriesHeld == 1)
        #expect(first.count == second.count)
        #expect(first.first?.first?.latitude == second.first?.first?.latitude)
        #expect(first.count == AtlasLogic.rings(of: japan).count)
        AtlasRingCache.clear()
        #expect(AtlasRingCache.countriesHeld == 0)
    }

    @Test func fiveThousandPinsAreFilteredToTheViewAndCapped() throws {
        let container = try ArtifactsStore.makeContainer(.inMemory)
        try withExtendedLifetime(container) {
            let repository = Repository(context: container.mainContext)
            try BuiltInCollections.seedIfNeeded(in: repository.context)
            try PreviewData.addStressPlaces(5000, to: repository)
            let items = try repository.context.fetch(FetchDescriptor<Item>())
            // The world is in view, so pins aren't asked for; London on its own is a crowd.
            let london = AtlasRegion(centreLatitude: 51.5, centreLongitude: -0.1, latitudeSpan: 1.5, longitudeSpan: 2)
            let pins = AtlasLogic.pins(items: items, in: london)
            #expect(pins.count == AtlasLogic.pinLimit)
            #expect(pins.allSatisfy { london.contains(latitude: $0.latitude ?? 0, longitude: $0.longitude ?? 0) })
            // Zoomed in on one street, there's room for them all.
            let street = AtlasRegion(centreLatitude: 51.5, centreLongitude: -0.1, latitudeSpan: 0.02, longitudeSpan: 0.03)
            #expect(AtlasLogic.pins(items: items, in: street).count < AtlasLogic.pinLimit)
        }
    }
}
