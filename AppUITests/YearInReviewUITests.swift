import XCTest

/// Year in review (#70): the Tasting Menu, from Look back.
final class YearInReviewUITests: UITestCase {
    @MainActor
    func testTheYearIsServedAsATastingMenu() {
        let app = launch(["-resetState", "-sampleData"])
        openCollectionsAndWait(app)
        let stats = app.buttons["statsButton"]
        if !stats.waitForExistence(timeout: 3) {
            app.navigationBars["Collections"].buttons["More"].tap()
        }
        XCTAssertTrue(stats.waitForExistence(timeout: 5))
        stats.tap()
        let link = app.buttons["yearInReviewLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 10), "No way to the year in review from Look back")
        link.tap()
        XCTAssertTrue(app.navigationBars["The Tasting Menu"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["The Tasting Menu"].firstMatch.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "tasting-menu-cover")
        app.swipeLeft()
        attachScreenshot(of: app, named: "tasting-menu-course")
    }
}
