import XCTest

/// Xcode's accessibility audit over the main screens (#74): every control described, hit regions
/// big enough, traits right, text that grows with Dynamic Type and isn't clipped, at the default
/// size and at the largest accessibility size. Contrast is left to the design review: the
/// palette (CONCEPT.md) is a design decision, and glass over moving content reads differently on
/// every frame.
final class AccessibilityUITests: UITestCase {
    private let audits: XCUIAccessibilityAuditType = [
        .sufficientElementDescription,
        .hitRegion,
        .trait,
        .elementDetection,
        .dynamicType,
        .textClipped,
    ]

    @MainActor
    func testTheMainScreensPassTheAccessibilityAudit() throws {
        let app = launch(["-resetState"])
        try auditMainScreens(app, size: "default")
    }

    @MainActor
    func testTheMainScreensPassTheAuditAtTheLargestTextSize() throws {
        let app = launch([
            "-resetState",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        try auditMainScreens(app, size: "ax5")
    }

    /// The Journal, the cabinet, the Countries drawer with its globe, and quick-log's blanks,
    /// each audited and screenshotted.
    @MainActor
    private func auditMainScreens(_ app: XCUIApplication, size: String) throws {
        XCTAssertTrue(app.buttons["quickLogButton"].waitForExistence(timeout: 10))
        try audit(app, screen: "journal", size: size)

        openCollectionsAndWait(app)
        try audit(app, screen: "cabinet", size: size)

        openDrawer(app, "Countries")
        XCTAssertTrue(app.descendants(matching: .any)["inkGlobe"].waitForExistence(timeout: 10))
        try audit(app, screen: "countries", size: size)
        app.navigationBars["Countries"].buttons.firstMatch.tap()

        let pill = app.buttons["quickLogButton"]
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
        pill.tap()
        XCTAssertTrue(app.navigationBars["What did you savour?"].waitForExistence(timeout: 10))
        try audit(app, screen: "quick-log", size: size)
    }

    @MainActor
    private func audit(_ app: XCUIApplication, screen: String, size: String) throws {
        attachScreenshot(of: app, named: "a11y-\(screen)-\(size)")
        // Each issue is reported with what it found and where, so a Nightly log says which element
        // to fix (the bare "Text clipped" says neither). Reporting it here still fails the test.
        try app.performAccessibilityAudit(for: audits) { issue in
            let element = issue.element
            XCTFail(
                """
                \(screen) at \(size): \(issue.compactDescription) — \(issue.detailedDescription) \
                [element: "\(element?.label ?? "?")" id "\(element?.identifier ?? "?")" \
                type \(element.map { String(describing: $0.elementType) } ?? "?") \
                frame \(element.map { String(describing: $0.frame) } ?? "?")]
                """,
            )
            return true
        }
    }
}
