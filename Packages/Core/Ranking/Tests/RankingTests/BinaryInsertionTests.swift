import Testing
@testable import Ranking

struct BinaryInsertionTests {
    @Test(arguments: [(0, 0), (1, 1), (2, 2), (3, 2), (4, 3), (7, 3), (8, 4), (100, 7), (1000, 10)])
    func maximumComparisonsIsCeilLog2(count: Int, expected: Int) {
        #expect(BinaryInsertion.maximumComparisons(forCount: count) == expected)
    }

    @Test func anEmptyListPlacesAtOnceWithNoQuestions() {
        let insertion = BinaryInsertion(count: 0)
        #expect(insertion.isPlaced)
        #expect(insertion.comparisonIndex == nil)
        #expect(insertion.position == 0)
    }

    @Test func asksTheMiddleFirst() {
        let insertion = BinaryInsertion(count: 7)
        #expect(insertion.comparisonIndex == 3)
        #expect(insertion.remainingComparisonsAtMost == 3)
    }

    /// Every slot of every list up to 64 long: lands exactly there, within the bound.
    @Test func placesEverySlotExactlyWithinTheBound() {
        for count in 0 ... 64 {
            let bound = BinaryInsertion.maximumComparisons(forCount: count)
            for truth in 0 ... count {
                let insertion = place(count: count, truth: truth)
                #expect(insertion.position == truth, "count \(count), truth \(truth)")
                #expect(insertion.comparisonsMade <= bound, "count \(count), truth \(truth)")
            }
        }
    }

    /// Property: for random long lists the place is right, the questions stay within
    /// ceil(log2(n + 1)), every question points at a real item, and the hint never undercounts.
    @Test func randomListsKeepTheInvariants() {
        var random = SeededGenerator(seed: 40)
        for _ in 0 ..< 2000 {
            let count = Int.random(in: 0 ... 5000, using: &random)
            let truth = Int.random(in: 0 ... count, using: &random)
            var insertion = BinaryInsertion(count: count)
            var asked = 0
            while let index = insertion.comparisonIndex {
                #expect((0 ..< count).contains(index))
                #expect(insertion.remainingComparisonsAtMost >= 1)
                let promised = asked + insertion.remainingComparisonsAtMost
                #expect(promised <= BinaryInsertion.maximumComparisons(forCount: count))
                insertion.record(index < truth ? .worse : .better)
                asked += 1
            }
            #expect(insertion.position == truth)
            #expect(insertion.comparisonsMade == asked)
            #expect(asked <= BinaryInsertion.maximumComparisons(forCount: count))
        }
    }

    @Test func undoAsksTheSameQuestionAgain() {
        var insertion = BinaryInsertion(count: 10)
        let first = insertion.comparisonIndex
        insertion.record(.better)
        let second = insertion.comparisonIndex
        insertion.record(.worse)
        insertion.undo()
        #expect(insertion.comparisonIndex == second)
        #expect(insertion.comparisonsMade == 1)
        insertion.undo()
        #expect(insertion.comparisonIndex == first)
        #expect(!insertion.canUndo)
        // Nothing left to take back: a no-op.
        insertion.undo()
        #expect(insertion == BinaryInsertion(count: 10))
    }

    @Test func undoAfterPlacingReopensTheLastQuestion() {
        // 0...5 → worse than #2 → 3...5 → worse than #4 → placed last.
        var insertion = place(count: 5, truth: 5)
        #expect(insertion.position == 5)
        insertion.undo()
        #expect(!insertion.isPlaced)
        #expect(insertion.comparisonIndex == 4)
        // Changing the answer: better than #4 leaves 3...4, then worse than #3 settles on 4.
        insertion.record(.better)
        insertion.record(.worse)
        #expect(insertion.position == 4)
    }

    @Test func answersAfterPlacingAreIgnored() {
        var insertion = place(count: 3, truth: 1)
        let placed = insertion
        insertion.record(.better)
        #expect(insertion == placed)
    }

    @Test func alwaysBetterLandsOnTopAlwaysWorseAtTheBottom() {
        #expect(place(count: 100, truth: 0).position == 0)
        #expect(place(count: 100, truth: 100).position == 100)
    }
}
