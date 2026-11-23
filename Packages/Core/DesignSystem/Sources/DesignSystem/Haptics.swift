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

    /// The system feedback each haptic plays.
    public var feedback: SensoryFeedback {
        switch self {
        case .seal: .success
        case .stamp: .impact(weight: .heavy)
        case .pick: .impact(weight: .medium)
        case .relishStep: .selection
        case .done: .success
        }
    }
}

public extension View {
    /// Plays `haptic` each time `trigger` changes.
    func haptic(_ haptic: Haptic, trigger: some Equatable) -> some View {
        sensoryFeedback(haptic.feedback, trigger: trigger)
    }
}
