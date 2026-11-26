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
        let add = app.buttons["addFieldButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "No way to add a field")
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
