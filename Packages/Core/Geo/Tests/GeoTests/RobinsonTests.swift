import Testing
@testable import Geo

struct RobinsonTests {
    @Test func theOriginStaysAtTheCentre() {
        let origin = Robinson.project(GeoPoint(longitude: 0, latitude: 0))
        #expect(origin.x == 0)
        #expect(origin.y == 0)
    }

    @Test func theEquatorSpansTheWidth() {
        #expect(Robinson.project(GeoPoint(longitude: 180, latitude: 0)).x == 1)
        #expect(Robinson.project(GeoPoint(longitude: -180, latitude: 0)).x == -1)
    }

    @Test func thePolesAreFlatLinesShorterThanTheEquator() {
        let pole = Robinson.project(GeoPoint(longitude: 180, latitude: 90))
        #expect(abs(pole.y - Robinson.aspect) < 1e-9)
        #expect(abs(pole.x - 0.5322) < 1e-9)
    }

    @Test func southMirrorsNorth() {
        let north = Robinson.project(GeoPoint(longitude: 30, latitude: 47))
        let south = Robinson.project(GeoPoint(longitude: 30, latitude: -47))
        #expect(north.x == south.x)
        #expect(north.y == -south.y)
    }

    @Test func latitudeRisesSteadily() {
        let heights = stride(from: 0.0, through: 90, by: 2.5).map { Robinson.project(GeoPoint(longitude: 0, latitude: $0)).y }
        let increasing = zip(heights, heights.dropFirst()).allSatisfy { $0 < $1 }
        #expect(increasing)
    }
}
