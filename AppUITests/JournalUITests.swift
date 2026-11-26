import XCTest

/// The Journal feed: sealed keepsakes under month mastheads, newest first.
final class JournalUITests: UITestCase {
    @MainActor
    func testTheJournalListsKeepsakesUnderTheirMonths() {
        let app = launch(["-resetState", "-sampleData"])
        XCTAssertTrue(app.tabBars.buttons["Journal"].waitForExistence(timeout: 10))
        let month = app.descendants(matching: .any)["journalMonth"].firstMatch
        XCTAssertTrue(month.waitForExistence(timeout: 10), "No month masthead in the Journal")
        XCTAssertFalse(app.staticTexts["your first keepsake"].exists, "The empty Journal is still showing")
        attachScreenshot(of: app, named: "journal-feed")

        // Tap a keepsake: its thing's page.
        let entry = app.descendants(matching: .any)["journalEntry"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "No keepsake in the Journal")
        entry.tap()
        XCTAssertTrue(app.staticTexts["itemCount"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testASealedKeepsakeLandsInTheJournal() {
        let app = launch(["-resetState"])
        XCTAssertTrue(app.staticTexts["your first keepsake"].waitForExistence(timeout: 10))

        app.buttons["start-films"].tap()
        XCTAssertTrue(app.textFields["quickLogName"].waitForExistence(timeout: 10))
        addNew("Perfect Days", in: app)
        XCTAssertTrue(app.staticTexts["When?"].waitForExistence(timeout: 5))
        app.buttons["when-Today"].tap()
        seal(app, drawer: "Films")

        // The first keepsake replaces the empty Journal.
        XCTAssertTrue(app.descendants(matching: .any)["journalEntry"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["journalMonth"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["your first keepsake"].exists)
    }
}
