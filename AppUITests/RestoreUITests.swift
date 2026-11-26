import XCTest

/// Restore from a backup (#58): Settings leads to a screen that asks for a backup folder. The
/// system's folder picker lives outside the app, so the rest is covered by unit tests.
final class RestoreUITests: UITestCase {
    @MainActor
    func testSettingsLeadsToTheRestoreScreen() {
        let app = launch(["-resetState"])
        let settings = app.buttons["settingsButton"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        let link = app.buttons["restoreBackupLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 10), "No way to restore in Settings")
        link.tap()
        XCTAssertTrue(app.navigationBars["Restore"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["chooseBackupButton"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "restore-backup")
    }

    @MainActor
    func testSettingsLeadsToTheBackUpScreen() {
        let app = launch(["-resetState"])
        let settings = app.buttons["settingsButton"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        let link = app.buttons["exportBackupLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 10), "No way to back up in Settings")
        link.tap()
        XCTAssertTrue(app.navigationBars["Back up"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["exportBackupButton"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "back-up-to-files")
    }
}
