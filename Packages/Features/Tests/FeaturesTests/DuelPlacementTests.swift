import Testing
@testable import Features

struct DuelPlacementTests {
    @Test func theNewcomerIsInsertedAtItsPlace() {
        #expect(DuelPlacement.inserting("N", into: ["a", "b", "c"], at: 0) == ["N", "a", "b", "c"])
        #expect(DuelPlacement.inserting("N", into: ["a", "b", "c"], at: 2) == ["a", "b", "N", "c"])
        #expect(DuelPlacement.inserting("N", into: ["a", "b", "c"], at: 3) == ["a", "b", "c", "N"])
        #expect(DuelPlacement.inserting("N", into: [], at: 0) == ["N"])
    }

    @Test func anOutOfRangePlaceIsClamped() {
        #expect(DuelPlacement.inserting("N", into: ["a"], at: 9) == ["a", "N"])
        #expect(DuelPlacement.inserting("N", into: ["a"], at: -1) == ["N", "a"])
    }

    @Test(arguments: [
        // (ranked count, newcomer's place, rows shown)
        (0, 0, 0 ..< 1),
        (3, 1, 0 ..< 4),
        (9, 0, 0 ..< 5),
        (9, 4, 2 ..< 7),
        (9, 9, 5 ..< 10),
        (9, 8, 5 ..< 10),
        (20, 10, 8 ..< 13),
    ])
    func theWindowCentresOnTheNewcomerWithinTheList(count: Int, position: Int, expected: Range<Int>) {
        #expect(DuelPlacement.window(count: count, position: position) == expected)
    }

    /// Every place in every list up to 30: the newcomer's row is always shown, never past the end.
    @Test func theWindowAlwaysHoldsTheNewcomer() {
        for count in 0 ... 30 {
            for position in 0 ... count {
                let window = DuelPlacement.window(count: count, position: position)
                #expect(window.contains(position), "count \(count), place \(position)")
                #expect(window.lowerBound >= 0 && window.upperBound <= count + 1)
                #expect(window.count == min(DuelPlacement.windowSize, count + 1))
            }
        }
    }

    @Test func theLoserLeansAwayFromTheOther() {
        #expect(DuelPlacement.lean(.newcomer) < 0)
        #expect(DuelPlacement.lean(.other) > 0)
        #expect(DuelPlacement.drift(.newcomer) < 0)
        #expect(DuelPlacement.drift(.other) > 0)
    }

    @Test func theStampHoldsLessWithoutMotion() {
        #expect(DuelPlacement.holdSeconds(reduceMotion: true) < DuelPlacement.holdSeconds(reduceMotion: false))
        #expect(DuelPlacement.spoken(0, name: "Tiny Tea Stall") == "Tiny Tea Stall is No. 1")
    }
}
