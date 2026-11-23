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
        // Wait for the row to settle in the Hidden section before swiping it.
        XCTAssertTrue(app.staticTexts["Hidden"].waitForExistence(timeout: 10))
        let airlines = app.staticTexts["Airlines"]
        XCTAssertTrue(airlines.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "collections-hidden")
        airlines.swipeLeft()
        XCTAssertTrue(app.buttons["Show"].waitForExistence(timeout: 10))
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
        app.buttons["Rose"].tap()
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
    func testKeepsakeGallery() {
        let runs = [(["-keepsakeGallery"], "keepsakes-light"), (["-keepsakeGallery", "-forceDarkMode"], "keepsakes-dark")]
        for (args, name) in runs {
            let app = launch(args)
            XCTAssertTrue(app.navigationBars["Keepsakes"].waitForExistence(timeout: 10))
            // Each keepsake is a single VoiceOver element with a spoken summary.
            let peru = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Passport stamp, Peru"))
            XCTAssertTrue(peru.firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(of: app, named: name)
            app.terminate()
        }
    }

    @MainActor
    func testHoldToSavourSealsTheKeepsake() {
        let app = launch(["-keepsakeGallery", "-resetState"])
        let seal = app.descendants(matching: .any)["sealButton"]
        XCTAssertTrue(seal.waitForExistence(timeout: 10))
        // A quick tap doesn't seal before the hold has been learned.
        seal.tap()
        XCTAssertFalse(app.descendants(matching: .any)["waxSeal"].waitForExistence(timeout: 2))
        // Holding past 0.6 s seals it.
        seal.press(forDuration: 1.2)
        XCTAssertTrue(app.descendants(matching: .any)["waxSeal"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "sealed")
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
        app.launchArguments = arguments + ["-inMemoryStore", "-disableTips"]
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
