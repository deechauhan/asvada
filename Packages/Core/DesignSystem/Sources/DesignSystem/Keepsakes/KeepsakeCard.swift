import SwiftUI

/// A keepsake's view: one VoiceOver element with a spoken summary. Concrete templates
/// (passport stamp, luggage tag, later receipt, ticket stub…) conform.
public protocol KeepsakeTemplate: View {
    /// What VoiceOver says for the whole keepsake, e.g. "Passport stamp, Japan, entered 3 April 2025".
    var accessibilitySummary: String { get }
}

/// Paper for keepsakes: matte `keepsakePaper`, a faint grain, a 3pt radius and a two-layer ink
/// shadow, placed at a small deterministic tilt (none under Reduce Motion).
public struct KeepsakeCard<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let id: String
    let tilt: Double
    let content: Content

    /// - Parameters:
    ///   - id: stable id (e.g. the entry's UUID) that fixes the tilt.
    ///   - maxTilt: lean limit in degrees (keepsakes ±2°).
    public init(id: String, maxTilt: Double = Tilt.keepsakeMax, @ViewBuilder content: () -> Content) {
        self.id = id
        tilt = Tilt.degrees(for: id, max: maxTilt)
        self.content = content()
    }

    public var body: some View {
        content
            .background(KeepsakePaper(seed: id))
            .clipShape(RoundedRectangle(cornerRadius: Radius.keepsake))
            .shadow(color: Palette.textPrimary.color.opacity(0.08), radius: 1, y: 1)
            .shadow(color: Palette.textPrimary.color.opacity(0.12), radius: 12, y: 8)
            .rotationEffect(.degrees(reduceMotion ? 0 : tilt))
    }
}

/// The paper fill with a subtle, deterministic grain.
public struct KeepsakePaper: View {
    let seed: String

    public init(seed: String) {
        self.seed = seed
    }

    public var body: some View {
        Palette.keepsakePaper.color
            .overlay {
                Canvas { context, size in
                    var state = Seed.hash(seed) | 1
                    let count = Int(size.width * size.height / 90)
                    for _ in 0 ..< count {
                        state ^= state << 13
                        state ^= state >> 7
                        state ^= state << 17
                        let x = Double(state % 10000) / 10000 * size.width
                        let y = Double((state >> 20) % 10000) / 10000 * size.height
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: 1.1, height: 1.1)),
                            with: .color(Palette.textPrimary.color.opacity(0.05)),
                        )
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }
}
