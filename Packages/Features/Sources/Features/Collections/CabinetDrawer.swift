import DesignSystem
import Model
import SwiftUI

/// One drawer in the Collections cabinet: the collection's name, its best three keepsakes fanned
/// out of the drawer, and a key stat in serif numerals. An empty drawer shows a ghost keepsake.
struct CabinetDrawer: View {
    let collection: ExperienceCollection
    var isArranging = false
    var onHide: () -> Void = {}

    private var accent: CollectionAccent {
        collection.accent
    }

    var body: some View {
        let summary = collection.drawerSummary
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.small) {
                Image(systemName: collection.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent.token.color)
                    .accessibilityHidden(true)
                Text(collection.name)
                    .typeToken(.headline)
                    .foregroundStyle(Palette.textPrimary.color)
                    .lineLimit(1)
            }
            DrawerFan(collection: collection, items: collection.drawerItems())
                .frame(maxWidth: .infinity)
                .frame(height: 92)
            DrawerStat(summary: summary)
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.medium))
        .overlay(alignment: .top) {
            // The drawer pull.
            Capsule()
                .fill(Palette.separator.color)
                .frame(width: 28, height: 4)
                .padding(.top, 5)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topLeading) {
            if isArranging {
                Button(action: onHide) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Palette.onBrand.color, Palette.textSecondary.color)
                }
                .buttonStyle(.plain)
                .offset(x: -8, y: -8)
                .accessibilityLabel("Hide \(collection.name)")
                .accessibilityIdentifier("hideCollection-\(collection.name)")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .modifier(Jiggle(isActive: isArranging, seed: collection.id.uuidString))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("collection-\(collection.kind.rawValue)-\(collection.name)")
    }
}

/// The serif numeral with its saffron macron, and a caption. Empty drawers get the ghost line.
private struct DrawerStat: View {
    let summary: DrawerSummary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            if let numeral = summary.numeral {
                Text(numeral)
                    .font(.system(.title, design: .serif, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.brand.color)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Palette.saffron.color)
                            .frame(height: 3)
                            .offset(y: -3)
                            .accessibilityHidden(true)
                    }
            }
            Text(summary.caption)
                .font(summary.numeral == nil ? .system(.callout, design: .serif).italic() : .caption)
                .foregroundStyle(Palette.textSecondary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(minHeight: 34, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.spoken)
    }
}

/// Up to three keepsakes fanned like cards: the best in front and centre, the next two behind it,
/// leaning out. Countries are different: their stamps are inked across a passport page instead.
/// Under Reduce Motion the keepsakes stay upright (no tilt), still spread side by side.
///
/// In the turning cabinet the fan sits inside the drawer and `rise` lifts the keepsakes out of it
/// one after another as the drawer eases ajar.
struct DrawerFan: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let collection: ExperienceCollection
    let items: [Item]
    /// How far the keepsakes have risen out of the drawer, in points (0 = sitting in the grid).
    var rise: CGFloat = 0

    /// Where a keepsake sits in the fan: offsets, lean in degrees and stacking order.
    private struct Spot {
        let x: CGFloat
        var y: CGFloat = 0
        let angle: Double
        let layer: Double
    }

    /// The spot for the keepsake at `rank` (0 = best) in a fan of `count`.
    private func placement(rank: Int, of count: Int) -> Spot {
        switch (count, rank) {
        case (1, _): Spot(x: 0, angle: -2, layer: 3)
        case (2, 0): Spot(x: -14, angle: -4, layer: 3)
        case (2, _): Spot(x: 18, angle: 6, layer: 2)
        case (_, 0): Spot(x: 0, angle: -1, layer: 3)
        case (_, 1): Spot(x: -36, angle: -11, layer: 2)
        default: Spot(x: 36, angle: 10, layer: 1)
        }
    }

    /// Stamps scatter across the page rather than fan: the newest left of centre, the others
    /// up and down the right-hand side, each at its own ink angle (set by the stamp itself).
    private func stampPlacement(rank: Int, of count: Int) -> Spot {
        switch (count, rank) {
        case (1, _): Spot(x: 0, angle: 0, layer: 3)
        case (2, 0): Spot(x: -28, y: 4, angle: 0, layer: 3)
        case (2, _): Spot(x: 30, y: -6, angle: 0, layer: 2)
        case (_, 0): Spot(x: -30, y: 2, angle: 0, layer: 3)
        case (_, 1): Spot(x: 34, y: -18, angle: 0, layer: 2)
        default: Spot(x: 30, y: 20, angle: 0, layer: 1)
        }
    }

    private var isPassport: Bool {
        collection.kind == .countries
    }

    var body: some View {
        ZStack {
            if items.isEmpty {
                GhostSlip(kind: collection.kind)
            } else {
                if isPassport {
                    PassportPage()
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { rank, item in
                    let spot = isPassport ? stampPlacement(rank: rank, of: items.count) : placement(rank: rank, of: items.count)
                    MiniKeepsake(item: item, collection: collection, rank: rank)
                        .paperTilt(spot.angle, anchor: .bottom)
                        .offset(x: spot.x, y: spot.y - rise)
                        .animation(
                            Motion.animation(Motion.settle, reduceMotion: reduceMotion)
                                .delay(Motion.staggerDelay(rank, reduceMotion: reduceMotion)),
                            value: rise,
                        )
                        .zIndex(spot.layer)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(items.map(\.name).formatted(.list(type: .and)))
        .accessibilityHidden(items.isEmpty)
    }
}

/// A keepsake small enough for a drawer. Countries get their passport stamp; every other kind
/// gets a paper slip in its accent ink until its own template lands (keepsake kit II).
struct MiniKeepsake: View {
    let item: Item
    let collection: ExperienceCollection
    var rank = 0

    var body: some View {
        if collection.kind == .countries {
            PassportStamp(
                country: item.name,
                code: item.isoCode,
                date: item.firstEncountered,
                ink: collection.accent.token,
            )
            // Ink the stamp at full size so the country name isn't squeezed, then shrink it.
            .fixedSize()
            .scaleEffect(0.5)
            .frame(width: 64, height: 44)
        } else {
            slip
        }
    }

    private var slip: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: collection.icon)
                    .font(.system(size: 10, weight: .semibold))
                if collection.ratingMode == .ranked {
                    Text("No. \(rank + 1)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                }
            }
            .foregroundStyle(collection.accent.token.color)
            Text(item.name)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.textPrimary.color)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(Spacing.small)
        .frame(width: 90, height: 66, alignment: .topLeading)
        .background(KeepsakePaper(seed: item.id.uuidString))
        .clipShape(RoundedRectangle(cornerRadius: Radius.keepsake))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(collection.accent.token.color.opacity(0.7))
                .frame(height: 2)
                .accessibilityHidden(true)
        }
        .shadow(color: Palette.textPrimary.color.opacity(0.14), radius: 4, y: 2)
    }
}

/// A passport page for country stamps: paper with a faint ruled guilloche border.
private struct PassportPage: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Radius.keepsake)
            .fill(Palette.keepsakePaper.color)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.keepsake)
                    .inset(by: 4)
                    .stroke(CollectionAccent.country.token.color.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [2, 2])),
            )
            .frame(maxWidth: 150, maxHeight: .infinity)
            .paperTilt(-1.5)
            .shadow(color: Palette.textPrimary.color.opacity(0.1), radius: 4, y: 2)
            .accessibilityHidden(true)
    }
}

/// A dashed outline where the first keepsake will go, shaped like its kind.
struct GhostSlip: View {
    let kind: CollectionKind

    var body: some View {
        Group {
            if kind == .countries {
                Circle()
                    .strokeBorder(Palette.brand.color.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .frame(width: 72, height: 72)
            } else {
                RoundedRectangle(cornerRadius: Radius.keepsake)
                    .strokeBorder(Palette.brand.color.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .frame(width: 90, height: 66)
            }
        }
        .paperTilt(-3)
        .accessibilityHidden(true)
    }
}

/// The blank tag at the end of the cabinet that starts a new collection.
struct NewCollectionTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.small) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                Text("New collection")
                    .typeToken(.callout)
                Text("a blank tag for anything")
                    .font(.system(.caption, design: .serif).italic())
                    .foregroundStyle(Palette.textSecondary.color)
            }
            .foregroundStyle(Palette.brand.color)
            .frame(maxWidth: .infinity, minHeight: 172)
            .background(
                RoundedRectangle(cornerRadius: Radius.medium)
                    .strokeBorder(Palette.brand.color.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])),
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New collection")
        .accessibilityIdentifier("newCollectionTile")
    }
}

/// The home-screen "edit" wobble while arranging. Each drawer starts at its own phase. Under
/// Reduce Motion there's no wobble; a brand outline marks the arranging state instead.
struct Jiggle: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isActive: Bool
    let seed: String

    func body(content: Content) -> some View {
        if isActive, reduceMotion {
            content.overlay(
                RoundedRectangle(cornerRadius: Radius.medium)
                    .strokeBorder(Palette.brand.color.opacity(0.5), lineWidth: 1.5),
            )
        } else if isActive {
            content.keyframeAnimator(initialValue: 0.0, repeating: true) { view, angle in
                view.rotationEffect(.degrees(angle))
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(0.0, duration: 0.01 + Seed.unit(seed) * 0.12)
                    LinearKeyframe(1.1, duration: 0.12)
                    LinearKeyframe(-1.1, duration: 0.24)
                    LinearKeyframe(0.0, duration: 0.12)
                }
            }
        } else {
            content
        }
    }
}
