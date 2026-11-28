import XCTest

/// The Atlas tab (#49): a world map that fills with plum ink as countries are stamped.
final class AtlasUITests: UITestCase {
    @MainActor
    func testTheAtlasFillsWithTheCountriesYouStamp() {
        let app = launch(["-resetState"])
        // Nothing stamped: a ghost line, never a bare 0.
        app.tabBars.buttons["Atlas"].tap()
        let headline = app.staticTexts["atlasHeadline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 10), "No headline over the Atlas")
        XCTAssertEqual(headline.label, "Your countries will fill with ink here")
        attachScreenshot(of: app, named: "atlas-empty")

        // Stamp Japan in the Countries drawer; the Atlas counts it.
        openCollectionsAndWait(app)
        openDrawer(app, "Countries")
        let search = app.textFields["stampSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Japan\n")
        XCTAssertTrue(labelled("1 of 195 countries, 1 percent", in: app).waitForExistence(timeout: 5))
        app.navigationBars["Countries"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Countries"].waitForNonExistence(timeout: 10))

        app.tabBars.buttons["Atlas"].tap()
        XCTAssertTrue(app.staticTexts["atlasHeadline"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["atlasHeadline"].label, "1 country · 1% of the world")
        attachScreenshot(of: app, named: "atlas-japan")
    }

    @MainActor
    func testTheFilterSheetNarrowsTheMapAndResets() {
        let app = launch(["-resetState"])
        app.tabBars.buttons["Atlas"].tap()
        let button = app.buttons["atlasFilterButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "No filter button on the Atlas")
        XCTAssertEqual(button.value as? String, "Off")
        button.tap()

        // Pick a collection: one filter on, and the map says nothing matches.
        let cafes = app.buttons["atlasFilterCollection-Cafés"]
        XCTAssertTrue(cafes.waitForExistence(timeout: 5))
        let footer = app.staticTexts["atlasFilterStatus"]
        XCTAssertEqual(footer.label, "Showing everything.")
        cafes.tap()
        XCTAssertEqual(footer.label, "1 filter on.")
        attachScreenshot(of: app, named: "atlas-filters")

        // Reset puts it back.
        app.buttons["atlasFilterReset"].tap()
        XCTAssertEqual(footer.label, "Showing everything.")
        cafes.tap()
        app.buttons["atlasFilterDone"].tap()
        XCTAssertTrue(app.staticTexts["atlasHeadline"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["atlasHeadline"].label, "Nothing matches these filters")
        XCTAssertEqual(button.value as? String, "1 filter on.")
    }
}
