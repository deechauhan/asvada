import Foundation
import SwiftUI

/// Motion kit II: the physical verbs of "Savour by hand" (docs/design/INTERACTION.md §8). Roll to
/// browse one thing at a time, pull to open, pinch to see everything, hold to commit.
///
/// Every token here becomes `Motion.crossfade` under Reduce Motion through
/// `Motion.animation(_:reduceMotion:)`; staggers collapse to zero. Haptics are kept.
public extension Motion {
    // MARK: - Springs

    /// The cabinet drum snapping to a drawer after a roll.
    static let roll = Animation.spring(duration: 0.42, bounce: 0.12)
    /// The riffle snapping to a card: quicker and flatter than the drum.
    static let riffle = Animation.spring(duration: 0.32, bounce: 0.08)
    /// A drawer pulled short of the threshold springing back.
    static let pull = Animation.spring(duration: 0.36, bounce: 0.2)
    /// One shape becoming another: cabinet ↔ chest, riffle ↔ spread, globe ↔ flat map.
    static let morph = Animation.spring(duration: 0.5, bounce: 0.06)
    /// The hand of blank keepsakes fanning out over the thumb.
    static let fan = Animation.spring(duration: 0.34, bounce: 0.3)
    /// The delay between neighbouring blanks as the hand fans out, from the centre outwards.
    static let fanStagger = 0.018

    /// When the blank at `index` of `count` starts fanning: the middle first, then outwards in
    /// pairs, `fanStagger` apart. All at once under Reduce Motion.
    static func fanDelay(_ index: Int, of count: Int, reduceMotion: Bool = false) -> Double {
        guard !reduceMotion, count > 1, (0 ..< count).contains(index) else { return 0 }
        let middle = Double(count - 1) / 2
        // Odd hands have one middle card (distance 0); even hands two (distance ½), both first.
        let rings = abs(Double(index) - middle).rounded(.down)
        return rings * fanStagger
    }

    // MARK: - Lucky dip spin

    /// How long a lucky-dip spin across `distance` drawers lasts: 2.1 s plus 18 ms a drawer.
    static func spinDuration(distance: Int) -> Double {
        2.1 + 0.018 * Double(max(distance, 0))
    }

    /// The spin's ease: fast off the flick, then clicking slower and slower, `1 − (1 − u)^3.2`.
    static func spinProgress(_ time: Double) -> Double {
        let clamped = min(max(time, 0), 1)
        return 1 - pow(1 - clamped, 3.2)
    }

    /// A lucky-dip spin across `distance` drawers.
    static func spin(distance: Int) -> Animation {
        Animation(SpinEase(duration: spinDuration(distance: distance)))
    }

    // MARK: - Ink bloom

    /// The stamp's ring spreading out from the impact point.
    static let inkBloomRing = Animation.easeOut(duration: 0.9)
    /// The country flooding with ink behind the ring.
    static let inkBloomFill = Animation.easeOut(duration: 0.5)

    // MARK: - Physics

    /// The deceleration of a flung scroll view (UIScrollView's normal rate, per millisecond).
    static let decelerationRate = 0.998

    /// How far past an edge a drag shows: the first points track almost 1:1, then it stiffens
    /// and never passes `dimension`. `(1 − 1/(x·c/d + 1))·d`, keeping the sign of `offset`.
    ///
    /// - Parameters:
    ///   - offset: how far the finger has gone past the edge, in points.
    ///   - dimension: the size of the thing being stretched (its height or width).
    ///   - coefficient: stiffness, 0.55 (UIKit's feel) to 0.75 (looser, for pulls).
    static func rubberBand(_ offset: Double, dimension: Double, coefficient: Double = 0.55) -> Double {
        guard dimension > 0, offset != 0 else { return 0 }
        let stretched = (1 - 1 / (abs(offset) * coefficient / dimension + 1)) * dimension
        return offset < 0 ? -stretched : stretched
    }

    /// Where a fling would come to rest, as a distance from where the finger let go
    /// (WWDC18 "Designing Fluid Interfaces"). Use it to pick the drawer or card to snap to.
    ///
    /// - Parameters:
    ///   - velocity: release velocity in points per second.
    ///   - decelerationRate: per-millisecond rate, 0.998 for a normal scroll view, 0.99 for fast.
    static func project(velocity: Double, decelerationRate: Double = Motion.decelerationRate) -> Double {
        guard decelerationRate > 0, decelerationRate < 1 else { return 0 }
        return velocity / 1000 * decelerationRate / (1 - decelerationRate)
    }

    /// The index a roll lands on: the current one moved by the projected fling, at most
    /// `maximumStep` away, and inside `0..<count`.
    ///
    /// - Parameters:
    ///   - current: the index under the centre when the finger lifted (may be fractional).
    ///   - velocity: release velocity in points per second; positive moves to higher indices.
    ///   - spacing: the distance between neighbours, in points.
    static func landingIndex(
        from current: Double,
        velocity: Double,
        spacing: Double,
        count: Int,
        maximumStep: Int = 3,
    ) -> Int {
        guard count > 0 else { return 0 }
        guard spacing > 0 else { return min(max(Int(current.rounded()), 0), count - 1) }
        let start = current.rounded()
        let projected = current + project(velocity: velocity) / spacing
        let step = min(max(projected.rounded() - start, -Double(maximumStep)), Double(maximumStep))
        return min(max(Int(start + step), 0), count - 1)
    }
}

/// `1 − (1 − u)^3.2` over a fixed duration: the lucky dip's long, clicking slow-down.
struct SpinEase: CustomAnimation {
    let duration: Double

    /// How far along the spin is at `time`, or `nil` once it has finished.
    func fraction(at time: TimeInterval) -> Double? {
        guard time < duration, duration > 0 else { return nil }
        return Motion.spinProgress(time / duration)
    }

    func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context _: inout AnimationContext<V>) -> V? {
        fraction(at: time).map { value.scaled(by: $0) }
    }
}
