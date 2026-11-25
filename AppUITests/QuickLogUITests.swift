import XCTest

/// Quick-log end to end: draw a blank, say what it was, savour it its collection's way, seal.
final class QuickLogUITests: UITestCase {
    /// Opens quick-log from the pill and draws `blank` from the grid ("Savour a café").
    @MainActor
    private func draw(_ blank: String, in app: XCUIApplication) {
        let pill = app.buttons["quickLogButton"]
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
        pill.tap()
        XCTAssertTrue(app.navigationBars["What did you savour?"].waitForExistence(timeout: 10))
        app.buttons[blank].tap()
        XCTAssertTrue(app.textFields["quickLogName"].waitForExistence(timeout: 5))
    }

    /// Types a new name and adds it by hand.
    @MainActor
    private func addNew(_ name: String, in app: XCUIApplication) {
        let field = app.textFields["quickLogName"]
        field.tap()
        field.typeText(name)
        let add = app.buttons["quickLogAddNew"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
    }

    /// Holds the ā and waits for the toast.
    @MainActor
    private func seal(_ app: XCUIApplication, drawer: String) {
        let seal = app.descendants(matching: .any)["sealButton"]
        XCTAssertTrue(seal.waitForExistence(timeout: 5))
        seal.press(forDuration: 1.2)
        // The sheet closes, then the toast shows over the app.
        XCTAssertTrue(app.textFields["quickLogNote"].waitForNonExistence(timeout: 10), "The sheet didn't close after sealing")
        let toast = app.descendants(matching: .any)["savouredToast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 10), "No toast after sealing")
        XCTAssertTrue(toast.label.hasPrefix("Savoured in "), toast.label)
        XCTAssertTrue(toast.label.hasSuffix("it's in your \(drawer) drawer"), toast.label)
    }

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
}
