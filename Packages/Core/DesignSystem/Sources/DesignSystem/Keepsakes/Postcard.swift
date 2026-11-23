import SwiftUI

/// A city keepsake: a postcard. The photo is the picture side (or the city's name inked large
/// until there is one); a round postmark carries the city, country and date, with wavy
/// cancellation lines running off it, and a perforated stamp sits in the corner. How it felt is
/// written across the bottom as a relish word.
public struct Postcard: KeepsakeTemplate {
    let city: String
    let country: String?
    let date: Date?
    let relish: String?
    let photo: Image?
    let ink: ColorToken

    /// - Parameters:
    ///   - city: e.g. "Lisbon".
    ///   - country: e.g. "Portugal".
    ///   - date: when it was visited.
    ///   - relish: a relish word, e.g. "Sublime".
    ///   - photo: the entry's photo, if any.
    ///   - ink: the collection's accent (Cities is Indigo).
    public init(
        city: String,
        country: String? = nil,
        date: Date? = nil,
        relish: String? = nil,
        photo: Image? = nil,
        ink: ColorToken = CollectionAccent.city.token,
    ) {
        self.city = city
        self.country = country
        self.date = date
        self.relish = relish
        self.photo = photo
        self.ink = ink
    }

    public var accessibilitySummary: String {
        var parts = ["Postcard from \(city)"]
        if let country {
            parts.append(country)
        }
        if let relish {
            parts.append(relish)
        }
        return parts.joined(separator: ", ")
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            front
            LinearGradient(
                colors: [.clear, .black.opacity(0.45)],
                startPoint: .center,
                endPoint: .bottom,
            )
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("Greetings from")
                    .typeToken(.ticketLabel)
                    .foregroundStyle(.white.opacity(0.85))
                Text(city)
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let relish {
                    Text(relish)
                        .font(.system(.title3, design: .serif).italic())
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(Spacing.large)
        }
        .overlay(alignment: .topTrailing) {
            // The stamp only just kisses the postmark, so the city and country stay legible.
            HStack(alignment: .top, spacing: -4) {
                Postmark(city: city, country: country, date: date)
                PostageStamp(ink: ink.color)
            }
            .padding(Spacing.medium)
        }
        .aspectRatio(3 / 2, contentMode: .fit)
        .frame(maxWidth: 340)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .padding(6)
        .background(KeepsakePaper(seed: city))
        .clipShape(RoundedRectangle(cornerRadius: Radius.keepsake))
        .shadow(color: Palette.textPrimary.color.opacity(0.14), radius: 10, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// The picture side: the photo, or the accent inked as a dusk sky until there is one.
    @ViewBuilder
    private var front: some View {
        if let photo {
            photo.resizable().scaledToFill()
        } else {
            LinearGradient(
                colors: [ink.color.opacity(0.9), Palette.aubergineBottom.color],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white.opacity(0.12))
                    .padding(Spacing.large)
            }
        }
    }
}

/// A round postmark: the city on top, the date across the middle, the country beneath, with wavy
/// cancellation lines trailing off to the left.
private struct Postmark: View {
    let city: String
    let country: String?
    let date: Date?

    var body: some View {
        ZStack {
            Cancellation()
                .stroke(.white.opacity(0.55), lineWidth: 1.5)
                .frame(width: 70, height: 24)
                .offset(x: -48)
            Circle().stroke(.white.opacity(0.8), lineWidth: 1.5)
            Circle().inset(by: 4).stroke(.white.opacity(0.6), lineWidth: 0.75)
            VStack(spacing: 1) {
                Text(city)
                    .font(.system(size: 8, weight: .bold).width(.expanded))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let date {
                    Text(KeepsakeDate.short(date))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                }
                if let country {
                    Text(country)
                        .font(.system(size: 7, weight: .semibold).width(.expanded))
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(8)
        }
        .frame(width: 64, height: 64)
        .rotationEffect(.degrees(-12))
        .accessibilityHidden(true)
    }
}

/// Three wavy lines, as a franking machine leaves.
private struct Cancellation: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for line in 0 ..< 3 {
            let y = rect.minY + rect.height * CGFloat(line) / 2
            path.move(to: CGPoint(x: rect.minX, y: y))
            let waves = 4
            let step = rect.width / CGFloat(waves)
            for wave in 0 ..< waves {
                let startX = rect.minX + CGFloat(wave) * step
                path.addQuadCurve(
                    to: CGPoint(x: startX + step, y: y),
                    control: CGPoint(x: startX + step / 2, y: y + (wave.isMultiple(of: 2) ? -4 : 4)),
                )
            }
        }
        return path
    }
}

/// A small perforated stamp in the collection's ink, bearing the ā.
private struct PostageStamp: View {
    let ink: Color

    var body: some View {
        ZStack {
            Rectangle().fill(Palette.keepsakePaper.color)
            Rectangle().inset(by: 4).fill(ink)
            Text("ā")
                .font(.system(size: 20, weight: .heavy, design: .serif))
                .foregroundStyle(Palette.keepsakePaper.color)
        }
        .frame(width: 40, height: 48)
        .overlay(
            Rectangle()
                .stroke(Palette.background.color, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.1, 5])),
        )
        .rotationEffect(.degrees(4))
        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        .accessibilityHidden(true)
    }
}
