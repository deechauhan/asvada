import Testing
@testable import Geo

/// Border, enclave and island cases for finding the country a place is in, offline.
struct CountryLookupTests {
    let catalog = CountryCatalog.shared

    @Test(arguments: [
        // Either side of land borders.
        ("Geneva", 6.14, 46.20, "CH"),
        ("Basel", 7.59, 47.56, "CH"),
        ("Strasbourg", 7.75, 48.58, "FR"),
        ("Kehl", 7.83, 48.57, "DE"),
        ("Detroit", -83.05, 42.33, "US"),
        ("Windsor", -83.02, 42.30, "CA"),
        ("El Paso", -106.30, 31.80, "US"),
        ("Ciudad Juárez", -106.42, 31.67, "MX"),
        ("La Línea", -5.35, 36.17, "ES"),
        ("Nice", 7.26, 43.70, "FR"),
        // Enclaves: inside another country's outer outline, so the smallest container wins.
        ("Maseru", 27.48, -29.31, "LS"),
        ("San Marino", 12.45, 43.94, "SM"),
        ("Rome", 12.50, 41.89, "IT"),
    ])
    func landPointsFindTheirCountry(place: String, longitude: Double, latitude: Double, code: String) {
        let point = GeoPoint(longitude: longitude, latitude: latitude)
        #expect(catalog.country(at: point)?.code == code, "\(place)")
    }

    @Test(arguments: [
        // Islands and harbours, some of which sit just off the simplified coastline.
        ("Honolulu", -157.86, 21.31, "US"),
        ("Reykjavík", -21.94, 64.15, "IS"),
        ("Malé", 73.509, 4.175, "MV"),
        ("Valletta", 14.51, 35.90, "MT"),
        ("Singapore", 103.82, 1.35, "SG"),
        ("Hong Kong", 114.17, 22.32, "HK"),
        ("Suva", 178.44, -18.14, "FJ"),
        ("Nukuʻalofa", -175.20, -21.14, "TO"),
        ("Tromsø", 18.96, 69.65, "NO"),
        ("Funchal", -16.91, 32.65, "PT"),
        ("Palma", 2.65, 39.57, "ES"),
        ("Monaco", 7.42, 43.74, "MC"),
    ])
    func islandsAndHarboursFindTheirCountry(place: String, longitude: Double, latitude: Double, code: String) {
        let point = GeoPoint(longitude: longitude, latitude: latitude)
        #expect(catalog.country(at: point)?.code == code, "\(place)")
    }

    @Test(arguments: [(-30.0, 30.0), (-150.0, -30.0), (-1.0, 50.2)])
    func theOpenSeaIsNoCountry(longitude: Double, latitude: Double) {
        #expect(catalog.country(at: GeoPoint(longitude: longitude, latitude: latitude)) == nil)
    }

    @Test func distanceToACoastIsMeasuredInKilometres() throws {
        let portugal = try #require(catalog.country(code: "PT"))
        // Funchal's harbour is within a couple of kilometres of Madeira's simplified coast.
        #expect(portugal.distanceInKilometres(to: GeoPoint(longitude: -16.91, latitude: 32.65)) < 5)
        #expect(portugal.distanceInKilometres(to: GeoPoint(longitude: -30, latitude: 30)) > 500)
    }
}
