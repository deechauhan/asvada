import SwiftUI

/// A restaurant keepsake: a deckle-edged menu card, set centred in serif. The dishes come from
/// the note; a "No. 1" carries a saffron underline.
public struct MenuCard: KeepsakeTemplate {
    let name: String
    let cuisine: String?
    let dishes: [String]
    let date: Date?
    let rank: Int?
    let ink: ColorToken

    /// - Parameters:
    ///   - name: the restaurant, e.g. "Dishoom".
    ///   - cuisine: e.g. "Bombay café".
    ///   - dishes: up to three dishes, printed as the courses.
    ///   - date: when it was savoured.
    ///   - rank: position in the ranked list, if ranked.
    ///   - ink: the collection's accent (Restaurants is Tomato).
    public init(
        name: String,
        cuisine: String? = nil,
        dishes: [String] = [],
        date: Date? = nil,
        rank: Int? = nil,
        ink: ColorToken = CollectionAccent.restaurant.token,
    ) {
        self.name = name
        self.cuisine = cuisine
        self.dishes = Array(dishes.prefix(3))
        self.date = date
        self.rank = rank
        self.ink = ink
    }

    public var accessibilitySummary: String {
        var parts = ["Menu card", name]
        if let cuisine {
            parts.append(cuisine)
        }
        if let rank {
            parts.append("number \(rank)")
        }
        if !dishes.isEmpty {
            parts.append(dishes.formatted(.list(type: .and)))
        }
        return parts.joined(separator: ", ")
    }

    public var body: some View {
        VStack(spacing: Spacing.small) {
            Text(cuisine ?? "Menu")
                .typeToken(.ticketLabel)
                .foregroundStyle(ink.color)
            Text(name)
                .font(.system(.title2, design: .serif, weight: .bold))
                .foregroundStyle(Palette.textPrimary.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Ornament(ink: ink.color)
            ForEach(dishes, id: \.self) { dish in
                Text(dish)
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(Palette.textSecondary.color)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: Spacing.medium) {
                if let rank {
                    Text("No. \(rank)")
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundStyle(Palette.brand.color)
                        .overlay(alignment: .bottom) {
                            if rank == 1 {
                                Capsule()
                                    .fill(Palette.saffron.color)
                                    .frame(height: 3)
                                    .offset(y: 4)
                                    .accessibilityHidden(true)
                            }
                        }
                }
                if let date {
                    Text(KeepsakeDate.short(date))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.textSecondary.color)
                }
            }
            .padding(.top, Spacing.xs)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.xl)
        .frame(maxWidth: 280)
        .background(KeepsakePaper(seed: name))
        .overlay(
            InsetDeckle(base: DeckledRectangle(seed: name), amount: 7)
                .stroke(ink.color.opacity(0.35), lineWidth: 1),
        )
        .clipShape(DeckledRectangle(seed: name))
        .shadow(color: Palette.textPrimary.color.opacity(0.12), radius: 8, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }
}

/// The little flourish under a menu's title: a rule, a diamond, a rule.
private struct Ornament: View {
    let ink: Color

    var body: some View {
        HStack(spacing: Spacing.small) {
            Rectangle().fill(ink.opacity(0.5)).frame(width: 28, height: 1)
            Image(systemName: "diamond.fill")
                .font(.system(size: 6))
                .foregroundStyle(ink.opacity(0.7))
            Rectangle().fill(ink.opacity(0.5)).frame(width: 28, height: 1)
        }
        .accessibilityHidden(true)
    }
}

/// A deckled outline drawn `amount` inside the card's edge.
struct InsetDeckle: Shape {
    let base: DeckledRectangle
    let amount: CGFloat

    func path(in rect: CGRect) -> Path {
        base.path(in: rect.insetBy(dx: amount, dy: amount))
    }
}
