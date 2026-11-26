import XCTest

/// Quick-log end to end: draw a blank, say what it was, savour it its collection's way, seal.
final class QuickLogUITests: UITestCase {
    @MainActor
    func testRankedCafesDuelThenRepeatVisitsSkipIt() {
        let app = launch(["-resetState"])

        // The first café has nothing to duel: it's No. 1.
        draw("Savour a café", in: app)
        addNew("Corner Kiosk", in: app)
        XCTAssertEqual(app.staticTexts["quickLogSummary"].label, "No. 1 in Cafés")
        let note = app.textFields["quickLogNote"]
        note.tap()
        note.typeText("Best flat white on the walk")
        attachScreenshot(of: app, named: "quick-log-seal")
        seal(app, drawer: "Cafés")
        attachScreenshot(of: app, named: "quick-log-toast")

        // The second meets it in a duel and wins.
        draw("Savour a café", in: app)
        addNew("Tiny Tea Stall", in: app)
        XCTAssertTrue(app.staticTexts["Which did you savour more?"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "quick-log-duel")
        app.buttons["duelNew"].tap()
        // "No. 1" stamps onto it in the re-flowed list, then the seal.
        let stamp = app.descendants(matching: .any)["duelPlaced"]
        XCTAssertTrue(stamp.waitForExistence(timeout: 5), "No placement after the duel")
        attachScreenshot(of: app, named: "duel-stamped")
        XCTAssertTrue(app.staticTexts["quickLogSummary"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["quickLogSummary"].label, "No. 1 in Cafés")
        seal(app, drawer: "Cafés")

        // A repeat visit by name: "Still No. 2?", no duel.
        draw("Savour a café", in: app)
        let field = app.textFields["quickLogName"]
        field.tap()
        field.typeText("Corner")
        app.buttons["pick-Corner Kiosk"].tap()
        XCTAssertTrue(app.staticTexts["Still No. 2?"].waitForExistence(timeout: 5))
        app.buttons["stillYes"].tap()
        seal(app, drawer: "Cafés")

        // "Again?" goes straight to the seal.
        app.buttons["quickLogButton"].tap()
        let again = app.buttons["Again: Corner Kiosk"]
        XCTAssertTrue(again.waitForExistence(timeout: 10))
        again.tap()
        seal(app, drawer: "Cafés")
    }

    @MainActor
    func testAFilmIsLoggedAndACountryStamped() {
        let app = launch(["-resetState"])

        // Films are a log: "When?"
        draw("Savour a film", in: app)
        addNew("Perfect Days", in: app)
        XCTAssertTrue(app.staticTexts["When?"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "quick-log-when")
        app.buttons["when-Yesterday"].tap()
        seal(app, drawer: "Films")

        // Countries come from the catalogue and are stamped.
        draw("Stamp a country", in: app)
        let field = app.textFields["quickLogName"]
        field.tap()
        field.typeText("Portu")
        let portugal = app.buttons["pick-Portugal"]
        XCTAssertTrue(portugal.waitForExistence(timeout: 5))
        portugal.tap()
        let stamp = app.buttons["stampItButton"]
        XCTAssertTrue(stamp.waitForExistence(timeout: 5))
        stamp.tap()
        seal(app, drawer: "Countries")
    }

    @MainActor
    func testDetailsAddPeopleAndTagsThatAreSuggestedNextTime() {
        let app = launch(["-resetState"])

        // While sealing: who with and a tag, under the details.
        draw("Savour a film", in: app)
        addNew("Perfect Days", in: app)
        app.buttons["when-Today"].tap()
        app.buttons["quickLogDetails"].tap()
        let people = app.textFields["peopleField"]
        XCTAssertTrue(people.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["addPhotosButton"].exists, "No way to add photos while sealing")
        people.tap()
        people.typeText("Ana\n")
        XCTAssertTrue(app.buttons["people-chip-Ana"].waitForExistence(timeout: 5))
        let tags = app.textFields["tagsField"]
        tags.tap()
        tags.typeText("rainy day\n")
        XCTAssertTrue(app.buttons["tags-chip-rainy day"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "quick-log-details")
        seal(app, drawer: "Films")

        // The toast opens the entry's details, which save as you go.
        app.descendants(matching: .any)["savouredToast"].tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["people-chip-Ana"].exists)
        XCTAssertTrue(app.buttons["tags-chip-rainy day"].exists)
        XCTAssertTrue(app.buttons["addPhotosButton"].exists, "No way to add photos to a sealed entry")
        let moreTags = app.textFields["tagsField"]
        moreTags.tap()
        moreTags.typeText("cinema\n")
        XCTAssertTrue(app.buttons["tags-chip-cinema"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "entry-details")
        app.buttons["entryDetailsDone"].tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForNonExistence(timeout: 10))

        // Next time, Ana and the tags are suggested as you type.
        draw("Savour a film", in: app)
        addNew("Past Lives", in: app)
        app.buttons["when-Today"].tap()
        app.buttons["quickLogDetails"].tap()
        let again = app.textFields["peopleField"]
        XCTAssertTrue(again.waitForExistence(timeout: 5))
        again.tap()
        again.typeText("an")
        XCTAssertTrue(app.buttons["people-suggestion-Ana"].waitForExistence(timeout: 5))
        app.buttons["people-suggestion-Ana"].tap()
        XCTAssertTrue(app.buttons["people-chip-Ana"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tags-suggestion-rainy day"].exists || app.buttons["tags-suggestion-cinema"].exists)
    }

    @MainActor
    func testThePrintHeadGuessesTearsAndTypes() {
        let app = launch(["-resetState", "-sampleData"])
        let pill = app.buttons["quickLogButton"]
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
        pill.tap()
        XCTAssertTrue(app.navigationBars["What did you savour?"].waitForExistence(timeout: 10))
        app.buttons["Savour a café"].tap()

        // The blank prints the café savoured last, and says where the guess came from.
        let printed = app.descendants(matching: .any)["printedGuess"]
        XCTAssertTrue(printed.waitForExistence(timeout: 10))
        XCTAssertEqual(printed.label, "Printed: Prufrock Coffee")
        let source = app.staticTexts["printSource"]
        XCTAssertEqual(source.label, "Again? · 1 of 3")
        attachScreenshot(of: app, named: "print-head")

        // Tear it off for the next; swipe back to restore it.
        app.buttons["printNext"].tap()
        XCTAssertTrue(labelled("Printed: Monmouth", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(source.label, "Again? · 2 of 3")
        printed.swipeRight()
        XCTAssertTrue(labelled("Printed: Prufrock Coffee", in: app).waitForExistence(timeout: 5))

        // Typing prints the top result instead.
        let field = app.textFields["quickLogName"]
        field.tap()
        field.typeText("Kaff")
        XCTAssertTrue(labelled("Printed: Kaffeine", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["printSource"].label, "Top result")
        attachScreenshot(of: app, named: "print-head-typed")

        // That's it: Kaffeine is ranked, so it's a repeat visit.
        app.buttons["printAccept"].tap()
        XCTAssertTrue(labelled("Still No.", in: app, prefix: true).waitForExistence(timeout: 5))
    }

    @MainActor
    func testSearchListsNumberedResultsAndPicksFromTheMap() {
        // Fixed sample places instead of Apple Maps, so the results are the same every run.
        let app = launch(["-resetState", "-samplePlaces"])

        // Typing lists every match, numbered; the second is one tap away.
        draw("Savour a café", in: app)
        let field = app.textFields["quickLogName"]
        field.tap()
        field.typeText("coffee")
        let second = app.buttons["pick-Prufrock Coffee"]
        XCTAssertTrue(second.waitForExistence(timeout: 10), "No list of results")
        XCTAssertTrue(second.label.hasPrefix("2. Prufrock Coffee"), second.label)
        XCTAssertTrue(app.buttons["pick-Origin Coffee"].exists, "Only the top result was listed")
        attachScreenshot(of: app, named: "quick-log-results")
        second.tap()
        let picked = app.staticTexts["quickLogItem"]
        XCTAssertTrue(picked.waitForExistence(timeout: 5))
        XCTAssertEqual(picked.label, "Prufrock Coffee")
        seal(app, drawer: "Cafés")

        // The same results on the map. Prufrock is in the drawer now, so it's listed there and
        // the rest renumber: Monmouth 1, Workshop 2, Origin 3. Tap pin 2, then "This one".
        draw("Savour a café", in: app)
        let again = app.textFields["quickLogName"]
        again.tap()
        again.typeText("coffee")
        let workshop = app.buttons["pick-Workshop Coffee"]
        XCTAssertTrue(workshop.waitForExistence(timeout: 10))
        XCTAssertTrue(workshop.label.hasPrefix("2. Workshop Coffee"), workshop.label)
        app.segmentedControls.buttons["Map"].tap()
        let pin = app.buttons["pin-2"]
        XCTAssertTrue(pin.waitForExistence(timeout: 10), "No numbered pins on the map")
        if !pin.isHittable {
            app.swipeUp()
        }
        pin.tap()
        let choose = app.buttons["mapPick"]
        XCTAssertTrue(choose.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "quick-log-results-map")
        choose.tap()
        XCTAssertTrue(picked.waitForExistence(timeout: 5))
        XCTAssertEqual(picked.label, "Workshop Coffee")
        // Prufrock is already ranked, so Workshop meets it in a duel.
        XCTAssertTrue(app.staticTexts["Which did you savour more?"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testJournalChipsDrawTheirOwnBlank() {
        let app = launch(["-resetState"])

        // "The last film you saw" goes straight to a film blank: no grid asking what it was.
        let film = app.buttons["start-films"]
        XCTAssertTrue(film.waitForExistence(timeout: 10))
        film.tap()
        XCTAssertTrue(app.textFields["quickLogName"].waitForExistence(timeout: 10), "The film chip didn't draw a blank")
        XCTAssertFalse(app.buttons["Savour a café"].exists, "The film chip showed the grid")
        addNew("Perfect Days", in: app)
        // Films are a log, so it asks when: proof the blank was a film.
        XCTAssertTrue(app.staticTexts["When?"].waitForExistence(timeout: 5))
        app.buttons["when-Today"].tap()
        seal(app, drawer: "Films")

        // "Your favourite café" draws a café blank. The film filled the Journal, which swaps the
        // chips for the feed, so this runs in a fresh launch with an empty one.
        app.terminate()
        let fresh = launch(["-resetState"])
        fresh.buttons["start-cafes"].tap()
        XCTAssertTrue(fresh.textFields["quickLogName"].waitForExistence(timeout: 10), "The café chip didn't draw a blank")
        XCTAssertFalse(fresh.buttons["Savour a film"].exists, "The café chip showed the grid")
        addNew("Corner Kiosk", in: fresh)
        XCTAssertEqual(fresh.staticTexts["quickLogSummary"].label, "No. 1 in Cafés")
    }

    @MainActor
    func testTheMapBrowsesWithNothingTypedAndSearchesThisArea() {
        let app = launch(["-resetState", "-samplePlaces"])
        draw("Savour a café", in: app)

        // Nothing typed: find it on the map instead.
        let find = app.buttons["findOnMap"]
        XCTAssertTrue(find.waitForExistence(timeout: 5), "No way to look on the map")
        find.tap()
        XCTAssertTrue(app.descendants(matching: .any)["resultsMap"].waitForExistence(timeout: 10))

        // "Search this area" looks for cafés where the map is.
        let searchHere = app.buttons["searchThisArea"]
        XCTAssertTrue(searchHere.waitForExistence(timeout: 10))
        searchHere.tap()
        let pin = app.buttons["pin-1"]
        XCTAssertTrue(pin.waitForExistence(timeout: 10), "Searching this area put no pins down")
        attachScreenshot(of: app, named: "quick-log-browse-map")
        if !pin.isHittable {
            app.swipeUp()
        }
        pin.tap()
        let choose = app.buttons["mapPick"]
        XCTAssertTrue(choose.waitForExistence(timeout: 5))
        choose.tap()
        let picked = app.staticTexts["quickLogItem"]
        XCTAssertTrue(picked.waitForExistence(timeout: 5))
        XCTAssertEqual(picked.label, "Monmouth Coffee")
    }
}
