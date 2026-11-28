import Foundation
import Model
import SwiftData
import Testing
@testable import Storage

@MainActor
struct CountryStampTests {
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try ArtifactsStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
    }

    private func collection(_ kind: CollectionKind) throws -> ExperienceCollection {
        let match = try repository.collections().first { $0.kind == kind }
        return try #require(match)
    }

    private func place(_ name: String, longitude: Double, latitude: Double, in kind: CollectionKind) throws -> Item {
        let item = try repository.upsertItem(named: name, externalRef: "mk:\(name)", in: collection(kind))
        item.longitude = longitude
        item.latitude = latitude
        return item
    }

    @Test func loggingAPlaceStampsItsCountry() throws {
        let cafe = try place("Copenhagen Coffee Lab", longitude: -9.14, latitude: 38.71, in: .cafes)
        repository.addEntry(to: cafe)
        try repository.save()
        #expect(cafe.countryCode == "PT")
        let countries = try collection(.countries).items ?? []
        #expect(countries.map(\.name) == ["Portugal"])
        #expect(countries.first?.externalRef == "iso:PT")
        #expect(countries.first?.entries?.count == 1)
    }

    @Test func aSecondPlaceTheSameDayDoesntStampTwice() throws {
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        let shibuya = try place("A", longitude: 139.70, latitude: 35.66, in: .cafes)
        let ginza = try place("B", longitude: 139.77, latitude: 35.68, in: .restaurants)
        let kyoto = try place("C", longitude: 135.77, latitude: 35.01, in: .cities)
        repository.addEntry(to: shibuya, date: day)
        repository.addEntry(to: ginza, date: day)
        repository.addEntry(to: kyoto, date: day.addingTimeInterval(86400 * 3))
        try repository.save()
        let japan = try collection(.countries).items?.first { $0.countryCode == "JP" }
        #expect(japan?.entries?.count == 2)
        #expect(japan?.entries?.map(\.date).min() == day)
    }

    @Test func anItemsOwnCountryCodeWins() throws {
        let item = try repository.upsertItem(named: "Somewhere", externalRef: nil, in: collection(.cities))
        item.countryCode = "pe"
        repository.addEntry(to: item)
        let countries = try collection(.countries).items ?? []
        #expect(countries.first?.countryCode == "PE")
    }

    @Test func placesAtSeaAndItemsWithoutAPlaceStampNothing() throws {
        let ferryBar = try place("Ferry bar", longitude: -30, latitude: 30, in: .restaurants)
        repository.addEntry(to: ferryBar)
        let film = try repository.upsertItem(named: "Perfect Days", externalRef: nil, in: collection(.films))
        repository.addEntry(to: film)
        try repository.save()
        let countries = try collection(.countries).items ?? []
        #expect(countries.isEmpty)
    }

    @Test func countriesDontStampThemselvesAgain() throws {
        let japan = try repository.upsertItem(named: "Japan", externalRef: "iso:JP", in: collection(.countries))
        japan.countryCode = "JP"
        repository.addEntry(to: japan)
        try repository.save()
        let countries = try collection(.countries).items ?? []
        #expect(countries.count == 1)
        #expect(japan.entries?.count == 1)
    }

    @Test func theStampPadSetsExactlyTheCountriesTicked() throws {
        let countries = try collection(.countries)
        try repository.setStamped(["JP", "pt"], in: countries)
        #expect(repository.stampedCodes(in: countries) == ["JP", "PT"])
        #expect(countries.items?.map(\.name).sorted() == ["Japan", "Portugal"])

        // Ticking one more and washing one off.
        try repository.setStamped(["PT", "BR"], in: countries)
        #expect(repository.stampedCodes(in: countries) == ["PT", "BR"])
        let japan = FetchDescriptor<Item>(predicate: #Predicate { $0.name == "Japan" })
        #expect(try container.mainContext.fetchCount(japan) == 0)
    }

    @Test func stampingAgainKeepsOneItemAndItsVisits() throws {
        let countries = try collection(.countries)
        // Lisbon café stamps Portugal with a dated visit.
        try repository.addEntry(to: place("Pastéis de Belém", longitude: -9.2032, latitude: 38.6975, in: .cafes))
        let portugal = try #require(countries.items?.first { $0.countryCode == "PT" })
        try repository.setStamped(["PT", "ES"], in: countries)
        #expect(countries.items?.filter { $0.countryCode == "PT" }.count == 1)
        #expect(portugal.entries?.count == 1, "re-stamping must not drop Portugal's visit")
    }

    @Test func unknownCodesAreIgnored() throws {
        let countries = try collection(.countries)
        try repository.setStamped(["ZZ"], in: countries)
        #expect(repository.stampedCodes(in: countries).isEmpty)
    }
}
