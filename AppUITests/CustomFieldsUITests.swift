import XCTest

/// Custom fields (#22): a collection adds its own fields in Customise, and they appear in the
/// entry form.
final class CustomFieldsUITests: UITestCase {
    @MainActor
    func testAFieldAddedToADrawerAppearsAmongTheDetailsWhenSealing() {
        let app = launch(["-resetState", "-sampleData"])
        openCollectionsAndWait(app)
        openDrawer(app, "Films")

        // Customise: add a text field called Seat.
        let customise = app.buttons["drawerCustomise"]
        XCTAssertTrue(customise.waitForExistence(timeout: 10))
        customise.tap()
        // The form is a lazy list: "Your fields" isn't in it until it has scrolled that far.
        let add = app.buttons["addFieldButton"]
        XCTAssertTrue(app.buttons["saveCollectionButton"].waitForExistence(timeout: 10))
        for _ in 0 ..< 6 where !add.exists {
            app.swipeUp()
        }
        XCTAssertTrue(add.waitForExistence(timeout: 5), "No way to add a field")
        scrollUntilVisible(add, in: app)
        add.tap()
        let name = app.textFields["fieldNameField"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Seat")
        attachScreenshot(of: app, named: "custom-fields-editor")
        app.buttons["saveCollectionButton"].tap()
        XCTAssertTrue(app.buttons["saveCollectionButton"].waitForNonExistence(timeout: 10))

        // Leave the drawer, then log a film: the field is among the details.
        app.navigationBars["Films"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Films"].waitForNonExistence(timeout: 10))
        draw("Savour a film", in: app)
        addNew("Zodiac", in: app)
        let details = app.buttons["quickLogDetails"]
        XCTAssertTrue(details.waitForExistence(timeout: 10))
        details.tap()
        let field = app.descendants(matching: .any)["customField-Seat"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "The field isn't in the entry form")
        attachScreenshot(of: app, named: "custom-fields-entry")
    }
}
