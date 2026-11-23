import CoreGraphics
import Geo
import Testing
@testable import Features

@MainActor
struct InkWorldMapTests {
    let world = InkWorld.shared

    /// Where `point` lands in the map's unit space, using the same crop as the map.
    private func unit(_ point: GeoPoint) -> CGPoint {
        let top = Robinson.project(GeoPoint(longitude: 0, latitude: InkWorld.north)).y
        let bottom = Robinson.project(GeoPoint(longitude: 0, latitude: InkWorld.south)).y
        let projected = Robinson.project(point)
        return CGPoint(x: (projected.x + 1) / 2, y: (top - projected.y) / (top - bottom))
    }

    @Test func everyCountryButAntarcticaIsDrawn() {
        let codes = Set(world.countries.map(\.code))
        #expect(codes.count == CountryCatalog.shared.countries.count - 1)
        #expect(!codes.contains("AQ"))
    }

    @Test func theCroppedMapIsWiderThanTall() {
        #expect(world.aspectRatio > 2 && world.aspectRatio < 2.6)
    }

    @Test(arguments: [
        (2.35, 48.86, "FR"),
        (139.69, 35.68, "JP"),
        (-47.9, -15.8, "BR"),
        (36.82, -1.29, "KE"),
        (77.2, 28.6, "IN"),
    ])
    func tappingAPointFindsItsCountry(longitude: Double, latitude: Double, code: String) {
        #expect(world.code(atUnit: unit(GeoPoint(longitude: longitude, latitude: latitude))) == code)
    }

    @Test func tappingTheSeaFindsNothing() {
        #expect(world.code(atUnit: unit(GeoPoint(longitude: -30, latitude: 30))) == nil)
    }

    @Test func voiceOverHearsWhatsInked() {
        #expect(InkWorldMap.summary(visited: []) == "World map, no countries inked yet")
        #expect(InkWorldMap.summary(visited: ["PT", "JP"]) == "World map, 2 countries inked: Japan and Portugal")
    }
}
