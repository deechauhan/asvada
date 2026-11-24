import Foundation
#if os(iOS) && canImport(CoreHaptics)
    import CoreHaptics
#endif

/// The tear: six rigid transients 22 ms apart, like paper parting along a perforation. Used by
/// the print head's tear-off and the film stub (#121).
///
/// `play()` returns `false` where Core Haptics isn't available, so the caller plays
/// `Haptic.tear` (a single rigid impact) instead.
@MainActor
public final class TearHaptics {
    /// When each tick lands, in seconds from the start.
    public static let tickTimes: [TimeInterval] = (0 ..< 6).map { Double($0) * 0.022 }
    /// How hard each tick is: a little stronger in the middle of the tear.
    public static let tickIntensities: [Float] = [0.45, 0.6, 0.7, 0.7, 0.6, 0.45]
    /// Rigid, papery ticks.
    public static let sharpness: Float = 0.9

    #if os(iOS) && canImport(CoreHaptics)
        private var engine: CHHapticEngine?
    #endif

    public init() {}

    /// Plays the tear, or returns `false` if this device can't.
    @discardableResult
    public func play() -> Bool {
        #if os(iOS) && canImport(CoreHaptics)
            guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return false }
            do {
                if engine == nil {
                    engine = try CHHapticEngine()
                }
                try engine?.start()
                let events = zip(Self.tickTimes, Self.tickIntensities).map { time, intensity in
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: Self.sharpness),
                        ],
                        relativeTime: time,
                    )
                }
                let pattern = try CHHapticPattern(events: events, parameters: [])
                try engine?.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
                return true
            } catch {
                return false
            }
        #else
            return false
        #endif
    }
}
