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
        let container = try AsvadaStore.makeContainer(.inMemory)
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
