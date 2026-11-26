import XCTest

/// Look back (#68): stats for everything and each drawer, from the Collections toolbar.
final class StatsUITests: UITestCase {
    @MainActor
    func testLookBackShowsTheNumbersTheChartAndEachDrawer() {
        let app = launch(["-resetState", "-sampleData"])
        openCollectionsAndWait(app)
        let more = app.buttons["statsButton"]
        if !more.waitForExistence(timeout: 3) {
            // A secondary action can sit in the toolbar's overflow menu.
            app.navigationBars["Collections"].buttons["More"].tap()
        }
        XCTAssertTrue(more.waitForExistence(timeout: 5), "No way to look back from Collections")
        more.tap()
        XCTAssertTrue(app.navigationBars["Look back"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["monthsChart"].waitForExistence(timeout: 5), "No months chart")
        XCTAssertTrue(app.descendants(matching: .any)["drawerStats"].firstMatch.exists, "No drawer stats")
        attachScreenshot(of: app, named: "look-back")
    }
}
