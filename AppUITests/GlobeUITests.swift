import XCTest

/// The ink globe in the Countries drawer: spin it, fly to a country by name, stamp the one in
/// the ring, unroll it into the flat map and roll it back up.
final class GlobeUITests: UITestCase {
    @MainActor
    func testTheGlobeSpinsFliesStampsAndUnrolls() {
        let app = launch(["-resetState"])
        openCollectionsAndWait(app)
        openDrawer(app, "Countries")

        let globe = app.descendants(matching: .any)["inkGlobe"]
        XCTAssertTrue(globe.waitForExistence(timeout: 10))
        XCTAssertEqual(globe.label, "World map, no countries inked yet")
        // A fling coasts, then the magnet pulls a country into the ring.
        globe.swipeLeft()
        attachScreenshot(of: app, named: "globe-spun")

        // Type a name and the globe flies there; the ring aims at it.
        let search = app.textFields["stampSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Peru")
        XCTAssertTrue(labelled("Aimed at Peru", in: app).waitForExistence(timeout: 5))

        // Stamp the one in the ring.
        let stamp = app.buttons["globeStamp"]
        XCTAssertTrue(stamp.waitForExistence(timeout: 5))
        stamp.tap()
        XCTAssertTrue(labelled("1 of 195 countries, 1 percent", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(labelled("World map, 1 country inked: Peru", in: app).waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "globe-stamped")

        // Unroll it into the flat map, then roll it back up.
        app.buttons["unrollGlobe"].tap()
        let map = app.descendants(matching: .any)["inkWorldMap"]
        XCTAssertTrue(map.waitForExistence(timeout: 5))
        XCTAssertEqual(map.label, "World map, 1 country inked: Peru")
        attachScreenshot(of: app, named: "globe-unrolled")
        app.buttons["rollUpGlobe"].tap()
        XCTAssertTrue(globe.waitForExistence(timeout: 5))
    }
}
