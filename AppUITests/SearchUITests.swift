import XCTest

/// Search across everything (#45): one field on the Journal and in Collections, with results
/// grouped by collection.
final class SearchUITests: UITestCase {
    @MainActor
    func testSearchingTheJournalGroupsResultsByCollection() {
        let app = launch(["-resetState", "-sampleData"])
        XCTAssertTrue(app.tabBars.buttons["Journal"].waitForExistence(timeout: 10))
        search(app, for: "perfect")

        let result = app.descendants(matching: .any)["searchResult"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10), "No result for a film in the sample data")
        XCTAssertTrue(app.staticTexts["Films"].exists, "Results aren't grouped under their collection")
        attachScreenshot(of: app, named: "search-results")

        // Tapping a result opens the item.
        result.tap()
        XCTAssertTrue(app.staticTexts["itemCount"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testSearchingCollectionsFindsAnItemAndSaysWhenThereIsNone() {
        let app = launch(["-resetState", "-sampleData"])
        openCollectionsAndWait(app)
        search(app, for: "zzzz")
        XCTAssertTrue(
            app.descendants(matching: .any)["searchNoResults"].waitForExistence(timeout: 10),
            "No empty state for a search that matches nothing",
        )

        let field = app.searchFields.firstMatch
        field.clearText()
        field.typeText("past")
        XCTAssertTrue(app.descendants(matching: .any)["searchResult"].firstMatch.waitForExistence(timeout: 10))
    }

    /// Taps the search field on the current screen and types `text`.
    @MainActor
    private func search(_ app: XCUIApplication, for text: String) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "No search field")
        field.tap()
        field.typeText(text)
    }
}

@MainActor
private extension XCUIElement {
    /// Deletes whatever is typed in the field.
    func clearText() {
        guard let text = value as? String, !text.isEmpty else { return }
        tap()
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count))
    }
}
