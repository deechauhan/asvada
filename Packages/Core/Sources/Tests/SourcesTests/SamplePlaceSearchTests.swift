import Geo
import Testing
@testable import Sources

struct SamplePlaceSearchTests {
    private let search = SamplePlaceSearch()

    @Test func typingFindsSamplesByName() async throws {
        let found = try await search.search("coffee", kind: .cafe, near: nil)
        #expect(found.map(\.name) == ["Monmouth Coffee", "Prufrock Coffee", "Workshop Coffee", "Origin Coffee"])
        #expect(try await search.search("  ", kind: .cafe, near: nil).isEmpty)
    }

    @Test func searchingThisAreaWithNothingTypedFindsEveryPlaceOfThatKind() async throws {
        // "Search this area" asks for the kind's own word.
        let cafes = try await search.search(PlaceKind.cafe.searchWord, kind: .cafe, near: nil)
        #expect(cafes.count == SamplePlaceSearch.places[.cafe]?.count)
        let restaurants = try await search.search("Restaurant", kind: .restaurant, near: nil)
        #expect(restaurants.map(\.name).contains("Padella"))
    }

    @Test func tappingNearACityFindsIt() async throws {
        // A little north of central Lisbon.
        let lisbon = try await search.city(at: GeoPoint(longitude: -9.15, latitude: 38.76))
        #expect(lisbon?.name == "Lisbon")
        // The middle of the Atlantic is no city at all.
        #expect(try await search.city(at: GeoPoint(longitude: -30, latitude: 40)) == nil)
    }

    @Test func eachKindHasAWordToSearchFor() {
        for kind in PlaceKind.allCases {
            #expect(!kind.searchWord.isEmpty)
        }
        #expect(PlaceKind.cafe.searchWord == "café")
    }

    @Test func placeSearchesWithoutACityLookupFindNone() async throws {
        struct NoCities: PlaceSearching {
            func search(_: String, kind _: PlaceKind, near _: GeoPoint?) async throws -> [PlaceResult] {
                []
            }
        }
        #expect(try await NoCities().city(at: GeoPoint(longitude: 0, latitude: 51.5)) == nil)
    }
}
