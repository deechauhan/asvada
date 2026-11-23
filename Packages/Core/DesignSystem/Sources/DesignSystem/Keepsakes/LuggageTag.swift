import SwiftUI

/// A custom-collection keepsake: a luggage tag with an eyelet, inked in the collection's colour.
public struct LuggageTag: KeepsakeTemplate {
    let collection: String
    let title: String
    let detail: String?
    let icon: String
    let ink: ColorToken

    /// - Parameters:
    ///   - collection: collection name, printed as the label (e.g. "Concerts").
    ///   - title: the item (e.g. "Radiohead, O2").
    ///   - detail: optional line such as a date or companions.
    ///   - icon: the collection's SF Symbol.
    ///   - ink: the collection's accent.
    public init(collection: String, title: String, detail: String? = nil, icon: String, ink: ColorToken) {
        self.collection = collection
        self.title = title
        self.detail = detail
        self.icon = icon
        self.ink = ink
    }

    public var accessibilitySummary: String {
        [collection, title, detail].compactMap(\.self).joined(separator: ", ")
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(ink.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(collection)
                    .typeToken(.ticketLabel)
                    .foregroundStyle(ink.color)
                Text(title)
                    .typeToken(.title)
                    .foregroundStyle(Palette.textPrimary.color)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.system(.caption, design: .monospaced, weight: .medium))
                        .foregroundStyle(Palette.textSecondary.color)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.large)
        .padding(.leading, 44)
        .padding(.trailing, Spacing.large)
        .background(KeepsakePaper(seed: title))
        .clipShape(TagShape())
        .overlay(alignment: .leading) {
            Circle()
                .fill(Palette.background.color)
                .overlay(Circle().stroke(ink.color.opacity(0.5), lineWidth: 2))
                .frame(width: 12, height: 12)
                .padding(.leading, 16)
                .accessibilityHidden(true)
        }
        .shadow(color: Palette.textPrimary.color.opacity(0.12), radius: 10, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }
}

/// A tag outline: square on the right, chamfered to a point on the left.
struct TagShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = min(30, rect.height * 0.35)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + notch, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - Radius.keepsake, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + Radius.keepsake),
            control: CGPoint(x: rect.maxX, y: rect.minY),
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - Radius.keepsake))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - Radius.keepsake, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY),
        )
        path.addLine(to: CGPoint(x: rect.minX + notch, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
