import XCTest

/// The keepsake world: the template gallery, the seal, the design catalogue and the country
/// picker with its ink map.
final class KeepsakeUITests: UITestCase {
    @MainActor
    func testKeepsakeGallery() {
        let runs = [(["-keepsakeGallery"], "keepsakes-light"), (["-keepsakeGallery", "-forceDarkMode"], "keepsakes-dark")]
        for (args, name) in runs {
            let app = launch(args)
            XCTAssertTrue(app.navigationBars["Keepsakes"].waitForExistence(timeout: 10))
            // Each keepsake is a single VoiceOver element with a spoken summary.
            XCTAssertTrue(labelled("Passport stamp, Peru", in: app).waitForExistence(timeout: 5))
            // Every template in the kit is present and speaks for itself.
            let summaries = [
                "Receipt, Prufrock Coffee",
                "Menu card, Dishoom",
                "Ticket stub, Perfect Days",
                "Ticket stub, Past Lives",
                "Boarding pass, British Airways",
                "Postcard from Lisbon",
                "Concerts, Radiohead",
            ]
            for summary in summaries {
                XCTAssertTrue(labelled(summary, in: app, prefix: true).exists, "\(summary) keepsake missing")
            }
            // One screenshot per screenful, so every template is captured.
            attachScreenshot(of: app, named: name)
            for page in 2 ... 5 {
                app.swipeUp()
                attachScreenshot(of: app, named: "\(name)-\(page)")
            }
            app.terminate()
        }
    }

    @MainActor
    func testCountryPickerSearchesAndMultiSelects() {
        let app = launch(["-countryPicker"])
        XCTAssertTrue(app.navigationBars["Countries"].waitForExistence(timeout: 10))
        // Grouped by continent, with flags, before searching. The list is lazy, so check the first
        // continent (Africa); later ones aren't built until scrolled to.
        XCTAssertTrue(app.staticTexts["Africa"].waitForExistence(timeout: 5) || app.staticTexts["AFRICA"].exists)
        attachScreenshot(of: app, named: "country-picker")
        let search = app.searchFields["Search countries"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("japan")
        let japan = app.buttons["country-JP"]
        XCTAssertTrue(japan.waitForExistence(timeout: 5))
        japan.tap()
        // While searching, the search field takes over the navigation bar (and its "N stamped"
        // title), so check the rows' selected state instead.
        XCTAssertTrue(waitUntilSelected(japan, true))
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "portu")
        let portugal = app.buttons["country-PT"]
        portugal.tap()
        XCTAssertTrue(waitUntilSelected(portugal, true))
        // The ink map floods with both.
        let map = app.descendants(matching: .any)["inkWorldMap"]
        XCTAssertTrue(map.exists)
        XCTAssertEqual(map.label, "World map, 2 countries inked: Japan and Portugal")
        attachScreenshot(of: app, named: "country-picker-search")
        // Tapping again unpicks.
        portugal.tap()
        XCTAssertTrue(waitUntilSelected(portugal, false))
    }

    @MainActor
    func testHoldToSavourSealsTheKeepsake() {
        let app = launch(["-keepsakeGallery", "-resetState"])
        let seal = app.descendants(matching: .any)["sealButton"]
        XCTAssertTrue(seal.waitForExistence(timeout: 10))
        // A quick tap doesn't seal before the hold has been learned.
        seal.tap()
        XCTAssertFalse(app.descendants(matching: .any)["waxSeal"].waitForExistence(timeout: 2))
        // Holding past 0.6 s seals it.
        seal.press(forDuration: 1.2)
        XCTAssertTrue(app.descendants(matching: .any)["waxSeal"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "sealed")
    }

    @MainActor
    func testDesignCatalogLight() {
        let app = launch(["-designCatalog"])
        XCTAssertTrue(app.navigationBars["Design catalogue"].waitForExistence(timeout: 10))
        attachScreenshot(of: app, named: "design-catalog-light")
    }

    @MainActor
    func testDesignCatalogDark() {
        let app = launch(["-designCatalog", "-forceDarkMode"])
        XCTAssertTrue(app.navigationBars["Design catalogue"].waitForExistence(timeout: 10))
        attachScreenshot(of: app, named: "design-catalog-dark")
    }
}
