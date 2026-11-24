import Geo
import MapKit
import Testing
@testable import Sources

struct PlaceSearchTests {
    @Test func countryComesFromTheCoordinatesOffline() {
        let prufrock = PlaceResult(name: "Prufrock Coffee", latitude: 51.5204, longitude: -0.1094)
        #expect(prufrock.countryCode == "GB")
        let pasteis = PlaceResult(name: "Pastéis de Belém", latitude: 38.6975, longitude: -9.2032)
        #expect(pasteis.countryCode == "PT")
        // A code MapKit gave wins.
        let given = PlaceResult(name: "Somewhere", latitude: 51.52, longitude: -0.11, countryCode: "IE")
        #expect(given.countryCode == "IE")
    }

    @Test func externalRefsPreferMapKitIdentifiers() {
        let known = PlaceResult(name: "Prufrock Coffee", latitude: 51.5204, longitude: -0.1094, mapItemIdentifier: "I1234")
        #expect(known.externalRef == "mk:I1234")
        let bare = PlaceResult(name: " Prufrock Coffee", latitude: 51.52041, longitude: -0.10943)
        #expect(bare.externalRef == "place:prufrock coffee@51.5204,-0.1094")
        // The same café found twice, a few metres apart, is the same item.
        let again = PlaceResult(name: "Prufrock Coffee", latitude: 51.52038, longitude: -0.10939)
        #expect(again.externalRef == bare.externalRef)
    }

    @Test func nearbyResultsAreOrderedByDistance() {
        let here = GeoPoint(longitude: -0.1094, latitude: 51.5204)
        let far = PlaceResult(name: "Far", latitude: 51.60, longitude: -0.20)
        let near = PlaceResult(name: "Near", latitude: 51.521, longitude: -0.109)
        let middle = PlaceResult(name: "Middle", latitude: 51.53, longitude: -0.12)
        let ordered = MapKitPlaceSearch.nearestFirst([far, near, middle], to: here)
        #expect(ordered.map(\.name) == ["Near", "Middle", "Far"])
    }

    @Test func distancesAreRoughlyRight() {
        // Clerkenwell to the British Museum: about 1.2 km.
        let clerkenwell = GeoPoint(longitude: -0.1094, latitude: 51.5204)
        let museum = PlaceResult(name: "British Museum", latitude: 51.5194, longitude: -0.1270)
        let distance = MapKitPlaceSearch.kilometres(from: clerkenwell, to: museum)
        #expect(distance > 1.1 && distance < 1.4)
    }

    @Test func blankQueriesFindNothingWithoutSearching() async throws {
        let results = try await MapKitPlaceSearch().search("   ", kind: .cafe, near: nil)
        #expect(results.isEmpty)
    }

    @Test func kindsFilterByCategory() {
        let cafes = PlaceKind.cafe.categories ?? []
        let restaurants = PlaceKind.restaurant.categories ?? []
        #expect(cafes.contains(.cafe))
        #expect(restaurants.contains(.restaurant))
        #expect(PlaceKind.any.categories == nil)
        #expect(PlaceKind.city.categories == nil)
    }
}
