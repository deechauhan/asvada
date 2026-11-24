import DesignSystem
import Model
import SwiftUI
import TipKit

/// The hand of blank keepsakes fanned in an arc over the savour pill (INTERACTION.md §5). Drawn
/// in the shell's overlay, centred on the pill; the blank under the thumb lifts and is named.
struct HandOfBlanks: View {
    let collections: [ExperienceCollection]
    /// The blank the thumb is on, if any.
    let selection: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fanned = false

    private var layout: HandLayout {
        HandLayout(count: collections.count)
    }

    var body: some View {
        ZStack {
            ForEach(Array(collections.prefix(HandLayout.maximumCount).enumerated()), id: \.element.id) { index, collection in
                let isLifted = selection == index
                let spot = layout.position(of: index)
                BlankKeepsake(collection: collection, isLifted: isLifted)
                    .scaleEffect(isLifted ? 1.18 : 1)
                    .rotationEffect(.degrees(fanned ? layout.angle(of: index) : 0), anchor: .bottom)
                    .offset(
                        x: fanned ? spot.x : 0,
                        y: (fanned ? spot.y : -20) - (isLifted ? 14 : 0),
                    )
                    .opacity(fanned ? 1 : 0)
                    .animation(
                        Motion.animation(Motion.fan, reduceMotion: reduceMotion)
                            .delay(Motion.fanDelay(index, of: collections.count, reduceMotion: reduceMotion)),
                        value: fanned,
                    )
                    .animation(Motion.animation(.snappy(duration: 0.18), reduceMotion: reduceMotion), value: isLifted)
            }
            if let selection, collections.indices.contains(selection) {
                Text(collections[selection].savourPhrase)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Palette.textPrimary.color)
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, Spacing.xs)
                    .background(.regularMaterial, in: Capsule())
                    .offset(y: -HandLayout.radius - DrawnBlankLabel.clearance)
            }
        }
        .onAppear { fanned = true }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selection
            .flatMap { collections.indices.contains($0) ? collections[$0].savourPhrase : nil } ?? "Hand of blank keepsakes")
        .accessibilityIdentifier("handOfBlanks")
    }
}

/// How far above the arc the name of the lifted blank floats.
enum DrawnBlankLabel {
    static let clearance: CGFloat = 78
}

/// Teaches hold-and-slide once the pill has been tapped open three times.
struct HoldToDrawTip: Tip {
    static let tapOpened = Event(id: "savourPillTapOpened")

    var title: Text {
        Text("Hold and slide up to draw")
    }

    var message: Text? {
        Text("Hold the pill and a hand of blank keepsakes fans out. Slide onto one and let go.")
    }

    var rules: [Rule] {
        #Rule(Self.tapOpened) { $0.donations.count >= 3 }
    }
}
