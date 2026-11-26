import SwiftUI

/// The macron as a progress bar (CONCEPT.md §2): a saffron bar along a faint track, filled to
/// `progress` (0…1). Saffron is only ever a bar, never text.
public struct MacronBar: View {
    let progress: Double
    var height: CGFloat

    public init(progress: Double, height: CGFloat = 4) {
        self.progress = progress
        self.height = height
    }

    private var clamped: Double {
        min(max(progress, 0), 1)
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.separator.color)
                Capsule()
                    .fill(Palette.saffron.color)
                    // A started bar always shows a nub, never a hairline.
                    .frame(width: clamped > 0 ? max(proxy.size.width * clamped, height) : 0)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// A small plum ring filled to `progress` (0…1), for "how much of the set" at a glance.
public struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat

    public init(progress: Double, lineWidth: CGFloat = 4) {
        self.progress = progress
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.separator.color, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Palette.brand.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
    }
}
