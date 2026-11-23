import XCTest

/// Launches the app, checks key screens and attaches screenshots.
/// CI exports these attachments into `screenshots/<issue>/`.
final class LaunchTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsTimelineTab() {
        let app = launch(["-resetState"])
        XCTAssertTrue(app.tabBars.buttons["Timeline"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Timeline"].exists)
        attachScreenshot(of: app, named: "launch")
    }

    @MainActor
    func testAllFourTabsAreReachable() {
        let app = launch(["-resetState"])
        for title in ["Collections", "Map", "Settings", "Timeline"] {
            let button = app.tabBars.buttons[title]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "\(title) tab missing")
            button.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), "\(title) screen missing")
        }
    }

    @MainActor
    func testLogButtonOpensQuickLogFromAnyTab() {
        let app = launch(["-resetState"])
        app.tabBars.buttons["Map"].tap()
        let logButton = app.buttons["quickLogButton"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 10))
        logButton.tap()
        XCTAssertTrue(app.navigationBars["What did you savour?"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "quick-log")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Map"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSelectedTabRestoresAfterRelaunch() {
        let app = launch(["-resetState"])
        app.tabBars.buttons["Collections"].tap()
        XCTAssertTrue(app.navigationBars["Collections"].waitForExistence(timeout: 5))
        // Give UserDefaults a moment to persist before the process is killed.
        sleep(2)
        app.terminate()

        let relaunched = launch([])
        XCTAssertTrue(relaunched.navigationBars["Collections"].waitForExistence(timeout: 10))
        XCTAssertTrue(relaunched.tabBars.buttons["Collections"].isSelected)
    }

    @MainActor
    func testAboutExplainsNameAndShowsVersion() {
        let app = launch(["-resetState"])
        app.tabBars.buttons["Settings"].tap()
        let aboutLink = app.buttons["aboutLink"]
        XCTAssertTrue(aboutLink.waitForExistence(timeout: 10))
        aboutLink.tap()
        XCTAssertTrue(app.navigationBars["About"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["appVersion"].label.hasPrefix("Version "))
        attachScreenshot(of: app, named: "about")
    }

    @MainActor
    func testCollectionsListsBuiltInsAndCanHideOne() {
        let app = launch(["-resetState"])
        app.tabBars.buttons["Collections"].tap()
        XCTAssertTrue(app.navigationBars["Collections"].waitForExistence(timeout: 10))
        for name in ["Cafés", "Restaurants", "Countries", "Cities", "Airlines", "Films"] {
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5), "\(name) missing")
        }
        attachScreenshot(of: app, named: "collections")

        app.staticTexts["Airlines"].swipeLeft()
        let hide = app.buttons["Hide"]
        XCTAssertTrue(hide.waitForExistence(timeout: 5))
        hide.tap()

        // Hidden collections stay listed (dimmed, in their own section) and can be shown again.
        let airlines = app.staticTexts["Airlines"]
        XCTAssertTrue(airlines.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "collections-hidden")
        airlines.swipeLeft()
        XCTAssertTrue(app.buttons["Show"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCreateCustomCollectionAppearsInListAndQuickLog() {
        let app = launch(["-resetState"])
        openCollectionsAndWait(app)
        app.buttons["newCollectionButton"].tap()

        let name = app.textFields["collectionNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        let save = app.buttons["saveCollectionButton"]
        XCTAssertFalse(save.isEnabled, "Save should be disabled until a name is entered")
        name.tap()
        name.typeText("Concerts")
        app.buttons["music note"].tap()
        app.buttons["Plum"].tap()
        attachScreenshot(of: app, named: "new-collection")
        XCTAssertTrue(save.isEnabled)
        save.tap()

        XCTAssertTrue(app.staticTexts["Concerts"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "collections-with-custom")

        app.buttons["quickLogButton"].tap()
        XCTAssertTrue(app.navigationBars["What did you savour?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Concerts"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEditAndDeleteCustomCollectionButNotBuiltIn() {
        let app = launch(["-resetState"])
        openCollectionsAndWait(app)
        app.buttons["newCollectionButton"].tap()
        let name = app.textFields["collectionNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap()
        name.typeText("Concerts")
        app.buttons["saveCollectionButton"].tap()
        XCTAssertTrue(app.staticTexts["Concerts"].waitForExistence(timeout: 5))

        // Rename
        app.staticTexts["Concerts"].swipeRight()
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit collection"].waitForExistence(timeout: 15))
        let field = app.textFields["collectionNameField"]
        field.tap()
        field.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) {
            app.menuItems["Select All"].tap()
        }
        field.typeText("Gigs")
        attachScreenshot(of: app, named: "edit-collection")
        app.buttons["saveCollectionButton"].tap()
        XCTAssertTrue(app.staticTexts["Gigs"].waitForExistence(timeout: 5))

        // Delete with confirmation
        app.staticTexts["Gigs"].swipeRight()
        app.buttons["Edit"].tap()
        app.buttons["deleteCollectionButton"].tap()
        let confirm = app.buttons["confirmDeleteButton"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["This collection is empty."].exists)
        attachScreenshot(of: app, named: "delete-confirmation")
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Gigs"].waitForNonExistence(timeout: 5))

        // Built-ins can be edited but not deleted
        app.staticTexts["Cafés"].swipeRight()
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit collection"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["deleteCollectionButton"].exists)
    }

    @MainActor
    func testDesignCatalogLight() {
        let app = launch(["-designCatalog"])
        XCTAssertTrue(app.navigationBars["Design catalogue"].waitForExistence(timeout: 10))
        attachScreenshot(of: app, named: "design-catalog-light")
    }

    @MainActor
    func testDesignCatalogDark() {
        let app = launch(["-designCatalog", "-forceDarkMode"])
        XCTAssertTrue(app.navigationBars["Design catalogue"].waitForExistence(timeout: 10))
        attachScreenshot(of: app, named: "design-catalog-dark")
    }

    // MARK: - Helpers

    /// Switches to Collections and waits until the list has loaded, so toolbar taps don't land
    /// mid tab-transition (they're dropped while the glass toolbar is animating).
    @MainActor
    private func openCollectionsAndWait(_ app: XCUIApplication) {
        app.tabBars.buttons["Collections"].tap()
        XCTAssertTrue(app.navigationBars["Collections"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Cafés"].waitForExistence(timeout: 10))
        let newButton = app.buttons["newCollectionButton"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 10))
        XCTAssertTrue(newButton.isHittable)
    }

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        // UI tests never touch the on-disk store.
        app.launchArguments = arguments + ["-inMemoryStore"]
        app.launch()
        return app
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
