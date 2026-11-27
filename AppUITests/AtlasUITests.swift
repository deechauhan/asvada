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
}
