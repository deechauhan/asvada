import Testing
@testable import Geo

struct CountryCatalogTests {
    let catalog = CountryCatalog.shared

    @Test func bundlesEveryCountryOnce() {
        #expect(catalog.countries.count >= 230)
        #expect(Set(catalog.countries.map(\.code)).count == catalog.countries.count)
        let allHaveOutlines = catalog.countries.allSatisfy { !$0.outlines.isEmpty }
        #expect(allHaveOutlines)
    }

    @Test func codesNaturalEarthLeavesBlankAreFilledIn() {
        #expect(catalog.country(code: "FR")?.name == "France")
        #expect(catalog.country(code: "no")?.name == "Norway")
        #expect(catalog.country(code: "XK")?.name == "Kosovo")
        #expect(catalog.country(code: "US")?.name == "United States")
    }

    @Test func flagsComeFromTheCode() {
        #expect(Country.flag(for: "JP") == "🇯🇵")
        #expect(catalog.country(code: "PT")?.flag == "🇵🇹")
        #expect(Country.flag(for: "J").isEmpty)
    }

    @Test(arguments: [
        ("Paris", 2.35, 48.86, "FR"),
        ("Tokyo", 139.69, 35.68, "JP"),
        ("London", -0.13, 51.51, "GB"),
        ("Sydney", 151.21, -33.87, "AU"),
        ("Nairobi", 36.82, -1.29, "KE"),
        ("Lima", -77.04, -12.05, "PE"),
    ])
    func findsTheCountryAtAPoint(city: String, longitude: Double, latitude: Double, code: String) {
        let point = GeoPoint(longitude: longitude, latitude: latitude)
        #expect(catalog.country(containing: point)?.code == code, "\(city)")
    }

    @Test func theOpenSeaIsNoCountry() {
        #expect(catalog.country(containing: GeoPoint(longitude: -30, latitude: 30)) == nil)
    }

    @Test func searchIgnoresCaseAndAccentsAndPrefersPrefixes() {
        #expect(catalog.search("jap").first?.code == "JP")
        #expect(Array(catalog.search("UNITED").map(\.code).prefix(3)) == ["AE", "GB", "US"])
        #expect(catalog.search("curacao").first?.code == "CW")
        #expect(catalog.search("ind").first?.code == "IN")
        #expect(catalog.search("jpn").first?.code == "JP")
        #expect(catalog.search("  ").count == catalog.countries.count)
    }

    @Test func everyContinentIsRepresented() {
        #expect(Set(catalog.byContinent.keys) == Set(Continent.allCases))
    }

    @Test func rayCastingHandlesASquare() {
        let square = [
            GeoPoint(longitude: 0, latitude: 0),
            GeoPoint(longitude: 10, latitude: 0),
            GeoPoint(longitude: 10, latitude: 10),
            GeoPoint(longitude: 0, latitude: 10),
        ]
        #expect(Country.ring(square, contains: GeoPoint(longitude: 5, latitude: 5)))
        #expect(!Country.ring(square, contains: GeoPoint(longitude: 15, latitude: 5)))
    }
}
