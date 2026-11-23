import Testing
@testable import Features

struct AppTabTests {
    @Test func hasThreeTabsInOrder() {
        #expect(AppTab.allCases == [.journal, .collections, .atlas])
        #expect(AppTab.allCases.map(\.title) == ["Journal", "Collections", "Atlas"])
    }

    @Test func restoresStoredTab() {
        #expect(AppTab.restored(from: "atlas") == .atlas)
        #expect(AppTab.restored(from: AppTab.collections.rawValue) == .collections)
    }

    @Test func v1ValuesMapOntoTheNewTabs() {
        #expect(AppTab.restored(from: "timeline") == .journal)
        #expect(AppTab.restored(from: "map") == .atlas)
        #expect(AppTab.restored(from: "settings") == .journal)
    }

    @Test func unknownOrMissingFallsBackToJournal() {
        #expect(AppTab.restored(from: nil) == .journal)
        #expect(AppTab.restored(from: "") == .journal)
        #expect(AppTab.restored(from: "archive") == .journal)
    }
}
