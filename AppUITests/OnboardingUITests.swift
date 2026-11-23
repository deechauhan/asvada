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

        // Stamp two countries by search; the counter rolls up.
        let search = app.textFields["stampSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Japan")
        app.buttons["flag-JP"].tap()
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "Portugal\n")
        app.buttons["flag-PT"].tap()
        let counter = app.staticTexts["stampCounter"]
        XCTAssertEqual(counter.label, "2 countries · 1% of the world")
        XCTAssertEqual(app.descendants(matching: .any)["inkWorldMap"].label, "World map, 2 countries inked: Japan and Portugal")
        attachScreenshot(of: app, named: "onboarding-stamp")
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
        XCTAssertTrue(labelled("2 stamped", in: app, prefix: true).waitForExistence(timeout: 5))
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
}
