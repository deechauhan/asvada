import XCTest

/// The lucky dip (#159): spin the cabinet for a forgotten keepsake, handed over face down.
final class LuckyDipUITests: UITestCase {
    @MainActor
    func testALuckyDipHandsOverAKeepsakeFaceDown() {
        let app = launch(["-resetState", "-sampleData"])
        openCollectionsAndWait(app)
        let dip = app.buttons["luckyDipButton"]
        XCTAssertTrue(dip.waitForExistence(timeout: 10), "No Lucky dip button under the cabinet")
        dip.tap()

        // The spin takes a couple of seconds, then the keepsake rises face down.
        let back = app.buttons["luckyDipBack"]
        XCTAssertTrue(back.waitForExistence(timeout: 15), "No keepsake after the spin")
        attachScreenshot(of: app, named: "lucky-dip-face-down")
        back.tap()
        XCTAssertTrue(app.buttons["luckyDipOpen"].waitForExistence(timeout: 5), "It didn't turn over")
        attachScreenshot(of: app, named: "lucky-dip")

        // Put back closes it and leaves you at the cabinet.
        app.buttons["luckyDipPutBack"].tap()
        XCTAssertTrue(back.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Collections"].exists)
    }
}
