import CoreGraphics
import Testing
@testable import Features

struct HandLayoutTests {
    @Test func blanksFanSymmetricallyOverThePill() {
        let hand = HandLayout(count: 5)
        #expect(hand.angle(of: 2) == 0)
        #expect(hand.angle(of: 0) == -44)
        #expect(hand.angle(of: 4) == 44)
        let middle = hand.position(of: 2)
        #expect(abs(middle.x) < 1e-9 && abs(middle.y + HandLayout.radius) < 1e-9, "straight above the pill")
        #expect(abs(hand.position(of: 0).x + hand.position(of: 4).x) < 1e-9)
    }

    @Test func bigHandsCloseUpToStayOnScreen() {
        let hand = HandLayout(count: 12)
        #expect(hand.count == HandLayout.maximumCount)
        #expect(hand.angle(of: 7) - hand.angle(of: 0) <= HandLayout.maximumSpread + 1e-9)
    }

    @Test func theThumbPicksTheBlankAtItsAngle() {
        let hand = HandLayout(count: 5)
        // Straight up picks the middle; up-left and up-right pick the neighbours.
        #expect(hand.selection(for: CGSize(width: 0, height: -120)) == 2)
        #expect(hand.selection(for: CGSize(width: -60, height: -120)) == 1)
        #expect(hand.selection(for: CGSize(width: 70, height: -70)) == 4)
        // Further round than the last blank still picks the last.
        #expect(hand.selection(for: CGSize(width: -200, height: -10)) == 0)
    }

    @Test func theDeadZoneAndBelowThePillChooseNothing() {
        let hand = HandLayout(count: 5)
        #expect(hand.selection(for: CGSize(width: 10, height: -30)) == nil)
        #expect(hand.selection(for: CGSize(width: 0, height: 40)) == nil)
        #expect(HandLayout(count: 0).selection(for: CGSize(width: 0, height: -120)) == nil)
    }

    @Test func aFlickAlwaysLandsOnTheSameBlank() {
        // Positions never change, so the same direction draws the same blank at any distance.
        let hand = HandLayout(count: 6)
        let near = hand.selection(for: CGSize(width: 30, height: -50))
        let far = hand.selection(for: CGSize(width: 90, height: -150))
        #expect(near == far)
    }

    @Test func aSingleBlankIsAlwaysTheOne() {
        let hand = HandLayout(count: 1)
        #expect(hand.angle(of: 0) == 0)
        #expect(hand.selection(for: CGSize(width: 80, height: -80)) == 0)
    }

    @MainActor
    @Test func aStillQuickPressIsATapEvenIfTheHandCameOut() {
        // The hold timer can beat a busy main thread to the lift; a quick still press still taps.
        #expect(PillPressCatcher.isTap(distance: 2, duration: 0.1, handWasShown: false))
        #expect(PillPressCatcher.isTap(distance: 2, duration: 0.2, handWasShown: true))
        // A real hold, let go in place without choosing a blank, opens nothing.
        #expect(!PillPressCatcher.isTap(distance: 2, duration: 0.8, handWasShown: true))
        // A slide is never a tap.
        #expect(!PillPressCatcher.isTap(distance: 40, duration: 0.1, handWasShown: false))
    }
}
