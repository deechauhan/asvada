import Testing
@testable import Features

struct AppTabTests {
    @Test func hasFourTabsInOrder() {
        #expect(AppTab.allCases == [.timeline, .collections, .map, .settings])
        #expect(AppTab.allCases.map(\.title) == ["Timeline", "Collections", "Map", "Settings"])
    }

    @Test func restoresStoredTab() {
        #expect(AppTab.restored(from: "map") == .map)
        #expect(AppTab.restored(from: AppTab.settings.rawValue) == .settings)
    }

    @Test func unknownOrMissingFallsBackToTimeline() {
        #expect(AppTab.restored(from: nil) == .timeline)
        #expect(AppTab.restored(from: "") == .timeline)
        #expect(AppTab.restored(from: "archive") == .timeline)
    }
}
