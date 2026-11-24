import XCTest

/// The shell and Collections: launch, tabs, Settings, the cabinet and editing collections.
/// CI exports the attached screenshots into `screenshots/<issue>/`.
final class LaunchTests: UITestCase {
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
        // Bundled data is credited as its licences ask (Natural Earth, OpenFlights under ODbL).
        let credits = app.staticTexts["dataCredits"]
        XCTAssertTrue(credits.exists)
        XCTAssertTrue(credits.label.contains("OpenFlights"))
        attachScreenshot(of: app, named: "about")
    }

    @MainActor
    func testCollectionsListsBuiltInsAndCanHideOne() {
        let app = launch(["-resetState"])
        openCollectionsAndWait(app)
        openChest(app)
        for name in ["Cafés", "Restaurants", "Countries", "Cities", "Airlines", "Films"] {
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5), "\(name) missing")
        }
        // An empty cabinet never shows a bare "0": empty drawers carry the ghost line instead.
        XCTAssertFalse(app.staticTexts["0"].exists)
        XCTAssertTrue(labelled("Nothing savoured yet", in: app).exists)
        attachScreenshot(of: app, named: "collections")

        // Put a drawer away from its hold menu: it waits on the chest's storeroom shelf.
        openDrawerMenu(app, "Airlines")
        app.buttons["Put away"].tap()
        XCTAssertTrue(app.buttons["Airlines drawer"].waitForNonExistence(timeout: 10))
        openChest(app)
        let takeOut = app.buttons["showCollection-Airlines"]
        XCTAssertTrue(takeOut.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Storeroom"].exists)
        attachScreenshot(of: app, named: "collections-storeroom")

        // Take it out again and it's back in the chest.
        takeOut.tap()
        XCTAssertTrue(takeOut.waitForNonExistence(timeout: 10))
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
            openChest(app)
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

        // The new drawer joins the cabinet (VoiceOver lists it as a drawer).
        XCTAssertTrue(app.buttons["Concerts drawer"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "collections-with-custom")

        app.buttons["quickLogButton"].tap()
        let quickLog = app.navigationBars["What did you savour?"].waitForExistence(timeout: 5)
        if !quickLog {
            attachScreenshot(of: app, named: "quick-log-did-not-open")
        }
        XCTAssertTrue(quickLog)
        // The new collection has its own blank in the hand.
        XCTAssertTrue(app.buttons["Savour in Concerts"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.buttons["Concerts drawer"].waitForExistence(timeout: 5))

        // Rename, from the front drawer's hold menu.
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
        XCTAssertTrue(app.buttons["Gigs drawer"].waitForExistence(timeout: 5))

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
        XCTAssertTrue(app.buttons["Gigs drawer"].waitForNonExistence(timeout: 5))

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
    func testShareTopFiveFromTheCafesDrawer() {
        let app = launch(["-resetState", "-sampleData"])
        openCollectionsAndWait(app)
        openDrawerMenu(app, "Cafés")
        let share = app.buttons["Share"]
        XCTAssertTrue(share.exists, "Share missing from a filled drawer's menu")
        share.tap()
        XCTAssertTrue(app.descendants(matching: .any)["shareCardPreview"].waitForExistence(timeout: 15))
        // The card renders to an image before the share button appears.
        XCTAssertTrue(app.buttons["shareCardButton"].waitForExistence(timeout: 10))
        // The card is one accessibility element whose label includes its title.
        let title = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "My top 4 cafés"))
        XCTAssertTrue(title.firstMatch.exists)
        attachScreenshot(of: app, named: "share-top-menu")
    }
}
