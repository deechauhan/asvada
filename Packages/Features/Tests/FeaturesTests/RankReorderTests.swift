import Foundation
import Model
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct RankReorderTests {
    @Test func movingDownLandsOneEarlierThanTheGap() {
        // onMove's destination is a gap index: dragging row 0 below row 1 reports gap 2.
        #expect(RankReorder.position(movingFrom: 0, toOffset: 2) == 1)
        #expect(RankReorder.position(movingFrom: 0, toOffset: 4) == 3)
    }

    @Test func movingUpLandsInTheGap() {
        #expect(RankReorder.position(movingFrom: 3, toOffset: 1) == 1)
        #expect(RankReorder.position(movingFrom: 2, toOffset: 0) == 0)
        // Dropping a row back where it was changes nothing.
        #expect(RankReorder.position(movingFrom: 2, toOffset: 2) == 2)
        #expect(RankReorder.position(movingFrom: 2, toOffset: 3) == 2)
    }

    @Test func theArrowsStopAtEitherEnd() {
        #expect(RankReorder.step(0, by: -1, count: 4) == nil)
        #expect(RankReorder.step(0, by: 1, count: 4) == 1)
        #expect(RankReorder.step(3, by: 1, count: 4) == nil)
        #expect(RankReorder.step(3, by: -1, count: 4) == 2)
    }

    @Test func aRankedItemMovesAndTheOthersKeepTheirOrder() throws {
        let container = try ArtifactsStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        let cafes = try #require(try repository.collections().first { $0.kind == .cafes })
        for name in ["A", "B", "C", "D"] {
            let item = try repository.addManualItem(ManualItemDraft(name: name), in: cafes)
            repository.place(item, at: repository.ranking(of: cafes).count, in: cafes)
        }
        #expect(repository.ranking(of: cafes).map(\.name) == ["A", "B", "C", "D"])

        // What the sheet does for "move A down": take it from the top and place it at index 1.
        let first = try #require(repository.ranking(of: cafes).first)
        repository.place(first, at: 1, in: cafes)
        #expect(repository.ranking(of: cafes).map(\.name) == ["B", "A", "C", "D"])
        // And "move D to the top".
        let last = try #require(repository.ranking(of: cafes).last)
        repository.place(last, at: 0, in: cafes)
        #expect(repository.ranking(of: cafes).map(\.name) == ["D", "B", "A", "C"])
    }

    @Test func aDuelCardShowsTheNewestPhotoOfTheNewestEntryThatHasOne() throws {
        let container = try ArtifactsStore.makeContainer(.inMemory)
        let context = container.mainContext
        let repository = Repository(context: context)
        try BuiltInCollections.seedIfNeeded(in: context)
        let cafes = try #require(try repository.collections().first { $0.kind == .cafes })
        let item = try repository.addManualItem(ManualItemDraft(name: "Prufrock"), in: cafes)
        #expect(item.latestThumbnailData == nil)

        let older = repository.addEntry(to: item, date: Date(timeIntervalSince1970: 1_000_000))
        let newer = repository.addEntry(to: item, date: Date(timeIntervalSince1970: 2_000_000))
        func attach(_ byte: UInt8, to entry: Entry, takenAt: TimeInterval) {
            let photo = Photo(imageData: Data([byte]), thumbnailData: Data([byte]), takenAt: Date(timeIntervalSince1970: takenAt))
            context.insert(photo)
            photo.entry = entry
        }
        attach(1, to: older, takenAt: 10)
        // The newest entry has no photo yet: the older one's shows.
        #expect(item.latestThumbnailData == Data([1]))
        attach(2, to: newer, takenAt: 20)
        attach(3, to: newer, takenAt: 30)
        #expect(item.latestThumbnailData == Data([3]))
    }
}
