import XCTest

/// Launches the app, checks the root screen and attaches a screenshot.
/// CI exports these attachments into `screenshots/`.
final class LaunchTests: XCTestCase {
    @MainActor
    func testLaunchShowsRootScreen() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Asvada"].waitForExistence(timeout: 10))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "launch"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
