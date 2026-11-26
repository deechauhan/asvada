import DesignSystem
import Foundation

/// The riffle's physics (INTERACTION.md §4b, ADR-0004's pager option): a continuous position
/// through a drawer's cards. 0 is the first card at the front; 2.5 is halfway through flipping
/// the third. Thumbing down moves forward one card per `pitch` points, a release projects
/// `flingTime` of velocity and snaps to a whole card, and both ends rubber-band.
struct RifflePager: Equatable {
    var count: Int
    var position: Double

    /// How far a thumb travels to flip one card, in points.
    static let pitch = 62.0
    /// How much of a release's velocity a fling carries, in seconds.
    static let flingTime = 0.18

    init(count: Int, position: Double = 0) {
        self.count = max(count, 0)
        self.position = position
    }

    /// The card at the front, in `0..<count`.
    var frontIndex: Int {
        clamp(Int(position.rounded()))
    }

    /// How far card `index` is behind the front, in cards: negative while it flips toward you.
    func offset(of index: Int) -> Double {
        Double(index) - position
    }

    /// The cards worth drawing: a few already flipped (so a spring can carry them away), the
    /// front, and up to `depth` behind it.
    func visibleIndices(before: Int = 2, depth: Int = 7) -> [Int] {
        guard count >= 1 else { return [] }
        let front = Int(position.rounded(.down))
        let first = min(max(front - before, 0), count - 1)
        let last = min(max(front + depth, 0), count - 1)
        guard first <= last else { return [] }
        return Array(first ... last)
    }

    /// The position for a drag `translation` (points, downward positive) that started at
    /// `start`. Past either end the cards rubber-band.
    func position(dragging translation: Double, from start: Double) -> Double {
        let raw = start + translation / Self.pitch
        guard count >= 1 else { return 0 }
        let last = Double(count - 1)
        if raw < 0 {
            return -Motion.rubberBand(-raw, dimension: 1)
        }
        if raw > last {
            return last + Motion.rubberBand(raw - last, dimension: 1)
        }
        return raw
    }

    /// Where the riffle comes to rest after a release at `velocity` (points per second, downward
    /// positive): the nearest whole card to where the fling would carry it.
    func restingPosition(afterReleaseAt velocity: Double) -> Double {
        guard count >= 1 else { return 0 }
        let projected = position + velocity * Self.flingTime / Self.pitch
        return Double(clamp(Int(projected.rounded())))
    }

    private func clamp(_ index: Int) -> Int {
        guard count >= 1 else { return 0 }
        return min(max(index, 0), count - 1)
    }
}

/// Where one card stands in the riffle, from its offset behind the front: pure maths, so the
/// stack animates by interpolating the pager's position.
struct RiffleCardGeometry: Equatable {
    /// Rotation about the card's bottom edge, in degrees: 0 standing, −86 flipped toward you.
    var rotation: Double
    /// Vertical offset, in points: cards behind step up so their tabs show.
    var y: Double
    var scale: Double
    var opacity: Double
    var zIndex: Double

    /// How far each card behind the front steps up, in points: enough for its tab to show.
    static let step = 36.0
    /// The flip, at its fullest.
    static let flipAngle = -86.0
    /// How many cards behind the front are drawn before they fade out.
    static let depth = 5.0
    /// The perspective for `rotation3DEffect`.
    static let perspective = 0.6

    init(offset: Double, reduceMotion: Bool = false) {
        zIndex = 1000 - offset * 10
        if offset < 0 {
            let flipped = min(-offset, 1)
            if reduceMotion {
                // No rotation: the card slides down behind the drawer front and fades.
                rotation = 0
                y = 120 * flipped
                opacity = 1 - flipped
            } else {
                rotation = Self.flipAngle * flipped
                y = 40 * flipped
                opacity = flipped < 0.8 ? 1 : max(0, (1 - flipped) / 0.2)
            }
            scale = 1
            return
        }
        rotation = 0
        y = -Self.step * offset
        scale = max(1 - 0.012 * offset, 0.9)
        opacity = offset <= Self.depth ? 1 : max(0, 1 - (offset - Self.depth) / 2)
    }

    var isVisible: Bool {
        opacity > 0.01
    }
}
