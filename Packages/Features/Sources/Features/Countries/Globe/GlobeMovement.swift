import Foundation

/// What the ink globe is doing: resting, coasting after a fling, or flying to a country. The
/// camera is a pure function of the time, so a `TimelineView` can draw any frame and the
/// tests can check any moment.
enum GlobeMovement: Equatable {
    case resting(GlobeCamera)
    case coasting(from: GlobeCamera, spin: GlobeSpin, start: Date)
    case flying(from: GlobeCamera, target: GlobeCamera, start: Date, duration: Double)

    /// Flying to a country takes this long (ease in and out).
    static let flightDuration = 0.75
    /// The magnet's pull into the ring is quicker.
    static let snapDuration = 0.3

    /// Where the globe faces at `date`.
    func camera(at date: Date) -> GlobeCamera {
        switch self {
        case let .resting(camera):
            return camera
        case let .coasting(from, spin, start):
            let elapsed = min(date.timeIntervalSince(start), GlobeMotion.coastDuration(spin))
            return GlobeMotion.coast(from, spin: spin, elapsed: elapsed)
        case let .flying(from, target, start, duration):
            let progress = duration > 0 ? min(max(date.timeIntervalSince(start) / duration, 0), 1) : 1
            return Self.between(from, target, Self.easeInOut(progress))
        }
    }

    /// Where it comes to rest.
    var destination: GlobeCamera {
        switch self {
        case let .resting(camera):
            camera
        case let .coasting(from, spin, _):
            GlobeMotion.coast(from, spin: spin, elapsed: GlobeMotion.coastDuration(spin))
        case let .flying(_, target, _, _):
            target
        }
    }

    /// When it comes to rest; nil when it's already resting.
    var end: Date? {
        switch self {
        case .resting:
            nil
        case let .coasting(_, spin, start):
            start.addingTimeInterval(GlobeMotion.coastDuration(spin))
        case let .flying(_, _, start, duration):
            start.addingTimeInterval(duration)
        }
    }

    var isMoving: Bool {
        end != nil
    }

    var isCoasting: Bool {
        if case .coasting = self {
            return true
        }
        return false
    }

    /// A flight from wherever the globe is at `date` to face `target`; a cut under Reduce Motion.
    static func flight(
        from movement: GlobeMovement,
        to target: GlobeCamera,
        at date: Date,
        duration: Double = flightDuration,
        reduceMotion: Bool,
    ) -> GlobeMovement {
        let from = movement.camera(at: date)
        guard !reduceMotion, from != target else { return .resting(target) }
        return .flying(from: from, target: target, start: date, duration: duration)
    }

    /// A flight to put country `code` in the ring, or nil if the globe doesn't draw it.
    static func flight(
        from movement: GlobeMovement,
        toCountry code: String,
        at date: Date,
        duration: Double = flightDuration,
        reduceMotion: Bool,
        world: InkGlobeWorld = .shared,
    ) -> GlobeMovement? {
        guard let anchor = world.country(code: code)?.anchor.point else { return nil }
        return flight(from: movement, to: GlobeCamera(facing: anchor), at: date, duration: duration, reduceMotion: reduceMotion)
    }

    /// The camera `fraction` of the way from `from` to `target`, the short way round in longitude.
    static func between(_ from: GlobeCamera, _ target: GlobeCamera, _ fraction: Double) -> GlobeCamera {
        let turn = GlobeCamera.wrap(target.longitude - from.longitude)
        return GlobeCamera(
            longitude: from.longitude + turn * fraction,
            latitude: from.latitude + (target.latitude - from.latitude) * fraction,
        )
    }

    /// Cubic ease in and out.
    static func easeInOut(_ time: Double) -> Double {
        time < 0.5 ? 4 * time * time * time : 1 - pow(-2 * time + 2, 3) / 2
    }
}
