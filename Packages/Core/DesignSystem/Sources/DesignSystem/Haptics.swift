import SwiftUI

/// The shared haptic vocabulary, so every screen feels the same paper physics. Haptics are kept
/// under Reduce Motion: they're how the app still feels physical when it stops moving.
public enum Haptic: CaseIterable, Sendable {
    /// The end of the seal. On devices with Core Haptics, `SealButton` also plays its ramp and
    /// final transient; this is the system feedback everywhere.
    case seal
    /// A stamp landing on the passport.
    case stamp
    /// Choosing a side in a duel.
    case pick
    /// Each step along the relish scale.
    case relishStep
    /// Something finished: a ranking settled, onboarding done.
    case done
    /// One drawer or card passing the centre: the click of a detent. Throttle with
    /// `DetentThrottle` (or `.detentHaptic(trigger:)`) so a fast roll doesn't buzz.
    case detent
    /// A drawer opening, shutting or landing; the lucky dip coming to rest.
    case clunk
    /// Lifting a card out or picking up a drawer to carry.
    case lift
    /// Tearing a guess off the print head or a film stub along its perforation. `TearHaptics`
    /// plays six rigid ticks where Core Haptics is available; this is the fallback.
    case tear

    /// The system feedback each haptic plays.
    public var feedback: SensoryFeedback {
        switch self {
        case .seal: .success
        case .stamp: .impact(weight: .heavy)
        case .pick: .impact(weight: .medium)
        case .relishStep: .selection
        case .done: .success
        case .detent: .selection
        case .clunk: .impact(flexibility: .solid, intensity: 0.8)
        case .lift: .impact(weight: .light)
        case .tear: .impact(flexibility: .rigid, intensity: 0.5)
        }
    }
}

public extension View {
    /// Plays `haptic` each time `trigger` changes.
    func haptic(_ haptic: Haptic, trigger: some Equatable) -> some View {
        sensoryFeedback(haptic.feedback, trigger: trigger)
    }

    /// Plays `Haptic.detent` each time `trigger` changes (for example the index under the centre
    /// of the cabinet), but never closer together than `DetentThrottle.minimumInterval`, so a
    /// fast fling clicks instead of buzzing.
    func detentHaptic(trigger: some Equatable) -> some View {
        modifier(DetentHapticModifier(trigger: trigger))
    }
}

/// Lets detent clicks through at most once every 30 ms (INTERACTION.md §8).
public struct DetentThrottle: Sendable {
    /// The shortest gap between two detent clicks.
    public static let minimumInterval: TimeInterval = 0.03

    private var last: TimeInterval?

    public init() {}

    /// Whether a detent at `time` (seconds, any monotonic clock) should click. Records it if so.
    public mutating func shouldFire(at time: TimeInterval) -> Bool {
        if let last, time - last < Self.minimumInterval, time >= last {
            return false
        }
        last = time
        return true
    }
}

private struct DetentHapticModifier<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    @State private var gate = DetentGate()

    func body(content: Content) -> some View {
        content.sensoryFeedback(trigger: trigger) { _, _ in
            gate.allows(at: ProcessInfo.processInfo.systemUptime) ? Haptic.detent.feedback : nil
        }
    }
}

/// A reference holder so the feedback closure can update the throttle without a state write.
@MainActor
private final class DetentGate {
    private var throttle = DetentThrottle()

    func allows(at time: TimeInterval) -> Bool {
        throttle.shouldFire(at: time)
    }
}
