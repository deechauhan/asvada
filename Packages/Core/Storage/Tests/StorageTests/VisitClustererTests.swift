import Foundation
import Geo
import Testing
@testable import Storage

struct VisitClustererTests {
    private let lisbon = GeoPoint(longitude: -9.14, latitude: 38.72)
    private let sintra = GeoPoint(longitude: -9.38, latitude: 38.80)
    private let tokyo = GeoPoint(longitude: 139.69, latitude: 35.68)
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func shots(
        _ prefix: String,
        at point: GeoPoint,
        from first: TimeInterval,
        count: Int,
        every gap: TimeInterval = 3600,
    ) -> [PhotoSighting] {
        (0 ..< count).map { index in
            PhotoSighting(
                id: "\(prefix)\(index)",
                date: start.addingTimeInterval(first + Double(index) * gap),
                point: GeoPoint(longitude: point.longitude + Double(index) * 0.001, latitude: point.latitude),
            )
        }
    }

    @Test func photosInOnePlaceOverAFewDaysAreOneVisitInItsCountry() throws {
        let photos = shots("a", at: lisbon, from: 0, count: 30, every: 4 * 3600)
        let visits = VisitClusterer.clusters(from: photos)
        let visit = try #require(visits.first)
        #expect(visits.count == 1)
        #expect(visit.photoCount == 30)
        #expect(visit.countryCode == "PT")
        #expect(visit.countryName == "Portugal")
        #expect(visit.start == photos.first?.date)
        #expect(visit.end == photos.last?.date)
        #expect(visit.id == "a0")
    }

    @Test func aLongGapSplitsAVisit() {
        let first = shots("a", at: lisbon, from: 0, count: 5)
        let second = shots("b", at: lisbon, from: 5 * 86400, count: 5)
        #expect(VisitClusterer.clusters(from: first + second).count == 2)
    }

    @Test func aDayTripFarAwaySplitsAVisit() {
        // Lisbon to Sintra is about 20 km: the same visit. Lisbon to Tokyo within hours is not.
        let near = shots("a", at: lisbon, from: 0, count: 4) + shots("b", at: sintra, from: 5 * 3600, count: 4)
        #expect(VisitClusterer.clusters(from: near).count == 1)
        let far = shots("a", at: lisbon, from: 0, count: 4) + shots("t", at: tokyo, from: 5 * 3600, count: 4)
        let visits = VisitClusterer.clusters(from: far)
        #expect(visits.map(\.countryCode) == ["PT", "JP"])
    }

    @Test func tooFewPhotosIsNotAVisit() {
        #expect(VisitClusterer.clusters(from: shots("a", at: lisbon, from: 0, count: VisitClusterer.minimumPhotos - 1)).isEmpty)
        #expect(VisitClusterer.clusters(from: []).isEmpty)
    }

    @Test func photosInAnyOrderGiveTheSameVisits() {
        let photos = shots("a", at: lisbon, from: 0, count: 6) + shots("t", at: tokyo, from: 10 * 86400, count: 6)
        let shuffled = Array(photos.reversed())
        #expect(VisitClusterer.clusters(from: shuffled) == VisitClusterer.clusters(from: photos))
        #expect(VisitClusterer.clusters(from: photos).map(\.id) == ["a0", "t0"])
    }

    @Test func aVisitOffersAFewSamplesSpreadThroughIt() throws {
        let photos = shots("a", at: lisbon, from: 0, count: 40)
        let visit = try #require(VisitClusterer.clusters(from: photos).first)
        #expect(visit.sampleIDs.count == VisitClusterer.sampleCount)
        #expect(visit.sampleIDs.first == "a0")
        #expect(visit.sampleIDs.last == "a39")
        let few = try #require(VisitClusterer.clusters(from: shots("b", at: lisbon, from: 0, count: 3)).first)
        #expect(few.sampleIDs == ["b0", "b1", "b2"])
    }

    @Test func aVisitAtSeaHasNoCountry() throws {
        let sea = GeoPoint(longitude: -30, latitude: 35)
        let visit = try #require(VisitClusterer.clusters(from: shots("s", at: sea, from: 0, count: 4)).first)
        #expect(visit.countryCode == nil)
        #expect(visit.countryName == nil)
    }

    @Test func distancesAreAboutRight() {
        // Lisbon to Sintra is roughly 20 km; London to Paris roughly 344 km.
        #expect(abs(VisitClusterer.kilometres(from: lisbon, to: sintra) - 20) < 5)
        let london = GeoPoint(longitude: -0.1276, latitude: 51.5072)
        let paris = GeoPoint(longitude: 2.3522, latitude: 48.8566)
        #expect(abs(VisitClusterer.kilometres(from: london, to: paris) - 344) < 10)
    }
}
