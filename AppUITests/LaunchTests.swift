import XCTest

/// Launches the app, checks key screens and attaches screenshots.
/// CI exports these attachments into `screenshots/<issue>/`.
final class LaunchTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsJournal() {
        let app = launch(["-resetState"])
        XCTAssertTrue(app.tabBars.buttons["Journal"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Journal"].exists)
        XCTAssertTrue(app.staticTexts["your first keepsake"].exists)
        attachScreenshot(of: app, named: "launch")
    }

    @MainActor
    func testAllThreeTabsAreReachable() {
        let app = launch(["-resetState"])
        for title in ["Collections", "Atlas", "Journal"] {
            let button = app.tabBars.buttons[title]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "\(title) tab missing")
            button.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), "\(title) screen missing")
        }
    }

    @MainActor
    func testLogButtonOpensQuickLogFromAnyTab() {
        let app = launch(["-resetState"])
        app.tabBars.buttons["Atlas"].tap()
        let logButton = app.buttons["quickLogButton"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 10))
        logButton.tap()
        XCTAssertTrue(app.navigationBars["What did you savour?"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "quick-log")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Atlas"].waitForExistence(timeout: 5))
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
        // Settings lives behind the ā avatar in the Journal toolbar.
        let settings = app.buttons["settingsButton"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
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
        // An empty cabinet never shows a bare "0": empty drawers carry the ghost line instead.
        XCTAssertFalse(app.staticTexts["0"].exists)
        XCTAssertTrue(labelled("Nothing savoured yet", in: app).exists)
        attachScreenshot(of: app, named: "collections")

        // Edit makes the drawers jiggle and gives each a hide badge.
        app.buttons["arrangeButton"].tap()
        let hide = app.buttons["hideCollection-Airlines"]
        bringIntoView(hide, in: app)
        attachScreenshot(of: app, named: "collections-arranging")
        hide.tap()
        app.buttons["arrangeButton"].tap()

        // Hidden collections sit below the cabinet, dimmed, and can be shown again.
        let hiddenHeader = app.staticTexts["Hidden"]
        bringIntoView(hiddenHeader, in: app)
        attachScreenshot(of: app, named: "collections-hidden")
        let show = app.buttons["showCollection-Airlines"]
        bringIntoView(show, in: app)
        show.tap()
        XCTAssertTrue(hiddenHeader.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["collection-airlines-Airlines"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCabinetFansKeepsakesOutOfFilledDrawers() {
        let runs = [
            (["-resetState", "-sampleData"], "cabinet"),
            (["-resetState", "-sampleData", "-forceDarkMode"], "cabinet-dark"),
        ]
        for (args, name) in runs {
            let app = launch(args)
            openCollectionsAndWait(app)
            // Ranked drawers name their No. 1; checklists show their share of the world.
            XCTAssertTrue(labelled("4 ranked, number one Prufrock Coffee", in: app).waitForExistence(timeout: 5))
            XCTAssertTrue(labelled("4 stamped", in: app, prefix: true).waitForExistence(timeout: 5))
            // Restaurants and Cities are still empty: ghost line, not "0".
            XCTAssertTrue(labelled("Nothing savoured yet", in: app).exists)
            XCTAssertFalse(app.staticTexts["0"].exists)
            attachScreenshot(of: app, named: name)
            app.terminate()
        }
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
        customiseFromMenu(app, "Concerts")
        let field = app.textFields["collectionNameField"]
        field.tap()
        field.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) {
            app.menuItems["Select All"].tap()
        }
        field.typeText("Gigs")
        attachScreenshot(of: app, named: "edit-collection")
        app.buttons["saveCollectionButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit collection"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Gigs"].waitForExistence(timeout: 5))

        // Delete with confirmation
        customiseFromMenu(app, "Gigs")
        let deleteButton = app.buttons["deleteCollectionButton"]
        scrollUntilVisible(deleteButton, in: app)
        deleteButton.tap()
        // The dialog can expose its button in more than one container, so take the first match.
        let confirm = app.buttons["confirmDeleteButton"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["This collection is empty."].exists)
        attachScreenshot(of: app, named: "delete-confirmation")
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Gigs"].waitForNonExistence(timeout: 5))

        // Built-ins can be edited but not deleted
        customiseFromMenu(app, "Cafés")
        XCTAssertTrue(app.navigationBars["Edit collection"].waitForExistence(timeout: 15))
        let builtInDelete = app.buttons["deleteCollectionButton"]
        for _ in 0 ..< 4 where !builtInDelete.exists {
            app.swipeUp()
        }
        XCTAssertFalse(builtInDelete.exists, "Built-in collections must not offer delete")
    }

    @MainActor
    func testKeepsakeGallery() {
        let runs = [(["-keepsakeGallery"], "keepsakes-light"), (["-keepsakeGallery", "-forceDarkMode"], "keepsakes-dark")]
        for (args, name) in runs {
            let app = launch(args)
            XCTAssertTrue(app.navigationBars["Keepsakes"].waitForExistence(timeout: 10))
            // Each keepsake is a single VoiceOver element with a spoken summary.
            XCTAssertTrue(labelled("Passport stamp, Peru", in: app).waitForExistence(timeout: 5))
            // Every template in the kit is present and speaks for itself.
            let summaries = [
                "Receipt, Prufrock Coffee",
                "Menu card, Dishoom",
                "Ticket stub, Perfect Days",
                "Ticket stub, Past Lives",
                "Boarding pass, British Airways",
                "Postcard from Lisbon",
                "Concerts, Radiohead",
            ]
            for summary in summaries {
                XCTAssertTrue(labelled(summary, in: app, prefix: true).exists, "\(summary) keepsake missing")
            }
            // One screenshot per screenful, so every template is captured.
            attachScreenshot(of: app, named: name)
            for page in 2 ... 5 {
                app.swipeUp()
                attachScreenshot(of: app, named: "\(name)-\(page)")
            }
            app.terminate()
        }
    }

    @MainActor
    func testCountryPickerSearchesAndMultiSelects() {
        let app = launch(["-countryPicker"])
        XCTAssertTrue(app.navigationBars["Countries"].waitForExistence(timeout: 10))
        // Grouped by continent, with flags, before searching. The list is lazy, so check the first
        // continent (Africa); later ones aren't built until scrolled to.
        XCTAssertTrue(app.staticTexts["Africa"].waitForExistence(timeout: 5) || app.staticTexts["AFRICA"].exists)
        attachScreenshot(of: app, named: "country-picker")
        let search = app.searchFields["Search countries"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("japan")
        let japan = app.buttons["country-JP"]
        XCTAssertTrue(japan.waitForExistence(timeout: 5))
        japan.tap()
        XCTAssertTrue(app.navigationBars["1 stamped"].waitForExistence(timeout: 5))
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "portu")
        app.buttons["country-PT"].tap()
        XCTAssertTrue(app.navigationBars["2 stamped"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "country-picker-search")
        // Tapping again unpicks.
        app.buttons["country-PT"].tap()
        XCTAssertTrue(app.navigationBars["1 stamped"].waitForExistence(timeout: 5))
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

    /// Scrolls the frontmost form until `element` is on screen (form rows load lazily).
    @MainActor
    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 6) {
        for _ in 0 ..< attempts where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(element) never scrolled into view")
    }

    /// Opens Customise from a collection drawer's context menu (long press).
    @MainActor
    private func customiseFromMenu(_ app: XCUIApplication, _ name: String) {
        openDrawerMenu(app, name)
        app.buttons["Customise"].tap()
        XCTAssertTrue(app.navigationBars["Edit collection"].waitForExistence(timeout: 15))
    }

    /// Long-presses a drawer until its context menu shows. A press that lands while the cabinet is
    /// still settling (after a scroll or a new drawer) starts no menu, so it's retried once.
    @MainActor
    private func openDrawerMenu(_ app: XCUIApplication, _ name: String) {
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
    private func labelled(_ label: String, in app: XCUIApplication, prefix: Bool = false) -> XCUIElement {
        let format = prefix ? "label BEGINSWITH %@" : "label == %@"
        return app.descendants(matching: .any).matching(NSPredicate(format: format, label)).firstMatch
    }

    /// Scrolls the cabinet until `element` can be tapped, up or down depending on where it is.
    /// The cabinet isn't lazy, so off-screen drawers exist and report their frames.
    @MainActor
    private func bringIntoView(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 8) {
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
