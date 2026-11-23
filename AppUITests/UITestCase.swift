import XCTest

/// Shared setup and helpers for the app's UI tests: launching with test-only arguments,
/// screenshots, finding elements by label and working the Collections cabinet.
class UITestCase: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Scrolls the frontmost form until `element` is on screen (form rows load lazily).
    @MainActor
    func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 6) {
        for _ in 0 ..< attempts where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(element) never scrolled into view")
    }

    /// Opens Customise from a collection drawer's context menu (long press).
    @MainActor
    func customiseFromMenu(_ app: XCUIApplication, _ name: String) {
        openDrawerMenu(app, name)
        app.buttons["Customise"].tap()
        XCTAssertTrue(app.navigationBars["Edit collection"].waitForExistence(timeout: 15))
    }

    /// Long-presses a drawer until its context menu shows. A press that lands while the cabinet is
    /// still settling (after a scroll or a new drawer) starts no menu, so it's retried once.
    @MainActor
    func openDrawerMenu(_ app: XCUIApplication, _ name: String) {
        let row = app.staticTexts[name]
        bringIntoView(row, in: app)
        let customise = app.buttons["Customise"]
        for _ in 0 ..< 2 where !customise.exists {
            row.press(forDuration: 1.2)
            _ = customise.waitForExistence(timeout: 4)
        }
        XCTAssertTrue(customise.exists, "The context menu did not appear for \(name)")
    }

    /// The first element of any type whose accessibility label is (or starts with) `label`.
    @MainActor
    func labelled(_ label: String, in app: XCUIApplication, prefix: Bool = false) -> XCUIElement {
        let format = prefix ? "label BEGINSWITH %@" : "label == %@"
        return app.descendants(matching: .any).matching(NSPredicate(format: format, label)).firstMatch
    }

    /// Scrolls the cabinet until `element` can be tapped, up or down depending on where it is.
    /// The cabinet isn't lazy, so off-screen drawers exist and report their frames.
    @MainActor
    func bringIntoView(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 8) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(element) missing")
        let screen = app.windows.firstMatch.frame
        // Keep clear of the tab bar and the savour pill at the bottom, which float over content.
        let floor = screen.maxY - 220
        for _ in 0 ..< attempts where !element.isHittable || element.frame.maxY > floor {
            if element.frame.midY < screen.midY {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
        XCTAssertTrue(element.isHittable, "\(element) never came into view")
    }

    /// Switches to Collections and waits until the list has loaded, so toolbar taps don't land
    /// mid tab-transition (they're dropped while the glass toolbar is animating).
    @MainActor
    func openCollectionsAndWait(_ app: XCUIApplication) {
        app.tabBars.buttons["Collections"].tap()
        XCTAssertTrue(app.navigationBars["Collections"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Cafés"].waitForExistence(timeout: 10))
        let newButton = app.buttons["newCollectionButton"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 10))
        XCTAssertTrue(newButton.isHittable)
    }

    @MainActor
    func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        // UI tests never touch the on-disk store.
        app.launchArguments = arguments + ["-inMemoryStore", "-disableTips"]
        app.launch()
        return app
    }

    @MainActor
    func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
