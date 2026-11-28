import Foundation
import Model
import Storage
import SwiftData
import SwiftUI
import Testing
@testable import Features

struct DrawerSummaryTests {
    @Test(arguments: RatingMode.allCases)
    func emptyDrawersNeverSayZero(mode: RatingMode) {
        let summary = DrawerSummary.make(mode: mode, itemCount: 0, entryCount: 0, knownTotal: 195)
        #expect(summary.numeral == nil)
        #expect(summary.caption == "Nothing savoured yet")
        #expect(!summary.spoken.contains("0"))
    }

    @Test func checklistShowsShareOfTheKnownSet() {
        let summary = DrawerSummary.make(mode: .checklist, itemCount: 23, entryCount: 30, knownTotal: 195)
        #expect(summary.numeral == "23")
        #expect(summary.caption == "stamped · 12%")
    }

    @Test func checklistNeverRoundsARealVisitDownToZeroPercent() {
        let summary = DrawerSummary.make(mode: .checklist, itemCount: 1, entryCount: 1, knownTotal: 195)
        #expect(summary.caption == "stamped · 1%")
    }

    @Test func rankedNamesTheLeader() {
        let summary = DrawerSummary.make(mode: .ranked, itemCount: 27, entryCount: 40, leader: "Prufrock")
        #expect(summary.numeral == "27")
        #expect(summary.caption == "No. 1 Prufrock")
        #expect(summary.spoken == "27 ranked, number one Prufrock")
    }

    @Test func logCountsEntries() {
        let summary = DrawerSummary.make(mode: .log, itemCount: 3, entryCount: 14)
        #expect(summary.numeral == "14")
        #expect(summary.caption == "logged")
    }

    @Test func starsCountItems() {
        #expect(DrawerSummary.make(mode: .stars, itemCount: 5, entryCount: 9).numeral == "5")
    }
}

@MainActor
struct DrawerItemsTests {
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try ArtifactsStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        try PreviewData.fillBuiltIns(repository)
    }

    private func collection(_ kind: CollectionKind) throws -> ExperienceCollection {
        let match = try repository.collections().first { $0.kind == kind }
        return try #require(match)
    }

    @Test func rankedDrawersFanTheTopThreeByRank() throws {
        let cafes = try collection(.cafes)
        #expect(cafes.drawerItems().map(\.name) == ["Prufrock Coffee", "Monmouth", "Kaffeine"])
        #expect(cafes.drawerSummary.caption == "No. 1 Prufrock Coffee")
    }

    @Test func otherDrawersFanTheMostRecent() throws {
        let countries = try collection(.countries)
        #expect(countries.drawerItems().map(\.name) == ["Portugal", "Japan", "Peru"])
        #expect(countries.drawerSummary.caption == "stamped · 2%")
    }

    @Test func emptyBuiltInsShowTheGhostLine() throws {
        let restaurants = try collection(.restaurants)
        #expect(restaurants.drawerItems().isEmpty)
        #expect(restaurants.drawerSummary.numeral == nil)
    }

    @Test func countryItemsKnowTheirIsoCode() {
        let item = Item(name: "Japan", externalRef: "iso:JP")
        #expect(item.isoCode == "JP")
    }
}

struct CabinetOrderTests {
    @Test func movingLaterCountsPastTheRemovedItem() {
        #expect(CabinetOrder.destination(moving: 0, onto: 2) == 3)
    }

    @Test func movingEarlierLandsInTheTargetSlot() {
        #expect(CabinetOrder.destination(moving: 3, onto: 1) == 1)
    }

    @Test func droppingOnTheNextDrawerSwapsThem() {
        var order = ["a", "b", "c"]
        order.move(fromOffsets: IndexSet(integer: 0), toOffset: CabinetOrder.destination(moving: 0, onto: 1))
        #expect(order == ["b", "a", "c"])
    }
}
