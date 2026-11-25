import XCTest

/// Draw a keepsake: the hand of blanks on the savour pill, and the same hand as a grid on tap.
final class HandUITests: UITestCase {
    @MainActor
    func testATapOpensTheHandAsAGrid() {
        let app = launch(["-resetState", "-sampleData"])
        let pill = app.buttons["quickLogButton"]
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
        pill.tap()
        XCTAssertTrue(app.navigationBars["What did you savour?"].waitForExistence(timeout: 5))
        // One blank per collection, and the latest things savoured as "Again?" chips.
        XCTAssertTrue(app.buttons["Stamp a country"].exists)
        XCTAssertTrue(labelled("Again: ", in: app, prefix: true).waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "hand-grid")
        app.buttons["Savour a café"].tap()
        XCTAssertTrue(app.navigationBars["Savour a café"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["drawnBlank"].exists)
        attachScreenshot(of: app, named: "hand-drawn")
        // Draw another is in the sheet's glass toolbar, which drops a tap while it's still
        // settling (as openChest notes), so tap until the hand is back.
        let grid = app.navigationBars["What did you savour?"]
        for _ in 0 ..< 3 where !grid.exists {
            app.buttons["drawAnotherButton"].tap()
            _ = grid.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(grid.exists, "Draw another didn't bring the hand back")
    }

    @MainActor
    func testHoldAndSlideDrawsABlank() {
        let app = launch(["-resetState"])
        let pill = app.buttons["quickLogButton"]
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
        // Hold the pill, then slide up and far to the left: the first blank, Cafés.
        let start = pill.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(
            forDuration: 0.4,
            thenDragTo: start.withOffset(CGVector(dx: -160, dy: -30)),
            withVelocity: 400,
            thenHoldForDuration: 0.2,
        )
        XCTAssertTrue(app.navigationBars["Savour a café"].waitForExistence(timeout: 5), "letting go didn't draw the blank")
    }

    @MainActor
    func testTheHandFansOverThePill() {
        let runs = [
            (["-resetState", "-sampleData", "-showHand"], "hand"),
            (["-resetState", "-sampleData", "-showHand", "-forceDarkMode"], "hand-dark"),
        ]
        for (args, name) in runs {
            let app = launch(args)
            let hand = app.descendants(matching: .any)["handOfBlanks"]
            XCTAssertTrue(hand.waitForExistence(timeout: 10))
            XCTAssertEqual(hand.label, "Savour a café", "the lifted blank names itself")
            // Let the fan settle before the screenshot.
            sleep(1)
            attachScreenshot(of: app, named: name)
            app.terminate()
        }
    }
}
