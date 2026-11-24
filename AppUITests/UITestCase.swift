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

    /// Turns the cabinet to `name`'s drawer and taps it open, unless it's open already. Drawers
    /// open from the cabinet, so this leaves the chest first if it's showing.
    @MainActor
    func openDrawer(_ app: XCUIApplication, _ name: String) {
        guard !app.navigationBars[name].exists else { return }
        let done = app.buttons["cabinetButton"]
        for _ in 0 ..< 3 where done.exists {
            done.tap()
            _ = done.waitForNonExistence(timeout: 4)
        }
        let knob = app.buttons["Turn to \(name)"]
        XCTAssertTrue(knob.waitForExistence(timeout: 10), "No knob for \(name)")
        knob.tap()
        XCTAssertTrue(waitUntilSelected(knob, true), "The cabinet didn't turn to \(name)")
        // Tapping the front drawer, in the middle of the drum, opens it.
        let front = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        for _ in 0 ..< 2 where !app.navigationBars[name].exists {
            front.tap()
            _ = app.navigationBars[name].waitForExistence(timeout: 5)
        }
        XCTAssertTrue(app.navigationBars[name].exists, "The \(name) drawer didn't open")
    }

    /// Opens Customise from a collection drawer's context menu (long press).
    @MainActor
    func customiseFromMenu(_ app: XCUIApplication, _ name: String) {
        openDrawerMenu(app, name)
        app.buttons["Customise"].tap()
        XCTAssertTrue(app.navigationBars["Edit collection"].waitForExistence(timeout: 15))
    }

    /// Opens `name`'s drawer and its Customise sheet from the drawer's toolbar.
    @MainActor
    func customise(_ app: XCUIApplication, _ name: String) {
        openDrawer(app, name)
        let button = app.buttons["drawerCustomise"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.navigationBars["Edit collection"].waitForExistence(timeout: 15))
    }

    /// Turns the cabinet to `name`'s drawer and holds it until its menu shows (the cabinet's
    /// front drawer has the hold menu; in the chest a hold carries the drawer instead). A press
    /// that lands while the drum is still settling starts no menu, so it's retried once.
    @MainActor
    func openDrawerMenu(_ app: XCUIApplication, _ name: String) {
        let done = app.buttons["cabinetButton"]
        for _ in 0 ..< 3 where done.exists {
            done.tap()
            _ = done.waitForNonExistence(timeout: 4)
        }
        let knob = app.buttons["Turn to \(name)"]
        XCTAssertTrue(knob.waitForExistence(timeout: 10), "No knob for \(name)")
        knob.tap()
        XCTAssertTrue(waitUntilSelected(knob, true), "The cabinet didn't turn to \(name)")
        let front = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        let customise = app.buttons["Customise"]
        for _ in 0 ..< 2 where !customise.exists {
            front.press(forDuration: 1.2)
            _ = customise.waitForExistence(timeout: 4)
        }
        XCTAssertTrue(customise.exists, "The menu did not appear for \(name)")
    }

    /// Waits until `element`'s selected state is `selected` (rows expose `.isSelected`).
    @MainActor
    func waitUntilSelected(_ element: XCUIElement, _ selected: Bool, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "isSelected == %@", NSNumber(value: selected))
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
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

    /// Switches to Collections and waits until the turning cabinet has loaded, so toolbar taps
    /// don't land mid tab-transition (they're dropped while the glass toolbar is animating).
    /// VoiceOver (and so XCUITest) sees the cabinet as a list of "<name> drawer" buttons.
    @MainActor
    func openCollectionsAndWait(_ app: XCUIApplication) {
        app.tabBars.buttons["Collections"].tap()
        XCTAssertTrue(app.navigationBars["Collections"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Cafés drawer"].waitForExistence(timeout: 10))
        let newButton = app.buttons["newCollectionButton"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 10))
        XCTAssertTrue(newButton.isHittable)
    }

    /// Switches the cabinet to the whole chest of drawers (the grid), where every drawer shows its
    /// name, stat and context menu. Does nothing if the chest is already showing.
    @MainActor
    func openChest(_ app: XCUIApplication) {
        let allDrawers = app.buttons["allDrawersButton"]
        let done = app.buttons["cabinetButton"]
        // A toolbar tap is dropped while the glass toolbar is still animating (after a sheet
        // closes, say), so tap again until the chest is really showing.
        for _ in 0 ..< 3 where !done.exists {
            if allDrawers.waitForExistence(timeout: 3) {
                allDrawers.tap()
            }
            _ = done.waitForExistence(timeout: 4)
        }
        XCTAssertTrue(done.exists, "The chest didn't open")
        XCTAssertTrue(app.staticTexts["Cafés"].waitForExistence(timeout: 10), "The chest has no Cafés drawer")
    }

    @MainActor
    func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        // UI tests never touch the on-disk store, and skip first-launch onboarding unless a test
        // is about it (`-onboarding`).
        let onboarding = arguments.contains("-onboarding") ? [] : ["-skipOnboarding"]
        app.launchArguments = arguments + ["-inMemoryStore", "-disableTips"] + onboarding
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
