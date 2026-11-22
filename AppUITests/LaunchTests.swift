import XCTest

/// Launches the app, checks key screens and attaches screenshots.
/// CI exports these attachments into `screenshots/<issue>/`.
final class LaunchTests: XCTestCase {
    @MainActor
    func testLaunchShowsRootScreen() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Asvada"].waitForExistence(timeout: 10))
        attachScreenshot(of: app, named: "launch")
    }

    @MainActor
    func testDesignCatalogLight() {
        let app = XCUIApplication()
        app.launchArguments = ["-designCatalog"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Design catalogue"].waitForExistence(timeout: 10))
        attachScreenshot(of: app, named: "design-catalog-light")
    }

    @MainActor
    func testDesignCatalogDark() {
        let app = XCUIApplication()
        app.launchArguments = ["-designCatalog", "-forceDarkMode"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Design catalogue"].waitForExistence(timeout: 10))
        attachScreenshot(of: app, named: "design-catalog-dark")
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
