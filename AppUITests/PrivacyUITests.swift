import XCTest

/// Privacy and Delete all data (#60), both under Settings.
final class PrivacyUITests: UITestCase {
    @MainActor
    func testThePrivacyPageSaysWhatLeavesThePhone() {
        let app = launch(["-resetState"])
        openSettings(app)
        let link = app.buttons["privacyLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 10), "No privacy page in Settings")
        link.tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 5))
        for source in ["tmdb", "apple-maps", "natural-earth"] {
            XCTAssertTrue(
                app.descendants(matching: .any)["privacy-\(source)"].waitForExistence(timeout: 5),
                "\(source) isn't on the privacy page",
            )
        }
        attachScreenshot(of: app, named: "privacy")
    }

    @MainActor
    func testDeleteAllDataAsksTwiceThenDeletes() {
        let app = launch(["-resetState", "-sampleData"])
        openSettings(app)
        let link = app.buttons["deleteDataLink"]
        // The list is long (the Lock section sits above this row), so scroll down to it.
        for _ in 0 ..< 6 where !link.exists {
            app.swipeUp()
        }
        XCTAssertTrue(link.waitForExistence(timeout: 10), "No way to delete data in Settings")
        link.tap()
        let delete = app.buttons["deleteAllButton"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()

        // The first ask, then the second: cancelling the second deletes nothing.
        // The system draws a dialog's button twice in the hierarchy; either one taps it.
        let proceed = app.buttons.matching(identifier: "deleteContinue").firstMatch
        XCTAssertTrue(proceed.waitForExistence(timeout: 5), "No first confirmation")
        proceed.tap()
        let confirm = app.buttons.matching(identifier: "deleteConfirm").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "No second confirmation")
        attachScreenshot(of: app, named: "delete-all-confirm")
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["deleteDone"].exists)

        delete.tap()
        proceed.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        let done = app.descendants(matching: .any)["deleteDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "Nothing said it was deleted")
        XCTAssertTrue(done.label.hasPrefix("Deleted"), done.label)
    }
}
