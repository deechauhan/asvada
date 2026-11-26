import XCTest

/// The turning cabinet: roll to a drawer, pull it open, and the chest one tap away.
final class CabinetUITests: UITestCase {
    /// A point on the drum, in the middle of the screen.
    @MainActor
    private func drum(_ app: XCUIApplication) -> XCUICoordinate {
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
    }

    /// A slow drag that ends still, so the drum lands where the finger left it (no fling).
    @MainActor
    private func drag(_ app: XCUIApplication, by offset: CGVector) {
        let start = drum(app)
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(offset), withVelocity: 300, thenHoldForDuration: 0.4)
    }

    @MainActor
    func testRollToADrawerAndPullItOpen() {
        let runs = [
            (["-resetState", "-sampleData"], "cabinet-drum"),
            (["-resetState", "-sampleData", "-forceDarkMode"], "cabinet-drum-dark"),
        ]
        for (args, name) in runs {
            let app = launch(args)
            openCollectionsAndWait(app)
            // Cafés is at the front, and every drawer is in VoiceOver's list with its stat.
            XCTAssertTrue(waitUntilSelected(app.buttons["Turn to Cafés"], true))
            for drawer in ["Cafés", "Restaurants", "Countries", "Cities", "Airlines", "Films"] {
                XCTAssertTrue(app.buttons["\(drawer) drawer"].exists, "\(drawer) drawer missing")
            }
            XCTAssertFalse(app.staticTexts["0"].exists)
            attachScreenshot(of: app, named: name)

            // Swipe left by about one drawer: the next drawer, Restaurants, rolls to the front.
            drag(app, by: CGVector(dx: -190, dy: 0))
            XCTAssertTrue(waitUntilSelected(app.buttons["Turn to Restaurants"], true), "the cabinet didn't roll")
            attachScreenshot(of: app, named: "\(name)-rolled")

            // The knob rail turns straight to a drawer.
            app.buttons["Turn to Cafés"].tap()
            XCTAssertTrue(waitUntilSelected(app.buttons["Turn to Cafés"], true))

            // Pull the front drawer toward you: it opens.
            drag(app, by: CGVector(dx: 0, dy: 280))
            XCTAssertTrue(app.navigationBars["Cafés"].waitForExistence(timeout: 10), "pulling didn't open the drawer")
            XCTAssertTrue(labelled("Receipt, Prufrock Coffee", in: app, prefix: true).waitForExistence(timeout: 5))
            attachScreenshot(of: app, named: "\(name)-opened")
            app.terminate()
        }
    }

    @MainActor
    func testTheBlankDrawerStartsANewCollection() {
        let app = launch(["-resetState"])
        openCollectionsAndWait(app)
        // The blank drawer sits at the end of the ring, just left of the first drawer.
        drag(app, by: CGVector(dx: 190, dy: 0))
        XCTAssertTrue(waitUntilSelected(app.buttons["Turn to New collection"], true))
        drum(app).tap()
        XCTAssertTrue(app.textFields["collectionNameField"].waitForExistence(timeout: 15))
    }

    @MainActor
    func testMidRollAndTheChest() {
        let app = launch(["-resetState", "-sampleData", "-cabinetMidRoll"])
        openCollectionsAndWait(app)
        attachScreenshot(of: app, named: "cabinet-mid-roll")
        // "All drawers" lays out the whole chest; tapping a drawer turns the cabinet to it.
        openChest(app)
        attachScreenshot(of: app, named: "cabinet-chest")
        app.staticTexts["Films"].tap()
        XCTAssertTrue(app.buttons["allDrawersButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntilSelected(app.buttons["Turn to Films"], true))
    }

    @MainActor
    func testHoldingTheFrontDrawerShowsItsMenu() {
        let app = launch(["-resetState", "-sampleData"])
        openCollectionsAndWait(app)
        XCTAssertTrue(waitUntilSelected(app.buttons["Turn to Cafés"], true))
        // The cabinet's front drawer has the hold menu but, unlike the chest, can't be dragged.
        let customise = app.buttons["Customise"]
        for _ in 0 ..< 2 where !customise.exists {
            drum(app).press(forDuration: 1.2)
            _ = customise.waitForExistence(timeout: 4)
        }
        XCTAssertTrue(customise.exists, "Holding the front drawer showed no menu")
        XCTAssertTrue(app.buttons["Open"].exists)
        XCTAssertTrue(app.buttons["Share"].exists)
        attachScreenshot(of: app, named: "cabinet-hold-menu")
        customise.tap()
        XCTAssertTrue(app.navigationBars["Edit collection"].waitForExistence(timeout: 15))
    }

    @MainActor
    func testCustomiseAndShareFromAnOpenDrawer() {
        let app = launch(["-resetState", "-sampleData"])
        openCollectionsAndWait(app)

        // Share the top cafés straight from the open drawer.
        openDrawer(app, "Cafés")
        let share = app.buttons["drawerShare"]
        XCTAssertTrue(share.waitForExistence(timeout: 5), "Share missing from a filled drawer")
        attachScreenshot(of: app, named: "open-drawer-toolbar")
        share.tap()
        XCTAssertTrue(app.descendants(matching: .any)["shareCardPreview"].waitForExistence(timeout: 15))
        // Close it with its Done button: a swipe over the card can scroll it instead of closing.
        app.buttons["shareCardDone"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["shareCardPreview"].waitForNonExistence(timeout: 10))

        // Customise it from the same toolbar; Cancel leaves it as it was.
        customise(app, "Cafés")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Cafés"].waitForExistence(timeout: 10))

        // An empty drawer has nothing to share.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Collections"].waitForExistence(timeout: 10))
        openDrawer(app, "Restaurants")
        XCTAssertTrue(app.buttons["drawerCustomise"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["drawerShare"].exists)
    }

    @MainActor
    func testDeletingAnOpenDrawerClosesIt() {
        let app = launch(["-resetState"])
        openCollectionsAndWait(app)
        app.buttons["newCollectionButton"].tap()
        let name = app.textFields["collectionNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap()
        name.typeText("Concerts")
        tapSaveCollection(app)
        XCTAssertTrue(app.buttons["Concerts drawer"].waitForExistence(timeout: 10))

        customise(app, "Concerts")
        let delete = app.buttons["deleteCollectionButton"]
        scrollUntilVisible(delete, in: app)
        delete.tap()
        let confirm = app.buttons["confirmDeleteButton"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        // Back at the cabinet, with no Concerts drawer left.
        XCTAssertTrue(app.navigationBars["Collections"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Concerts drawer"].waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testAddAnItemByHandFromAnOpenDrawer() {
        let app = launch(["-resetState"])
        openCollectionsAndWait(app)

        // A café search can't find: written in by hand, with a pin on the map.
        openDrawer(app, "Cafés")
        app.buttons["drawerAddByHand"].tap()
        let name = app.textFields["manualItemName"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        let add = app.buttons["manualItemSave"]
        XCTAssertFalse(add.isEnabled, "A name is required")
        name.tap()
        name.typeText("Corner Kiosk")
        XCTAssertTrue(add.isEnabled)
        let pin = app.staticTexts["manualItemPin"]
        XCTAssertEqual(pin.label, "Tap the map to pin where it is")
        app.descendants(matching: .any)["manualItemMap"].tap()
        XCTAssertTrue(labelled("Pinned", in: app, prefix: true).waitForExistence(timeout: 5), "Tapping the map dropped no pin")
        attachScreenshot(of: app, named: "add-by-hand")
        add.tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 10))
        let kiosk = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Corner Kiosk")).firstMatch
        XCTAssertTrue(kiosk.waitForExistence(timeout: 10), "The new café isn't in its drawer")
        attachScreenshot(of: app, named: "add-by-hand-in-drawer")

        // Films have no place to pin: just a name.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Collections"].waitForExistence(timeout: 10))
        openDrawer(app, "Films")
        app.buttons["drawerAddByHand"].tap()
        XCTAssertTrue(app.textFields["manualItemName"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["manualItemMap"].exists)
    }

    @MainActor
    func testAKeepsakeOpensItsThingsPage() {
        let app = launch(["-resetState", "-sampleData"])
        openCollectionsAndWait(app)
        openDrawer(app, "Cafés")

        // Tap Prufrock Coffee's receipt: its page shows its rank, how often, and every visit.
        let receipt = labelled("Receipt, Prufrock Coffee", in: app, prefix: true)
        XCTAssertTrue(receipt.waitForExistence(timeout: 10))
        receipt.tap()
        XCTAssertTrue(app.navigationBars["Prufrock Coffee"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["itemRank"].label, "No. 1 in Cafés")
        XCTAssertEqual(app.staticTexts["itemCount"].label, "1 visit")
        attachScreenshot(of: app, named: "item-detail")

        // Each entry opens its details.
        let entry = app.buttons["itemEntry"].firstMatch
        XCTAssertTrue(entry.exists)
        entry.tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testAnEntryIsEditedDeletedAndPutBack() {
        let app = launch(["-resetState", "-sampleData"])
        openCollectionsAndWait(app)
        openDrawer(app, "Cafés")
        let receipt = labelled("Receipt, Prufrock Coffee", in: app, prefix: true)
        XCTAssertTrue(receipt.waitForExistence(timeout: 10))
        receipt.tap()
        XCTAssertTrue(app.navigationBars["Prufrock Coffee"].waitForExistence(timeout: 10))
        let count = app.staticTexts["itemCount"]
        XCTAssertEqual(count.label, "1 visit")

        // Edit: a note written in the details is filled in when they open again.
        let entry = app.buttons["itemEntry"].firstMatch
        entry.tap()
        let notes = app.descendants(matching: .any)["entryNotes"]
        XCTAssertTrue(notes.waitForExistence(timeout: 10))
        notes.tap()
        notes.typeText("Edited by hand")
        app.buttons["entryDetailsDone"].tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForNonExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(notes.waitForExistence(timeout: 10))
        XCTAssertTrue((notes.value as? String ?? "").contains("Edited by hand"), "The note wasn't filled in again")

        // Delete from the details: the sheet closes, and Undo puts the entry back.
        app.buttons["deleteEntryButton"].tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForNonExistence(timeout: 10))
        let undo = app.buttons["undoDelete"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "No undo after deleting")
        XCTAssertEqual(count.label, "Not savoured yet")
        attachScreenshot(of: app, named: "entry-deleted-undo")
        undo.tap()
        XCTAssertTrue(undo.waitForNonExistence(timeout: 5))
        XCTAssertEqual(count.label, "1 visit")

        // Swipe it away (a full swipe deletes outright; a short one shows Delete). Once Undo
        // has gone, so has the entry.
        entry.swipeLeft()
        if !undo.waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
        }
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "No undo after swiping to delete")
        XCTAssertEqual(count.label, "Not savoured yet")
        XCTAssertTrue(undo.waitForNonExistence(timeout: 15), "Undo never went away")
        XCTAssertEqual(count.label, "Not savoured yet")
        XCTAssertFalse(app.buttons["itemEntry"].exists)
    }

    @MainActor
    func testCountriesTickOffTheWorldWithProgressPerContinent() {
        let app = launch(["-resetState"])
        openCollectionsAndWait(app)
        openDrawer(app, "Countries")

        // Nothing stamped yet: the ghost line, never a bare 0.
        let progress = app.descendants(matching: .any)["passportProgress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        XCTAssertEqual(progress.label, "No countries stamped yet")

        // Stamp Japan by search (Return stamps it): the world and Asia both move.
        let search = app.textFields["stampSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Japan\n")
        XCTAssertTrue(labelled("1 of 195 countries, 1 percent", in: app).waitForExistence(timeout: 5))
        let asia = app.descendants(matching: .any)["continentProgress-Asia"]
        XCTAssertTrue(asia.label.hasPrefix("Asia, 1 of "), asia.label)
        attachScreenshot(of: app, named: "countries-checklist")

        // It's saved: leave the drawer and come back.
        app.navigationBars["Countries"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Countries"].waitForNonExistence(timeout: 10))
        openDrawer(app, "Countries")
        XCTAssertTrue(labelled("1 of 195 countries, 1 percent", in: app).waitForExistence(timeout: 10))
    }
}
