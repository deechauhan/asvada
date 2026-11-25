import Foundation
import Model
import Testing
@testable import Features

@MainActor
struct QuickLogFlowTests {
    @Test func eachRatingModeHasItsSavourStep() {
        #expect(QuickLogFlow.step(for: .ranked, rank: nil, othersRanked: 7) == .duel(count: 7))
        #expect(QuickLogFlow.step(for: .ranked, rank: 1, othersRanked: 7) == .still(rank: 2))
        #expect(QuickLogFlow.step(for: .stars, rank: nil, othersRanked: 0) == .relish)
        #expect(QuickLogFlow.step(for: .log, rank: nil, othersRanked: 0) == .when)
        #expect(QuickLogFlow.step(for: .checklist, rank: nil, othersRanked: 0) == .stamp)
    }

    @Test func aRepeatVisitToARankedItemSkipsTheDuel() {
        // Already No. 1: "Still No. 1?", whatever else is ranked.
        #expect(QuickLogFlow.step(for: .ranked, rank: 0, othersRanked: 0) == .still(rank: 1))
    }

    @Test func theFirstTimeHasNoCountAndLaterOnesDo() {
        #expect(QuickLogFlow.timesLabel(previousEntries: 0) == nil)
        #expect(QuickLogFlow.timesLabel(previousEntries: 2) == "That makes it ×3")
    }

    @Test func theToastSaysHowLongAndWhere() {
        #expect(QuickLogFlow.toast(seconds: 6.43, collection: "Cafés") == "Savoured in 6.4 s · it's in your Cafés drawer")
        #expect(QuickLogFlow.toast(seconds: -1, collection: "Films") == "Savoured in 0.0 s · it's in your Films drawer")
    }

    @Test func whenCountsBackFromNow() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        #expect(LogWhen.today.date(from: now, calendar: calendar) == now)
        #expect(LogWhen.yesterday.date(from: now, calendar: calendar) == now.addingTimeInterval(-86400))
        #expect(LogWhen.lastWeek.date(from: now, calendar: calendar) == now.addingTimeInterval(-7 * 86400))
    }

    @Test func typingMatchesThingsAlreadyInTheDrawer() {
        let prufrock = Item(name: "Prufrock Coffee")
        let monmouth = Item(name: "Monmouth")
        let cafe = Item(name: "Café Kitsuné")
        let items = [prufrock, monmouth, cafe]
        #expect(QuickLogFlow.matches(items, query: "coffee").map(\.name) == ["Prufrock Coffee"])
        #expect(QuickLogFlow.matches(items, query: "cafe").map(\.name) == ["Café Kitsuné"])
        #expect(QuickLogFlow.matches(items, query: "  ").count == 3)
        #expect(QuickLogFlow.hasExactMatch(items, query: " monmouth "))
        #expect(!QuickLogFlow.hasExactMatch(items, query: "Monmouth Coffee"))
    }
}
