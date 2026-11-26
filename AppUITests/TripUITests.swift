import XCTest

/// Trips (#66): plan one from the Journal, and open its page.
final class TripUITests: UITestCase {
    @MainActor
    func testATripIsPlannedAndOpened() {
        let app = launch(["-resetState", "-sampleData"])
        let trips = app.buttons["tripsButton"]
        XCTAssertTrue(trips.waitForExistence(timeout: 10), "No way to reach trips from the Journal")
        trips.tap()
        XCTAssertTrue(app.navigationBars["Trips"].waitForExistence(timeout: 5))
        let plan = app.buttons["planTripButton"]
        XCTAssertTrue(plan.waitForExistence(timeout: 5), "No empty state to start a trip from")
        attachScreenshot(of: app, named: "trips-empty")
        plan.tap()

        let name = app.textFields["tripNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Lisbon in June")
        attachScreenshot(of: app, named: "trip-editor")
        app.buttons["saveTripButton"].tap()
        XCTAssertTrue(app.buttons["saveTripButton"].waitForNonExistence(timeout: 10))

        let row = app.buttons["tripRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The new trip isn't listed")
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tripPage"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Lisbon in June"].exists)
        attachScreenshot(of: app, named: "trip-page")
    }
}
