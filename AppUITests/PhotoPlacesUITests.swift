import XCTest

/// Find places in my photos (#64): Settings leads to the screen that explains what it reads. The
/// system's photo permission and library can't be driven from here, so the scan itself is covered
/// by unit tests.
final class PhotoPlacesUITests: UITestCase {
    @MainActor
    func testSettingsLeadsToTheScreenThatExplainsWhatItReads() {
        let app = launch(["-resetState"])
        let settings = app.buttons["settingsButton"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        let link = app.buttons["photoPlacesLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 10), "No way to find places in photos in Settings")
        link.tap()
        XCTAssertTrue(app.navigationBars["Photo places"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["findPlacesButton"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "photo-places")
    }
}
