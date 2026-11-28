import XCTest

/// The optional app lock (#76). The simulator has no Face ID, so these run with
/// `-fakeAuthenticator`, which passes when asked and waits for the Unlock tap.
final class AppLockUITests: UITestCase {
    @MainActor
    func testTheLockIsOffUntilYouTurnItOn() {
        let app = launch(["-resetState", "-fakeAuthenticator"])
        openSettings(app)
        let toggle = app.switches["appLockToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "No lock toggle in Settings")
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(app.descendants(matching: .any)["appLockDelay"].exists)
        flip(toggle)
        // Turning it on asks first (the fake passes), then offers how soon it falls.
        XCTAssertTrue(app.descendants(matching: .any)["appLockDelay"].waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1")
        attachScreenshot(of: app, named: "app-lock-settings")
    }

    @MainActor
    func testTheAppLocksWhenItLeavesTheFrontAndUnlocksWithATap() {
        let app = launch(["-resetState", "-fakeAuthenticator"])
        openSettings(app)
        let toggle = app.switches["appLockToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        flip(toggle)
        XCTAssertTrue(app.descendants(matching: .any)["appLockDelay"].waitForExistence(timeout: 5))

        // Out to the Home Screen and back: with "Immediately" the lock has fallen. It covers the
        // open Settings sheet too, not just the screen underneath.
        XCUIDevice.shared.press(.home)
        app.activate()
        let unlock = app.buttons["unlockButton"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 10), "The app didn't lock")
        attachScreenshot(of: app, named: "app-lock-cover")
        unlock.tap()
        XCTAssertTrue(unlock.waitForNonExistence(timeout: 5), "Unlock left the cover up")
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Settings didn't come back after unlocking")
    }

    /// A Settings toggle's element is the whole row, and only the switch at its right end flips,
    /// so a tap in the middle of the row (what `tap()` does) lands on the label and does nothing.
    @MainActor
    private func flip(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }
}
