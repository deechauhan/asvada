import Testing
@testable import Sources

struct AirlineCatalogTests {
    let catalog = AirlineCatalog.shared

    @Test func bundlesActiveAirlinesWithIataCodes() {
        #expect(catalog.airlines.count > 800)
        let allHaveCodes = catalog.airlines.allSatisfy { $0.iata.count == 2 }
        #expect(allHaveCodes)
    }

    @Test func looksUpByIataPreferringThePassengerAirline() {
        #expect(catalog.airline(iata: "ba")?.name == "British Airways")
        #expect(catalog.airline(iata: "BA")?.icao == "BAW")
        #expect(catalog.airline(iata: "BA")?.country == "GB")
        let lufthansa = catalog.airline(iata: "LH")
        #expect(lufthansa?.isPassengerAirline == true)
        #expect(catalog.airline(iata: "ZZ9") == nil)
    }

    @Test func searchFindsByCodeNameAndIgnoresCase() {
        #expect(catalog.search("EK").first?.name == "Emirates")
        #expect(catalog.search("baw").first?.iata == "BA")
        #expect(catalog.search("qantas").first?.iata == "QF")
        #expect(catalog.search("swiss").contains { $0.iata == "LX" })
        #expect(catalog.search("   ").count == catalog.airlines.count)
    }

    @Test func countriesAreIsoCodes() {
        let codes = catalog.airlines.compactMap(\.country)
        let allTwoLetters = codes.allSatisfy { $0.count == 2 && $0 == $0.uppercased() }
        #expect(allTwoLetters)
        #expect(Double(codes.count) / Double(catalog.airlines.count) > 0.95)
    }
}
