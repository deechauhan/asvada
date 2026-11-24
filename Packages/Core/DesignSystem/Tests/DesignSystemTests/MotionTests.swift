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
        #expect(Haptic.allCases.count == 9)
    }
}

@MainActor
struct MotionKitTests {
    @Test func springsMatchTheInteractionDoc() {
        #expect(Motion.roll == .spring(duration: 0.42, bounce: 0.12))
        #expect(Motion.riffle == .spring(duration: 0.32, bounce: 0.08))
        #expect(Motion.pull == .spring(duration: 0.36, bounce: 0.2))
        #expect(Motion.morph == .spring(duration: 0.5, bounce: 0.06))
        #expect(Motion.fan == .spring(duration: 0.34, bounce: 0.3))
        #expect(Motion.fanStagger == 0.018)
    }

    @Test func everyNewTokenCrossfadesUnderReduceMotion() {
        for token in [Motion.roll, Motion.riffle, Motion.pull, Motion.morph, Motion.fan, Motion.spin(distance: 6)] {
            #expect(Motion.animation(token, reduceMotion: true) == Motion.crossfade)
        }
    }

    @Test func theHandFansFromTheMiddleOut() {
        let odd = (0 ..< 5).map { Motion.fanDelay($0, of: 5) }
        #expect(odd.map { ($0 / Motion.fanStagger).rounded() } == [2, 1, 0, 1, 2])
        let even = (0 ..< 4).map { Motion.fanDelay($0, of: 4) }
        #expect(even.map { ($0 / Motion.fanStagger).rounded() } == [1, 0, 0, 1])
        #expect(Motion.fanDelay(0, of: 5, reduceMotion: true) == 0)
        #expect(Motion.fanDelay(9, of: 5) == 0)
    }

    @Test func spinSlowsDownAndLasts() {
        #expect(abs(Motion.spinDuration(distance: 10) - 2.28) < 1e-9)
        #expect(Motion.spinDuration(distance: -3) == 2.1)
        #expect(Motion.spinProgress(0) == 0)
        #expect(Motion.spinProgress(1) == 1)
        #expect(Motion.spinProgress(2) == 1)
        // Most of the distance goes early; the last stretch crawls (the clicks slow down).
        #expect(Motion.spinProgress(0.25) > 0.55)
        #expect(Motion.spinProgress(0.9) > 0.99)
        let samples = stride(from: 0.0, through: 1, by: 0.05).map(Motion.spinProgress)
        let rising = zip(samples, samples.dropFirst()).allSatisfy { $0 <= $1 }
        #expect(rising)
    }

    @Test func spinEaseRunsForItsDurationThenStops() {
        let ease = SpinEase(duration: 2)
        #expect(ease.fraction(at: 0) == 0)
        let half = ease.fraction(at: 1) ?? 0
        #expect(abs(half - Motion.spinProgress(0.5)) < 1e-9)
        #expect(ease.fraction(at: 2) == nil)
        #expect(SpinEase(duration: 0).fraction(at: 0) == nil)
    }

    @Test func rubberBandTracksThenStiffens() {
        let height = 400.0
        #expect(Motion.rubberBand(0, dimension: height) == 0)
        let small = Motion.rubberBand(10, dimension: height)
        #expect(small > 5 && small < 10, "near 1:1 at first, got \(small)")
        #expect(Motion.rubberBand(10000, dimension: height) < height)
        #expect(Motion.rubberBand(-50, dimension: height) == -Motion.rubberBand(50, dimension: height))
        #expect(Motion.rubberBand(200, dimension: height, coefficient: 0.75) > Motion.rubberBand(200, dimension: height))
        #expect(Motion.rubberBand(30, dimension: 0) == 0)
        let offsets = stride(from: 0.0, through: 2000, by: 50).map { Motion.rubberBand($0, dimension: height) }
        let increasing = zip(offsets, offsets.dropFirst()).allSatisfy { $0 < $1 }
        #expect(increasing)
    }

    @Test func projectionFollowsWWDC18() {
        // 1,000 pt/s at the normal rate travels 499 pt.
        #expect(abs(Motion.project(velocity: 1000) - 499) < 1e-6)
        #expect(Motion.project(velocity: -1000) < 0)
        #expect(abs(Motion.project(velocity: 1000, decelerationRate: 0.99) - 99) < 1e-6)
        #expect(Motion.project(velocity: 1000, decelerationRate: 1) == 0)
    }

    @Test func aRollLandsWithinThreeDrawers() {
        // A gentle release stays put; a hard fling is capped at three drawers.
        #expect(Motion.landingIndex(from: 4.2, velocity: 50, spacing: 280, count: 10) == 4)
        #expect(Motion.landingIndex(from: 4, velocity: 900, spacing: 280, count: 10) == 6)
        #expect(Motion.landingIndex(from: 4, velocity: 20000, spacing: 280, count: 10) == 7)
        #expect(Motion.landingIndex(from: 4, velocity: -20000, spacing: 280, count: 10) == 1)
        // Never past the ends.
        #expect(Motion.landingIndex(from: 1, velocity: -20000, spacing: 280, count: 10) == 0)
        #expect(Motion.landingIndex(from: 9, velocity: 20000, spacing: 280, count: 10) == 9)
        #expect(Motion.landingIndex(from: 0, velocity: 500, spacing: 280, count: 0) == 0)
    }
}

@MainActor
struct HapticKitTests {
    @Test func newMomentsHaveTheirFeedback() {
        #expect(Haptic.detent.feedback == .selection)
        #expect(Haptic.clunk.feedback == .impact(flexibility: .solid, intensity: 0.8))
        #expect(Haptic.lift.feedback == .impact(weight: .light))
        #expect(Haptic.tear.feedback == .impact(flexibility: .rigid, intensity: 0.5))
    }

    @Test func detentsAreThrottledTo30ms() {
        var throttle = DetentThrottle()
        #expect(throttle.shouldFire(at: 1.000))
        #expect(!throttle.shouldFire(at: 1.010))
        #expect(!throttle.shouldFire(at: 1.029))
        #expect(throttle.shouldFire(at: 1.031))
        #expect(!throttle.shouldFire(at: 1.040))
        #expect(throttle.shouldFire(at: 2.000))
    }

    @Test func theTearIsSixTicks22msApart() {
        #expect(TearHaptics.tickTimes.count == 6)
        #expect(TearHaptics.tickIntensities.count == 6)
        let gaps = zip(TearHaptics.tickTimes, TearHaptics.tickTimes.dropFirst()).map { $1 - $0 }
        let even = gaps.allSatisfy { abs($0 - 0.022) < 1e-9 }
        #expect(even)
    }

    @Test func theTearFallsBackWhereThereAreNoHaptics() {
        // macOS test hosts have no haptic engine: play() reports it, so callers use Haptic.tear.
        #expect(TearHaptics().play() == false)
    }
}
