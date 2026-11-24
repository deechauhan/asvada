import DesignSystem
import Foundation

/// The turning cabinet's physics: a continuous position along a ring of drawers
/// (docs/design/INTERACTION.md §3, ADR-0004).
///
/// `position` counts drawers: 0 is the first drawer at the front, 2.5 is halfway between the
/// third and fourth. A drag moves it 1:1, a release projects where a fling would land (at most
/// three drawers away) and a spring animates it there. With three or more drawers the ring wraps
/// around, so rolling past the last drawer brings the first one round again; with one or two it
/// has hard ends that rubber-band.
struct CabinetDrum: Equatable {
    /// How many drawers are on the ring (including the blank "new collection" drawer).
    var drawers: Int
    /// Where the ring is, in drawers. Unbounded while wrapping; see `frontIndex`.
    var position: Double

    /// How far a finger travels to turn the ring by one drawer, in points.
    static let dragPerDrawer = 170.0
    /// A finger that stays still this long before lifting has stopped: its release carries no
    /// fling, as in a scroll view.
    static let restBeforeLift: TimeInterval = 0.1

    /// The velocity a release really carries: none if the finger rested for `restBeforeLift` or
    /// more after its last movement (event times, so a busy main thread doesn't change it).
    static func releaseVelocity(_ velocity: Double, restedFor rest: TimeInterval) -> Double {
        rest >= restBeforeLift ? 0 : velocity
    }

    /// The most drawers a single fling can travel.
    static let maximumFlingStep = 3

    init(count: Int, position: Double = 0) {
        drawers = max(count, 0)
        self.position = position
    }

    /// Whether the ring wraps around (three or more drawers).
    var wraps: Bool {
        drawers >= 3
    }

    /// The drawer at the front, in `0..<drawers`.
    var frontIndex: Int {
        guard drawers >= 1 else { return 0 }
        return Self.wrap(Int(position.rounded()), count: drawers)
    }

    /// `index` folded into `0..<count`.
    static func wrap(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let remainder = index % count
        return remainder < 0 ? remainder + count : remainder
    }

    /// How far drawer `index` is from the front, in drawers: negative to the left, positive to
    /// the right. Wrapping takes the short way round, so the result is within `-drawers/2...drawers/2`.
    func offset(of index: Int) -> Double {
        let raw = Double(index) - position
        guard wraps else { return raw }
        let span = Double(drawers)
        var folded = (raw + span / 2).truncatingRemainder(dividingBy: span)
        if folded < 0 {
            folded += span
        }
        return folded - span / 2
    }

    /// The drawers worth drawing: those within `radius` of the front, nearest last (so the front
    /// drawer is drawn on top).
    func visibleIndices(radius: Double = 2.5) -> [Int] {
        (0 ..< drawers)
            .filter { abs(offset(of: $0)) <= radius }
            .sorted { abs(offset(of: $0)) > abs(offset(of: $1)) }
    }

    /// The position for a drag `translation` (points, rightward positive) that started at
    /// `start`. Dragging right brings the drawer on the left to the front. Without wrapping the
    /// ends rubber-band.
    func position(dragging translation: Double, from start: Double) -> Double {
        let raw = start - translation / Self.dragPerDrawer
        guard !wraps, drawers >= 1 else { return raw }
        let last = Double(drawers - 1)
        if raw < 0 {
            return -Motion.rubberBand(-raw, dimension: 1)
        }
        if raw > last {
            return last + Motion.rubberBand(raw - last, dimension: 1)
        }
        return raw
    }

    /// Where the ring should come to rest after a release at `velocity` (points per second,
    /// rightward positive): a whole drawer, at most three away, projected like a scroll view.
    /// Unwrapped, so the spring takes the short way; call `normalised()` once it has settled.
    func restingPosition(afterReleaseAt velocity: Double) -> Double {
        guard drawers >= 1 else { return 0 }
        let current = position
        let start = current.rounded()
        let travelled = -Motion.project(velocity: velocity) / Self.dragPerDrawer
        let step = min(
            max((current + travelled).rounded() - start, -Double(Self.maximumFlingStep)),
            Double(Self.maximumFlingStep),
        )
        let target = start + step
        guard !wraps else { return target }
        return min(max(target, 0), Double(drawers - 1))
    }

    /// The position that brings drawer `index` to the front by the shortest turn.
    func position(turningTo index: Int) -> Double {
        guard drawers >= 1 else { return 0 }
        let target = Self.wrap(index, count: drawers)
        return position + offset(of: target)
    }

    /// The same drawer at the front, with `position` folded back into `0..<drawers` so it doesn't
    /// grow without bound after many turns.
    func normalised() -> CabinetDrum {
        guard drawers >= 1 else { return self }
        let span = Double(drawers)
        var folded = position.truncatingRemainder(dividingBy: span)
        if folded < 0 {
            folded += span
        }
        return CabinetDrum(count: drawers, position: folded)
    }
}
