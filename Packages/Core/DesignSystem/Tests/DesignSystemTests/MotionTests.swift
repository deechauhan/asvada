import SwiftUI
import Testing
@testable import DesignSystem

@MainActor
struct MotionTests {
    @Test func tokensMatchTheConcept() {
        #expect(Motion.sealHold == 0.6)
        #expect(Motion.stagger == 0.04)
        #expect(Motion.thunkStart == 1.6)
        #expect(Motion.thunk.map(\.scale) == [1.18, 0.97, 1])
        #expect(Motion.thunk.map(\.duration) == [0.09, 0.07, 0.12])
        #expect(SealButton.holdDuration == Motion.sealHold)
    }

    @Test func thunkEndsAtRest() {
        #expect(Motion.thunk.last?.scale == 1)
    }

    @Test func reduceMotionCrossfadesInsteadOfMoving() {
        #expect(Motion.animation(Motion.settle, reduceMotion: true) == Motion.crossfade)
        #expect(Motion.animation(Motion.settle, reduceMotion: false) == Motion.settle)
    }

    @Test func reduceMotionKeepsThingsUpright() {
        #expect(Motion.tilt(8, reduceMotion: true) == 0)
        #expect(Motion.tilt(-2, reduceMotion: false) == -2)
    }

    @Test func staggerSpacesItemsAndCollapsesUnderReduceMotion() {
        #expect(Motion.staggerDelay(0) == 0)
        #expect(abs(Motion.staggerDelay(3) - 0.12) < 1e-9)
        #expect(Motion.staggerDelay(3, reduceMotion: true) == 0)
        #expect(Motion.staggerDelay(-1) == 0)
    }
}

@MainActor
struct HapticTests {
    @Test func eachMomentHasItsFeedback() {
        #expect(Haptic.stamp.feedback == .impact(weight: .heavy))
        #expect(Haptic.pick.feedback == .impact(weight: .medium))
        #expect(Haptic.relishStep.feedback == .selection)
        #expect(Haptic.done.feedback == .success)
        #expect(Haptic.seal.feedback == .success)
    }

    @Test func theVocabularyIsComplete() {
        #expect(Haptic.allCases.count == 5)
    }
}
