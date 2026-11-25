import Testing
@testable import DesignSystem

struct RelishInputTests {
    @Test(arguments: [
        (0.0, 0.5), // the very start still rates something
        (0.05, 0.5), // left half of the first ā
        (0.1, 0.5),
        (0.15, 1.0), // its right half
        (0.45, 2.5), // left half of the third
        (0.55, 3.0), // right half of the third
        (1.0, 5.0),
        (1.4, 5.0), // past the end
        (-0.2, 0.5),
    ] as [(Double, Double)])
    func aFingerRatesTheHalfItsOn(fraction: Double, rating: Double) {
        #expect(RelishInput.rating(atFraction: fraction) == rating)
    }

    @Test func voiceOverStepsByHalvesWithinTheScale() {
        #expect(RelishInput.adjusted(nil, upward: true) == 0.5)
        #expect(RelishInput.adjusted(3, upward: true) == 3.5)
        #expect(RelishInput.adjusted(3, upward: false) == 2.5)
        #expect(RelishInput.adjusted(5, upward: true) == 5)
        #expect(RelishInput.adjusted(0.5, upward: false) == 0.5)
    }

    @Test func marksInkInWholesAndHalves() {
        // 3½: three whole marks, half the fourth, none of the fifth.
        let fills = (0 ..< 5).map { RelishInput.fill(of: $0, for: 3.5) }
        #expect(fills == [1, 1, 1, 0.5, 0])
        #expect((0 ..< 5).map { RelishInput.fill(of: $0, for: nil) } == [0, 0, 0, 0, 0])
    }

    @Test func itReadsAsANumeralAndAWord() {
        #expect(RelishInput.numeral(3.5) == "3½")
        #expect(RelishInput.numeral(4) == "4")
        #expect(RelishInput.numeral(0.5) == "½")
        #expect(RelishInput.spoken(3.5) == "3½ of 5, Lovely")
        #expect(RelishInput.spoken(nil) == "Not rated")
    }
}
