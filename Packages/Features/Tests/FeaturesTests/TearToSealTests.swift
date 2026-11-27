import Testing
@testable import Features

struct TearToSealTests {
    @Test func theTearRunsForwardWithTheFingerAndStopsAtTheEnd() {
        #expect(TearToSeal.progress(after: 130, width: 260, from: 0) == 0.5)
        // Dragging back doesn't mend it.
        #expect(TearToSeal.progress(after: 50, width: 260, from: 0.5) == 0.5)
        #expect(TearToSeal.progress(after: 400, width: 260, from: 0.2) == 1)
        #expect(TearToSeal.progress(after: -30, width: 260, from: 0) == 0)
        #expect(TearToSeal.progress(after: 30, width: 0, from: 0.3) == 0.3)
    }

    @Test func eachNotchTicksOnce() {
        #expect(TearToSeal.notch(at: 0) == 0)
        #expect(TearToSeal.notch(at: 0.124) == 0)
        #expect(TearToSeal.notch(at: 0.125) == 1)
        #expect(TearToSeal.notch(at: 0.99) == TearToSeal.notchCount - 1)
        #expect(TearToSeal.notch(at: 1) == TearToSeal.notchCount)
        #expect(TearToSeal.notch(at: 2) == TearToSeal.notchCount)
    }

    @Test func itPartsBeforeTheVeryEnd() {
        #expect(TearToSeal.partsAt < 1)
        #expect(TearToSeal.partsAt > 0.5)
    }
}
