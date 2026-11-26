import DesignSystem
import Model
import SwiftUI

/// One card in the riffle: card stock with an index tab on its top edge, holding the keepsake
/// (or, for a guide card, the year or relish word on a plum wash).
struct RiffleCardView: View {
    let card: RiffleCard
    let collection: ExperienceCollection
    /// Which third of the top edge the tab sits on (0, 1 or 2).
    let slot: Int
    let isFront: Bool
    let width: Double

    /// Height over width.
    static let aspect = 0.76
    /// How tall the tab is above the card's top edge.
    static let tabHeight: CGFloat = 24

    private var height: Double {
        width * Self.aspect
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RiffleTab(text: card.tab, isFront: isFront, ink: collection.accent.token.color)
                .frame(width: width / 3 - 8, alignment: .leading)
                .offset(x: Double(slot) * width / 3 + 4, y: -Self.tabHeight + 2)
            stock
        }
        .frame(width: width, height: height, alignment: .topLeading)
        // One element per card, read as its keepsake (the tab is decoration).
        .accessibilityElement(children: .combine)
    }

    private var stock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.small)
                .fill(Palette.keepsakePaper.color)
            if card.isGuide {
                RoundedRectangle(cornerRadius: Radius.small)
                    .fill(Palette.brand.color.opacity(0.12))
            }
            content
                .padding(Spacing.medium)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.small))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.small)
                .strokeBorder(Palette.separator.color, lineWidth: 1),
        )
        .shadow(color: Palette.textPrimary.color.opacity(0.12), radius: 6, y: -1)
    }

    @ViewBuilder
    private var content: some View {
        switch card.content {
        case let .keepsake(item, rank):
            ItemKeepsake(item: item, collection: collection, rank: rank)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
        case let .guide(title, detail):
            VStack(spacing: Spacing.small) {
                Text(title)
                    .typeToken(.display)
                    .foregroundStyle(Palette.brand.color)
                Text(detail)
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(Palette.textSecondary.color)
                MacronBar(progress: 0.3, height: 3)
                    .frame(width: 48)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(card.spoken)
            .accessibilityAddTraits(.isHeader)
        }
    }
}

/// An index tab: the card's place in the order. The front card's tab carries the saffron macron.
private struct RiffleTab: View {
    let text: String
    let isFront: Bool
    let ink: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(isFront ? Palette.textPrimary.color : ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if isFront {
                MacronBar(progress: 1, height: 2)
                    .frame(width: 22)
            }
        }
        .padding(.horizontal, Spacing.small)
        .frame(height: RiffleCardView.tabHeight, alignment: .center)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5)
                .fill(Palette.keepsakePaper.color),
        )
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5)
                .strokeBorder(Palette.separator.color, lineWidth: 1),
        )
        .accessibilityHidden(true)
    }
}

/// The jump rail down the right-hand side: the marks (No. 1, years, relish words, initials).
/// Tap one or scrub along it to jump; VoiceOver adjusts it up and down.
struct RiffleRail: View {
    let marks: [RiffleMark]
    let front: Int
    let jump: (Int) -> Void

    static let width: CGFloat = 64
    static let rowHeight: CGFloat = 26

    /// The mark for the card at the front: the last one at or before it.
    private var current: Int? {
        marks.lastIndex { $0.cardIndex <= front }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(marks.enumerated()), id: \.element.id) { position, mark in
                HStack(spacing: Spacing.xs) {
                    Text(mark.label)
                        .font(.system(size: 11, weight: position == current ? .bold : .regular, design: .monospaced))
                        .foregroundStyle(position == current ? Palette.brand.color : Palette.textSecondary.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Capsule()
                        .fill(position == current ? Palette.saffron.color : .clear)
                        .frame(width: 3, height: 12)
                }
                .frame(width: Self.width, height: Self.rowHeight, alignment: .trailing)
            }
        }
        .contentShape(Rectangle())
        .gesture(scrub)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Jump to")
        .accessibilityValue(current.map { marks[$0].label } ?? "")
        .accessibilityAdjustableAction { direction in
            let now = current ?? 0
            switch direction {
            case .increment: jumpToMark(now + 1)
            case .decrement: jumpToMark(now - 1)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("riffleRail")
    }

    private var scrub: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let row = Int(value.location.y / Self.rowHeight)
                if row != current {
                    jumpToMark(row)
                }
            }
    }

    private func jumpToMark(_ position: Int) {
        guard marks.indices.contains(position) else { return }
        jump(marks[position].cardIndex)
    }
}

/// The front of the open drawer along the bottom: its label, and a tap shuts it.
struct DrawerLip: View {
    let collection: ExperienceCollection
    let shut: () -> Void

    var body: some View {
        Button(action: shut) {
            HStack(spacing: Spacing.small) {
                Image(systemName: collection.icon)
                    .foregroundStyle(collection.accent.token.color)
                Text(collection.name)
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary.color)
                Spacer(minLength: 0)
                Capsule()
                    .fill(Palette.textSecondary.color.opacity(0.25))
                    .frame(width: 44, height: 8)
            }
            .padding(.horizontal, Spacing.large)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                LinearGradient(
                    colors: [Palette.surface.color, Palette.background.color],
                    startPoint: .top,
                    endPoint: .bottom,
                ),
                in: RoundedRectangle(cornerRadius: Radius.medium),
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(collection.accent.token.color.opacity(0.75))
                    .frame(height: 3)
                    .padding(.horizontal, Spacing.large)
            }
            .shadow(color: Palette.textPrimary.color.opacity(0.18), radius: 10, y: -4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shut the \(collection.name) drawer")
        .accessibilityIdentifier("drawerShut")
    }
}
