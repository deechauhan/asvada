import SwiftUI

/// A film keepsake: a perforated cinema ticket. The stub on the left says ADMIT ONE and holds the
/// poster; the right carries the title, year, date and seat, and how it landed (a relish word,
/// or ×n for rewatches).
public struct TicketStub: KeepsakeTemplate {
    let title: String
    let year: Int?
    let date: Date?
    let seat: String?
    let relish: String?
    let rewatches: Int
    let poster: Image?
    let ink: ColorToken

    /// - Parameters:
    ///   - title: the film, e.g. "Perfect Days".
    ///   - year: release year.
    ///   - date: when it was watched.
    ///   - seat: optional seat, e.g. "F12".
    ///   - relish: a relish word, e.g. "Lovely".
    ///   - rewatches: how many times it's been watched (shown as ×n when more than once).
    ///   - poster: a cached poster thumbnail, if any.
    ///   - ink: the collection's accent (Films is Rose).
    public init(
        title: String,
        year: Int? = nil,
        date: Date? = nil,
        seat: String? = nil,
        relish: String? = nil,
        rewatches: Int = 1,
        poster: Image? = nil,
        ink: ColorToken = CollectionAccent.film.token,
    ) {
        self.title = title
        self.year = year
        self.date = date
        self.seat = seat
        self.relish = relish
        self.rewatches = rewatches
        self.poster = poster
        self.ink = ink
    }

    /// Width of the ADMIT ONE stub, left of the tear.
    static let stubWidth: CGFloat = 96

    public var accessibilitySummary: String {
        var parts = ["Ticket stub", title]
        if let year {
            parts.append(String(year))
        }
        if let relish {
            parts.append(relish)
        }
        if rewatches > 1 {
            parts.append("watched \(rewatches) times")
        }
        return parts.joined(separator: ", ")
    }

    public var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: Spacing.xs) {
                Text("Admit one")
                    .typeToken(.ticketLabel)
                    .foregroundStyle(ink.color)
                    .fixedSize()
                    .rotationEffect(.degrees(-90))
                    .frame(width: 16)
                posterView
            }
            .frame(width: Self.stubWidth)
            Perforation(ink: ink.color)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundStyle(Palette.textPrimary.color)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let year {
                    Text(String(year))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.textSecondary.color)
                }
                Spacer(minLength: Spacing.xs)
                HStack(alignment: .bottom, spacing: Spacing.medium) {
                    if let date {
                        TicketField(label: "Date", value: KeepsakeDate.short(date), ink: ink.color)
                    }
                    if let seat {
                        TicketField(label: "Seat", value: seat, ink: ink.color)
                    }
                    Spacer(minLength: 0)
                    verdict
                }
            }
            .padding(Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 340, minHeight: 124)
        .background(KeepsakePaper(seed: title))
        .overlay(alignment: .top) {
            Rectangle().fill(ink.color).frame(height: 4).accessibilityHidden(true)
        }
        .clipShape(NotchedTicket(tear: .fromLeading(Self.stubWidth)))
        .shadow(color: Palette.textPrimary.color.opacity(0.12), radius: 8, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private var verdict: some View {
        if rewatches > 1 {
            Text("×\(rewatches)")
                .font(.system(.headline, design: .monospaced, weight: .bold))
                .foregroundStyle(Palette.brand.color)
        } else if let relish {
            Text(relish)
                .font(.system(.headline, design: .serif).italic())
                .foregroundStyle(Palette.brand.color)
        }
    }

    /// The poster, or a placeholder frame with the film symbol until one is cached.
    private var posterView: some View {
        Group {
            if let poster {
                poster.resizable().scaledToFill()
            } else {
                ink.color.opacity(0.14)
                    .overlay(
                        Image(systemName: "film")
                            .foregroundStyle(ink.color.opacity(0.7)),
                    )
            }
        }
        .frame(width: 58, height: 86)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .accessibilityHidden(true)
    }
}
