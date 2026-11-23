import SwiftUI

/// A café keepsake: a narrow till receipt with a torn zig-zag foot and a faint coffee ring.
/// Name, district, date and time in mono, "SAVOURED ×4", and the rank as "No. 3".
public struct Receipt: KeepsakeTemplate {
    let name: String
    let district: String?
    let date: Date?
    let visits: Int
    let rank: Int?
    let ink: ColorToken

    /// - Parameters:
    ///   - name: the café, e.g. "Prufrock Coffee".
    ///   - district: neighbourhood, e.g. "Clerkenwell".
    ///   - date: the latest visit.
    ///   - visits: how many times it's been savoured.
    ///   - rank: position in the ranked list, if ranked.
    ///   - ink: the collection's accent (Cafés is Coffee).
    public init(
        name: String,
        district: String? = nil,
        date: Date? = nil,
        visits: Int = 1,
        rank: Int? = nil,
        ink: ColorToken = CollectionAccent.cafe.token,
    ) {
        self.name = name
        self.district = district
        self.date = date
        self.visits = visits
        self.rank = rank
        self.ink = ink
    }

    public var accessibilitySummary: String {
        var parts = ["Receipt", name]
        if let district {
            parts.append(district)
        }
        if let rank {
            parts.append("number \(rank)")
        }
        parts.append(visits == 1 ? "savoured once" : "savoured \(visits) times")
        return parts.joined(separator: ", ")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(alignment: .firstTextBaseline) {
                Text("Receipt")
                    .typeToken(.ticketLabel)
                    .foregroundStyle(ink.color)
                Spacer(minLength: Spacing.small)
                if let rank {
                    Text("No. \(rank)")
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundStyle(Palette.brand.color)
                }
            }
            Text(name.uppercased())
                .font(.system(.headline, design: .monospaced, weight: .bold))
                .foregroundStyle(Palette.textPrimary.color)
                .fixedSize(horizontal: false, vertical: true)
            Group {
                if let district {
                    Text(district)
                }
                if let date {
                    Text(KeepsakeDate.withTime(date))
                }
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Palette.textSecondary.color)
            DashedRule(ink: Palette.textSecondary.color)
            HStack {
                Text("Savoured")
                    .typeToken(.ticketLabel)
                Spacer()
                Text("×\(visits)")
                    .font(.system(.callout, design: .monospaced, weight: .bold))
            }
            .foregroundStyle(Palette.textPrimary.color)
        }
        .padding(.horizontal, Spacing.large)
        .padding(.top, Spacing.large)
        .padding(.bottom, Spacing.large + 6)
        .frame(maxWidth: 240, alignment: .leading)
        .background {
            KeepsakePaper(seed: name)
                .overlay(alignment: .bottomTrailing) {
                    // The coffee ring someone left on it.
                    Circle()
                        .stroke(ink.color.opacity(0.12), lineWidth: 5)
                        .frame(width: 70, height: 70)
                        .offset(x: 18, y: 6)
                }
        }
        .clipShape(ZigZagFoot())
        .shadow(color: Palette.textPrimary.color.opacity(0.12), radius: 8, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }
}

/// A dashed horizontal rule, as on a till receipt.
struct DashedRule: View {
    let ink: Color

    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: 1)
            .overlay(
                Rectangle()
                    .stroke(ink.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3])),
            )
            .accessibilityHidden(true)
    }
}
