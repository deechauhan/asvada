import XCTest

/// First launch: welcome, stamp your passport, see the spread, savour one thing.
final class OnboardingUITests: UITestCase {
    @MainActor
    func testOnboardingStampsAPassportAndSavoursAFirstKeepsake() {
        let app = launch(["-resetState", "-onboarding"])
        let begin = app.buttons["onboardingBegin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 10))
        attachScreenshot(of: app, named: "onboarding-welcome")
        begin.tap()

        // Stamp Japan by search (Return stamps it), then Australia from Oceania's strip.
        let search = app.textFields["stampSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Japan\n")
        app.buttons["continent-Oceania"].tap()
        let australia = app.buttons["stamp-AU"]
        XCTAssertTrue(australia.waitForExistence(timeout: 5))
        australia.tap()
        let counter = app.staticTexts["stampCounter"]
        XCTAssertEqual(counter.label, "2 countries · 1% of the world")
        XCTAssertEqual(app.descendants(matching: .any)["inkGlobe"].label, "World map, 2 countries inked: Australia and Japan")
        XCTAssertTrue(australia.isSelected)

        // Unroll the globe into the flat map, then carry the rubber stamp to Brazil and lift:
        // its foot sits 44 pt above the finger.
        let map = unrollTheGlobe(app)
        let rubberStamp = app.buttons["rubberStamp"]
        XCTAssertTrue(rubberStamp.waitForExistence(timeout: 5))
        let brazil = map.coordinate(withNormalizedOffset: CGVector(dx: 0.36, dy: 0))
            .withOffset(CGVector(dx: 0, dy: map.frame.height * 0.65 + 44))
        rubberStamp.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.3, thenDragTo: brazil)
        XCTAssertTrue(labelled("World map, 3 countries inked", in: app, prefix: true).waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["passport-BR"].exists)
        attachScreenshot(of: app, named: "onboarding-stamp")

        // Long-press a stamp in the passport to wash it off; Undo brings it back.
        app.descendants(matching: .any)["passport-BR"].press(forDuration: 1.0)
        XCTAssertTrue(labelled("World map, 2 countries inked", in: app, prefix: true).waitForExistence(timeout: 5))
        let undo = app.buttons["washOffUndo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "onboarding-stamp-washed-off")
        undo.tap()
        XCTAssertTrue(labelled("World map, 3 countries inked", in: app, prefix: true).waitForExistence(timeout: 5))
        app.buttons["onboardingContinue"].tap()

        // The passport spread, ready to share.
        XCTAssertTrue(app.descendants(matching: .any)["passportSpread"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["sharePassport"].waitForExistence(timeout: 10))
        attachScreenshot(of: app, named: "onboarding-passport")
        app.buttons["onboardingContinue"].tap()

        // One thing you loved: hold the ā.
        let seal = app.descendants(matching: .any)["sealButton"]
        XCTAssertTrue(seal.waitForExistence(timeout: 10))
        seal.press(forDuration: 1.2)
        XCTAssertTrue(app.descendants(matching: .any)["waxSeal"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "onboarding-first-keepsake")
        app.buttons["onboardingContinue"].tap()

        // Into the app, with the passport and the keepsake in their drawers.
        XCTAssertTrue(app.navigationBars["Journal"].waitForExistence(timeout: 10))
        openCollectionsAndWait(app)
        openChest(app)
        XCTAssertTrue(labelled("3 stamped", in: app, prefix: true).waitForExistence(timeout: 5))
        XCTAssertTrue(labelled("1 ranked, number one My favourite café", in: app).exists)
    }

    @MainActor
    func testEveryStepCanBeSkipped() {
        let app = launch(["-resetState", "-onboarding"])
        let skip = app.buttons["onboardingSkip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        for _ in 0 ..< 4 {
            skip.tap()
        }
        XCTAssertTrue(app.navigationBars["Journal"].waitForExistence(timeout: 10))
    }

    /// Taps Unroll and waits for the flat ink map the globe unrolls into.
    @MainActor
    private func unrollTheGlobe(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["unrollGlobe"].tap()
        let map = app.descendants(matching: .any)["inkWorldMap"]
        XCTAssertTrue(map.waitForExistence(timeout: 5))
        XCTAssertEqual(map.label, "World map, 2 countries inked: Australia and Japan")
        return map
    }
}
