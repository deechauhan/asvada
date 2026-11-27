import DesignSystem
import Geo
import Model
import Storage
import SwiftUI

/// An open drawer tipped out onto the table (INTERACTION.md §4b step 6, #44): every keepsake at
/// once, laid out for the drawer's rating mode. Tapping one hands it back (to the riffle at that
/// card, or to its page where there's no riffle). Each card carries a matched-geometry id, so
/// tipping the drawer out and back moves the cards rather than swapping screens.
struct DrawerSpread: View {
    let collection: ExperienceCollection
    /// What to show, already sorted and filtered.
    let items: [Item]
    let kind: SpreadKind
    /// Each item's place in the drawer's ranking (1 = best), for The Menu's "No. n".
    let ranks: [UUID: Int]
    let morph: Namespace.ID
    let pick: (Item) -> Void
    /// The Menu's "Re-order by hand", when the drawer is ranked.
    var reorder: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.large) {
            Masthead(title: kind.title, caption: caption)
                // On the masthead alone: an identifier on the whole spread would rename its cards.
                .accessibilityIdentifier("spread-\(kind.title)")
            switch kind {
            case .menu: menu
            case .ticketBox: ticketBox
            case .passport: passport
            case .pinboard: pinboard
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var caption: String {
        switch kind {
        case .menu: "best first, by duels"
        case .ticketBox: "by year"
        case .passport: items.count == 1 ? "1 stamp" : "\(items.count) stamps"
        case .pinboard: "pinned where they landed"
        }
    }

    // MARK: - The Menu

    @ViewBuilder
    private var menu: some View {
        if let first = items.first {
            card(first) {
                VStack(spacing: Spacing.small) {
                    MenuNumber(rank: ranks[first.id] ?? 1)
                    ItemKeepsake(item: first, collection: collection, rank: ranks[first.id])
                }
            }
        }
        VStack(spacing: Spacing.medium) {
            ForEach(items.dropFirst(), id: \.id) { item in
                card(item) {
                    MenuLine(rank: ranks[item.id], name: item.name, detail: SpreadText.detail(for: item))
                }
            }
        }
        if let reorder, items.count > 1 {
            Button("Re-order by hand", systemImage: "arrow.up.arrow.down", action: reorder)
                .typeToken(.callout)
                .foregroundStyle(Palette.brand.color)
                .accessibilityIdentifier("menuReorder")
        }
    }

    // MARK: - Ticket box

    private var ticketBox: some View {
        VStack(spacing: Spacing.xl) {
            ForEach(SpreadYear.group(items)) { year in
                VStack(spacing: Spacing.medium) {
                    Text("— \(String(year.year)) —")
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary.color)
                        .accessibilityLabel("\(String(year.year)), \(SpreadText.count(year.items.count))")
                        .accessibilityAddTraits(.isHeader)
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.medium), count: 3),
                        spacing: Spacing.large,
                    ) {
                        ForEach(year.items, id: \.id) { item in
                            card(item) {
                                VStack(spacing: Spacing.xxs) {
                                    MiniKeepsake(item: item, collection: collection)
                                    if item.encounterCount > 1 {
                                        Text("×\(item.encounterCount)")
                                            .font(.system(.caption, design: .monospaced, weight: .semibold))
                                            .foregroundStyle(collection.accent.token.color)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Passport

    private var passport: some View {
        let pages = SpreadText.pages(of: items, perPage: 6)
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: Spacing.medium) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    PassportSpreadPage(number: index + 1) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.medium) {
                            ForEach(page, id: \.id) { item in
                                card(item) {
                                    PassportStamp(
                                        country: item.name,
                                        code: item.isoCode,
                                        date: item.firstEncountered,
                                        ink: collection.accent.token,
                                    )
                                    .fixedSize()
                                    .scaleEffect(0.72)
                                    .frame(height: 76)
                                }
                            }
                        }
                    }
                    .containerRelativeFrame(.horizontal) { width, _ in width * 0.88 }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .accessibilityIdentifier("passportSpread")
    }

    // MARK: - Pinboard

    private var pinboard: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.large), GridItem(.flexible())], spacing: Spacing.xl) {
            ForEach(items, id: \.id) { item in
                card(item) {
                    ItemKeepsake(item: item, collection: collection)
                        .scaleEffect(0.92)
                }
                .paperTilt(SpreadText.tilt(for: item.id))
            }
        }
    }

    // MARK: - Cards

    /// A tappable card in the spread: hands the item back, and morphs to and from its place in
    /// the riffle.
    private func card(_ item: Item, @ViewBuilder content: () -> some View) -> some View {
        Button {
            pick(item)
        } label: {
            content()
        }
        .buttonStyle(.plain)
        .matchedGeometryEffect(id: item.id.uuidString, in: morph)
        .accessibilityIdentifier("spreadCard")
    }
}

/// The spread's masthead: its name in serif between rules, and what it's ordered by.
private struct Masthead: View {
    let title: String
    let caption: String

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            HStack(spacing: Spacing.medium) {
                Rectangle().fill(Palette.separator.color).frame(width: 28, height: 1)
                Text(title)
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary.color)
                Rectangle().fill(Palette.separator.color).frame(width: 28, height: 1)
            }
            Text(caption)
                .font(.system(.footnote, design: .serif).italic())
                .foregroundStyle(Palette.textSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// "No. 1" over a saffron macron.
private struct MenuNumber: View {
    let rank: Int

    var body: some View {
        VStack(spacing: 3) {
            Text("No. \(rank)")
                .font(.system(.headline, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.brand.color)
            MacronBar(progress: 1, height: 3)
                .frame(width: 36)
        }
        .accessibilityHidden(true)
    }
}

/// One printed line of The Menu: "No. 2  Monmouth ............ Borough".
private struct MenuLine: View {
    let rank: Int?
    let name: String
    let detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            if let rank {
                Text("No. \(rank)")
                    .font(.system(.footnote, design: .monospaced, weight: .semibold))
                    .foregroundStyle(Palette.brand.color)
                    .frame(width: 52, alignment: .leading)
            }
            Text(name)
                .font(.system(.body, design: .serif))
                .foregroundStyle(Palette.textPrimary.color)
                .lineLimit(1)
            DottedLeader()
                .frame(height: 1)
                .frame(minWidth: 12)
            if let detail {
                Text(detail)
                    .font(.system(.footnote, design: .serif).italic())
                    .foregroundStyle(Palette.textSecondary.color)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Spacing.small)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([rank.map { "No. \($0)" }, name, detail].compactMap(\.self).joined(separator: ", "))
    }
}

/// The dots between a dish and its price on a printed menu.
private struct DottedLeader: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
            }
            .stroke(Palette.textSecondary.color.opacity(0.6), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1, 4]))
        }
        .accessibilityHidden(true)
    }
}

/// One page of the passport: paper with a dashed border, its stamps, and the page number.
private struct PassportSpreadPage<Content: View>: View {
    let number: Int
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: Spacing.small) {
            content
            Spacer(minLength: 0)
            Text("\(number)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Palette.textSecondary.color)
                .accessibilityHidden(true)
        }
        .padding(Spacing.medium)
        .frame(minHeight: 300, alignment: .top)
        .background(Palette.keepsakePaper.color, in: RoundedRectangle(cornerRadius: Radius.keepsake))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.keepsake)
                .inset(by: 5)
                .stroke(CollectionAccent.country.token.color.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [2, 2])),
        )
        .shadow(color: Palette.textPrimary.color.opacity(0.1), radius: 4, y: 2)
    }
}

/// The words and small sums the spreads use.
enum SpreadText {
    /// A menu line's detail: the country it's in, else the street it's on, else when it was last
    /// savoured.
    static func detail(for item: Item, catalog: CountryCatalog = .shared) -> String? {
        if let code = item.countryCode, let country = catalog.country(code: code) {
            return country.name
        }
        if let address = item.placeAddress, let street = address.split(separator: ",").first {
            return String(street).trimmingCharacters(in: .whitespaces)
        }
        guard item.entries?.isEmpty == false else { return nil }
        return KeepsakeDate.short(item.lastEncountered)
    }

    /// "1 keepsake", "3 keepsakes".
    static func count(_ count: Int) -> String {
        count == 1 ? "1 keepsake" : "\(count) keepsakes"
    }

    /// `items` cut into pages of `perPage`.
    static func pages<Element>(of items: [Element], perPage: Int) -> [[Element]] {
        guard perPage > 0 else { return [items] }
        return stride(from: 0, to: items.count, by: perPage).map { start in
            Array(items[start ..< min(start + perPage, items.count)])
        }
    }

    /// A pin's lean, −3° to 3°, fixed for each keepsake so the board doesn't shuffle.
    static func tilt(for id: UUID) -> Double {
        Double(Int(id.uuid.0) % 7) - 3
    }
}
