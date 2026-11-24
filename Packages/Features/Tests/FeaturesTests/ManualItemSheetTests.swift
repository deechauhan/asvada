import Geo
import Model
import Storage
import Testing
@testable import Features

@MainActor
struct ManualItemSheetTests {
    @Test(arguments: [
        (ItemSource.mapkit, true),
        (ItemSource.manual, true),
        (ItemSource.tmdb, false),
        (ItemSource.airlineCatalog, false),
        (ItemSource.countryCatalog, false),
    ])
    func onlyPlacesAndCustomCollectionsAskWhere(source: ItemSource, takesLocation: Bool) {
        #expect(ExperienceCollection(name: "Test", itemSource: source).takesLocation == takesLocation)
    }

    @Test func aCollectionWithNoPinsStartsTheMapNowhere() {
        #expect(ExperienceCollection(name: "Cafés", itemSource: .mapkit).lastPinnedPoint == nil)
    }

    @Test func thePinSummarySaysWhereItIs() {
        #expect(PinSummary.summary(for: ManualItemDraft(name: "Kiosk")) == "Tap the map to pin where it is")
        let lisbon = ManualItemDraft(name: "Kiosk", location: GeoPoint(longitude: -9.14, latitude: 38.71))
        #expect(PinSummary.summary(for: lisbon) == "Pinned in Portugal")
        let atSea = ManualItemDraft(name: "Ferry bar", location: GeoPoint(longitude: -30, latitude: 30))
        #expect(PinSummary.summary(for: atSea) == "Pinned at 30.00, -30.00")
    }
}
