import XCTest

/// Rating while savouring: the relish scale for stars and logs, and the ranked duel's Skip.
final class RatingUITests: UITestCase {
    @MainActor
    func testStarsRateInHalvesAndTheRatingCanBeChanged() {
        let app = launch(["-resetState"])
        // Custom collections rate with the relish scale (stars).
        openCollectionsAndWait(app)
        app.buttons["newCollectionButton"].tap()
        let name = app.textFields["collectionNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap()
        name.typeText("Concerts")
        tapSaveCollection(app)
        XCTAssertTrue(app.buttons["Concerts drawer"].waitForExistence(timeout: 5))

        draw("Savour in Concerts", in: app)
        addNew("Bonobo at the Roundhouse", in: app)
        // 65% of the way along five ā is the left half of the fourth: 3½.
        let scale = app.descendants(matching: .any)["relishScale"]
        XCTAssertTrue(scale.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "relish-scale")
        scale.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5)).tap()
        seal(app, drawer: "Concerts")

        // The details show 3½, and the rating can be changed there. (VoiceOver's adjust action
        // steps by halves; XCUITest on iOS can't drive it, so RelishInputTests cover that.)
        app.descendants(matching: .any)["savouredToast"].tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForExistence(timeout: 10))
        let rating = app.descendants(matching: .any)["relishScale"]
        XCTAssertTrue(rating.waitForExistence(timeout: 5))
        XCTAssertEqual(rating.value as? String, "3½ of 5, Lovely")
        // 75%: the right half of the fourth, so 4.
        rating.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        XCTAssertEqual(rating.value as? String, "4 of 5, Lovely")
        attachScreenshot(of: app, named: "relish-details")
    }

    @MainActor
    func testAFilmCanBeRatedOptionallyAndTheRatingCleared() {
        let app = launch(["-resetState"])
        draw("Savour a film", in: app)
        addNew("Perfect Days", in: app)
        app.buttons["when-Today"].tap()

        // Logs can say how it landed, but don't have to: 75% along five ā is 4.
        let scale = app.descendants(matching: .any)["relishScale"]
        XCTAssertTrue(scale.waitForExistence(timeout: 5), "No optional rating for a film")
        scale.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        XCTAssertEqual(app.staticTexts["quickLogSummary"].label, "Lovely")
        attachScreenshot(of: app, named: "film-optional-rating")
        seal(app, drawer: "Films")

        // In the details it can be changed or cleared.
        app.descendants(matching: .any)["savouredToast"].tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForExistence(timeout: 10))
        let rating = app.descendants(matching: .any)["relishScale"]
        XCTAssertTrue(rating.waitForExistence(timeout: 5))
        XCTAssertEqual(rating.value as? String, "4 of 5, Lovely")
        app.buttons["clearRating"].tap()
        XCTAssertEqual(rating.value as? String, "Not rated")
    }

    @MainActor
    func testSkippingTheDuelSealsUnrankedAndItDuelsNextTime() {
        let app = launch(["-resetState", "-sampleData"])
        draw("Savour a café", in: app)
        addNew("Corner Kiosk", in: app)
        XCTAssertTrue(app.staticTexts["Which did you savour more?"].waitForExistence(timeout: 5))

        // Skip: straight to the seal, with no place in the ranking.
        app.buttons["duelSkip"].tap()
        XCTAssertTrue(app.textFields["quickLogNote"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["quickLogSummary"].exists, "A skipped duel still placed it")
        seal(app, drawer: "Cafés")

        // Next time it's still unranked, so it duels.
        draw("Savour a café", in: app)
        let field = app.textFields["quickLogName"]
        field.tap()
        field.typeText("Corner")
        app.buttons["pick-Corner Kiosk"].tap()
        XCTAssertTrue(app.staticTexts["Which did you savour more?"].waitForExistence(timeout: 5))
    }
}
