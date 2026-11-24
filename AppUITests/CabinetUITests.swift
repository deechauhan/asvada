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
}
