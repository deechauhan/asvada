import SwiftUI

/// The relish scale's arithmetic: five ā marks rated in halves, from ½ to 5.
public enum RelishInput {
    /// The smallest step: half an ā.
    public static let step = 0.5
    public static let maximum = Double(Relish.words.count)

    /// The rating under a finger at `fraction` (0…1) of the scale's width: always rounded up to
    /// the next half, so the left half of the third ā is 2½ and its right half is 3.
    public static func rating(atFraction fraction: Double) -> Double {
        let clamped = min(max(fraction, 0), 1)
        // A hair's tolerance: 0.7 × 5 / 0.5 is 7.000000000000001 in floating point, which would
        // otherwise round up a whole half past a boundary.
        let halves = (clamped * maximum / step - 1e-9).rounded(.up)
        return max(halves, 1) * step
    }

    /// `rating` moved one half up (or down), staying within ½…5. Unrated moves up to ½.
    public static func adjusted(_ rating: Double?, upward: Bool) -> Double {
        let current = rating ?? 0
        let next = current + (upward ? step : -step)
        return min(max(next, step), maximum)
    }

    /// How much of the `index`th ā (0-based) is inked for `rating`: 0, ½ or 1.
    public static func fill(of index: Int, for rating: Double?) -> Double {
        let left = (rating ?? 0) - Double(index)
        if left >= 1 {
            return 1
        }
        return left >= step ? step : 0
    }

    /// "3½" or "4".
    public static func numeral(_ rating: Double) -> String {
        let whole = Int(rating)
        let half = rating - Double(whole) >= step
        return whole == 0 ? "½" : "\(whole)\(half ? "½" : "")"
    }

    /// What VoiceOver says: "3½ of 5, Lovely", or "Not rated".
    public static func spoken(_ rating: Double?) -> String {
        guard let rating, rating > 0, let word = Relish.word(for: rating) else { return "Not rated" }
        return "\(numeral(rating)) of \(Int(maximum)), \(word)"
    }
}

/// Five serif ā marks to rate how something landed, in halves. Tap or drag along them; the left
/// half of a mark rates a half. One `relishStep` haptic per half crossed. VoiceOver hears one
/// adjustable element ("3½ of 5, Lovely") and swipes up or down by halves.
public struct RelishScale: View {
    @Binding var rating: Double?
    /// Called when a finger lifts (a tap or the end of a drag), with the rating it left.
    var onCommit: (Double) -> Void
    var markSize: CGFloat

    public init(rating: Binding<Double?>, markSize: CGFloat = 28, onCommit: @escaping (Double) -> Void = { _ in }) {
        _rating = rating
        self.markSize = markSize
        self.onCommit = onCommit
    }

    private var width: CGFloat {
        markSize * 1.7 * CGFloat(Relish.words.count)
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(0 ..< Relish.words.count, id: \.self) { index in
                mark(fill: RelishInput.fill(of: index, for: rating))
                    .frame(width: markSize * 1.7, height: markSize * 1.7)
            }
        }
        .frame(width: width)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in rating = RelishInput.rating(atFraction: value.location.x / width) }
                .onEnded { value in
                    let landed = RelishInput.rating(atFraction: value.location.x / width)
                    rating = landed
                    onCommit(landed)
                },
        )
        .haptic(.relishStep, trigger: rating)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Relish")
        .accessibilityValue(RelishInput.spoken(rating))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: rating = RelishInput.adjusted(rating, upward: true)
            case .decrement: rating = RelishInput.adjusted(rating, upward: false)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("relishScale")
    }

    /// One ā: grey, or inked plum in full or in its left half.
    private func mark(fill: Double) -> some View {
        let glyph = Text("ā").font(.system(size: markSize, weight: .heavy, design: .serif))
        return ZStack {
            glyph.foregroundStyle(Palette.textSecondary.color.opacity(0.45))
            glyph
                .foregroundStyle(Palette.brand.color)
                .mask {
                    GeometryReader { glyph in
                        Rectangle().frame(width: glyph.size.width * CGFloat(fill))
                    }
                }
                .opacity(fill > 0 ? 1 : 0)
        }
    }
}
