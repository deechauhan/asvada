import SwiftUI

/// The size every share card is laid out at, in points. Rendered at `ShareCard.scale` it becomes
/// a 1080 × 1350 portrait image (4:5), the shape social feeds crop to least.
public enum ShareCard {
    public static let size = CGSize(width: 360, height: 450)
    public static let scale: CGFloat = 3

    /// Renders a share card to an image at 3×, or `nil` if rendering fails.
    @MainActor
    public static func render(_ card: some View) -> Image? {
        let renderer = ImageRenderer(content: card.frame(width: size.width, height: size.height))
        renderer.scale = scale
        guard let cgImage = renderer.cgImage else { return nil }
        return Image(decorative: cgImage, scale: scale)
    }
}

/// The frame every share card sits in: the aubergine field, a title in serif, the content, and
/// the ā colophon at the foot.
public struct ShareFrame<Content: View>: View {
    let eyebrow: String
    let title: String
    let content: Content

    /// - Parameters:
    ///   - eyebrow: small caps above the title, e.g. "My passport".
    ///   - title: e.g. "23 countries".
    public init(eyebrow: String, title: String, @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: Spacing.large) {
            VStack(spacing: Spacing.xs) {
                Text(eyebrow)
                    .typeToken(.ticketLabel)
                    .foregroundStyle(Palette.saffron.color)
                Text(title)
                    .font(.system(.title, design: .serif, weight: .bold))
                    .foregroundStyle(Palette.onAubergine.color)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Colophon()
        }
        .padding(Spacing.xl)
        .frame(width: ShareCard.size.width, height: ShareCard.size.height)
        .background(
            LinearGradient(
                colors: [Palette.aubergineTop.color, Palette.aubergineBottom.color],
                startPoint: .top,
                endPoint: .bottom,
            ),
        )
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .combine)
    }
}

/// "ā · Asvada · savoured", set small at the foot of a share card.
private struct Colophon: View {
    var body: some View {
        HStack(spacing: Spacing.small) {
            ZStack(alignment: .top) {
                Text("a")
                    .font(.system(size: 18, weight: .heavy, design: .serif))
                    .foregroundStyle(Palette.onAubergine.color)
                    .padding(.top, 3)
                Capsule()
                    .fill(Palette.saffron.color)
                    .frame(width: 9, height: 2.5)
            }
            Text("Asvada · savoured")
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(Palette.onAubergine.color.opacity(0.8))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Asvada")
    }
}

/// A single keepsake on the aubergine field.
public struct KeepsakeShareCard<Keepsake: View>: View {
    let eyebrow: String
    let title: String
    let keepsake: Keepsake

    public init(eyebrow: String, title: String, @ViewBuilder keepsake: () -> Keepsake) {
        self.eyebrow = eyebrow
        self.title = title
        self.keepsake = keepsake()
    }

    public var body: some View {
        ShareFrame(eyebrow: eyebrow, title: title) {
            keepsake
                .frame(maxWidth: 300)
                .rotationEffect(.degrees(-2))
        }
    }
}

/// A country stamp as the passport spread prints it.
public struct StampEntry: Identifiable, Sendable {
    public let country: String
    public let code: String
    public let date: Date?

    public var id: String {
        code
    }

    public init(country: String, code: String, date: Date? = nil) {
        self.country = country
        self.code = code
        self.date = date
    }
}

/// An open passport: two pages of stamps, the count and share of the world in the title.
public struct PassportSpreadCard: View {
    let stamps: [StampEntry]
    let worldTotal: Int

    /// The most stamps a spread can hold (three per page row, two rows, two pages).
    static let capacity = 12

    public init(stamps: [StampEntry], worldTotal: Int = 195) {
        self.stamps = stamps
        self.worldTotal = worldTotal
    }

    /// "23 countries · 12% of the world" (never rounds a real visit down to 0%).
    public static func title(count: Int, worldTotal: Int) -> String {
        let noun = count == 1 ? "country" : "countries"
        guard worldTotal > 0, count > 0 else { return "\(count) \(noun)" }
        let percent = max(1, Int((Double(count) / Double(worldTotal) * 100).rounded()))
        return "\(count) \(noun) · \(percent)% of the world"
    }

    private var pages: [[StampEntry]] {
        let shown = Array(stamps.prefix(Self.capacity))
        let half = (shown.count + 1) / 2
        return [Array(shown.prefix(half)), Array(shown.dropFirst(half))]
    }

    public var body: some View {
        ShareFrame(eyebrow: "My passport", title: Self.title(count: stamps.count, worldTotal: worldTotal)) {
            HStack(spacing: 0) {
                ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
                    PassportPageView(stamps: page)
                }
            }
            .background(Palette.keepsakePaper.color)
            .overlay {
                // The spine.
                Rectangle()
                    .fill(Palette.textPrimary.color.opacity(0.15))
                    .frame(width: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.keepsake))
            .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
        }
    }
}

/// One page of a passport spread: stamps in a loose grid, each at its own ink angle.
private struct PassportPageView: View {
    let stamps: [StampEntry]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.small) {
            ForEach(stamps) { stamp in
                PassportStamp(country: stamp.country, code: stamp.code, date: stamp.date)
                    .fixedSize()
                    .scaleEffect(0.48)
                    .frame(width: 70, height: 56)
            }
        }
        .padding(Spacing.small)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A ranked collection's top five, printed as a menu: "No. 1 … Prufrock Coffee ……… Clerkenwell".
public struct TopMenuCard: View {
    /// One line of the menu: the name and an optional note on the right (e.g. the district).
    public struct Course: Identifiable, Sendable {
        public let name: String
        public let detail: String?

        public var id: String {
            name
        }

        public init(name: String, detail: String? = nil) {
            self.name = name
            self.detail = detail
        }
    }

    let collection: String
    let courses: [Course]

    /// - Parameters:
    ///   - collection: the collection's name, e.g. "Cafés".
    ///   - courses: best first; only the first five are printed.
    public init(collection: String, courses: [Course]) {
        self.collection = collection
        self.courses = Array(courses.prefix(5))
    }

    /// "My top 5 cafés" (or "My top 3 cafés" when there are only three).
    static func title(collection: String, count: Int) -> String {
        "My top \(count) \(collection.lowercased())"
    }

    public var body: some View {
        ShareFrame(eyebrow: "The menu", title: Self.title(collection: collection, count: courses.count)) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                ForEach(Array(courses.enumerated()), id: \.element.id) { index, course in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                        Text("No. \(index + 1)")
                            .font(.system(.callout, design: .serif, weight: .bold))
                            .foregroundStyle(Palette.brand.color)
                            .frame(width: 44, alignment: .leading)
                        // The name wins space first; the dotted leader gives way, then the name
                        // shrinks a little before it would truncate.
                        Text(course.name)
                            .font(.system(.body, design: .serif, weight: index == 0 ? .bold : .regular))
                            .foregroundStyle(Palette.textPrimary.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .layoutPriority(2)
                        DottedLeader()
                        if let detail = course.detail {
                            Text(detail)
                                .font(.system(.caption, design: .serif).italic())
                                .foregroundStyle(Palette.textSecondary.color)
                                .lineLimit(1)
                                .layoutPriority(1)
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if index == 0 {
                            Capsule()
                                .fill(Palette.saffron.color)
                                .frame(width: 34, height: 3)
                                .offset(y: 5)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KeepsakePaper(seed: collection))
            .clipShape(DeckledRectangle(seed: collection))
            .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
        }
    }
}

/// The dotted leader between a menu course and its note.
private struct DottedLeader: View {
    var body: some View {
        Line()
            .stroke(Palette.textSecondary.color.opacity(0.6), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [0.1, 4]))
            .frame(height: 1)
            .frame(minWidth: 12)
            .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}
