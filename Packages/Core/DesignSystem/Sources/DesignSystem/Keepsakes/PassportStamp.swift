import SwiftUI

/// The ink outline a passport stamp uses. Chosen from a hash of the country code, so a country
/// always gets the same stamp and a passport page looks collected, not generated.
public enum StampShape: CaseIterable, Sendable {
    case round
    case rectangle
    case octagon
    case triangle

    public static func forCode(_ code: String) -> StampShape {
        allCases[Int(Seed.hash(code.uppercased()) % UInt64(allCases.count))]
    }
}

/// A country keepsake: single-colour ink stamp with the country, "ENTRY" and a date.
public struct PassportStamp: KeepsakeTemplate {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let country: String
    let code: String
    let date: Date?
    let ink: ColorToken

    /// - Parameters:
    ///   - country: display name, e.g. "Japan".
    ///   - code: ISO code, e.g. "JP" (drives the shape and angle).
    ///   - date: first entry date, if known.
    ///   - ink: the collection's accent (Countries is Jade).
    public init(country: String, code: String, date: Date? = nil, ink: ColorToken = CollectionAccent.country.token) {
        self.country = country
        self.code = code
        self.date = date
        self.ink = ink
    }

    /// Stamps print dates like a real entry stamp, "03·04·25" (day·month·year), in every locale.
    static func stampDate(_ date: Date) -> String {
        KeepsakeDate.short(date)
    }

    var shape: StampShape {
        StampShape.forCode(code)
    }

    public var accessibilitySummary: String {
        if let date {
            "Passport stamp, \(country), entered \(date.formatted(date: .long, time: .omitted))"
        } else {
            "Passport stamp, \(country)"
        }
    }

    public var body: some View {
        VStack(spacing: Spacing.xxs) {
            Text(country)
                .typeToken(.ticketLabel)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text("Entry")
                .typeToken(.ticketLabel)
                .opacity(0.8)
            if let date {
                Text(Self.stampDate(date))
                    .font(.system(.caption, design: .monospaced, weight: .medium))
            }
        }
        .foregroundStyle(ink.color)
        // A triangle only has room near its base, so its text sits low with wide side margins.
        .padding(.horizontal, shape == .triangle ? Spacing.xxl : Spacing.medium)
        .padding(.top, shape == .triangle ? 52 : Spacing.medium)
        .padding(.bottom, shape == .triangle ? Spacing.small : Spacing.medium)
        .frame(minWidth: shape == .triangle ? 150 : 96, minHeight: shape == .round ? 96 : 72)
        .background { StampOutline(shape: shape, ink: ink.color) }
        .opacity(0.88)
        .rotationEffect(.degrees(reduceMotion ? 0 : Tilt.degrees(for: code, max: Tilt.stampMax)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }
}

/// The double-ruled ink outline for each stamp shape.
private struct StampOutline: View {
    let shape: StampShape
    let ink: Color

    var body: some View {
        switch shape {
        case .round:
            ZStack {
                Circle().stroke(ink, lineWidth: 2.5)
                Circle().inset(by: 5).stroke(ink, lineWidth: 1)
            }
        case .rectangle:
            ZStack {
                RoundedRectangle(cornerRadius: 4).stroke(ink, lineWidth: 2.5)
                RoundedRectangle(cornerRadius: 2).inset(by: 5).stroke(ink, lineWidth: 1)
            }
        case .octagon:
            ZStack {
                Octagon().stroke(ink, lineWidth: 2.5)
                Octagon().inset(by: 5).stroke(ink, lineWidth: 1)
            }
        case .triangle:
            ZStack {
                Triangle().stroke(ink, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                Triangle().inset(by: 7).stroke(ink, style: StrokeStyle(lineWidth: 1, lineJoin: .round))
            }
        }
    }
}

/// A regular-ish octagon filling its rect.
struct Octagon: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let cut = min(rect.width, rect.height) * 0.29
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> Octagon {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

/// An upward triangle filling its rect.
struct Triangle: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount * 1.6, dy: insetAmount)
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> Triangle {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}
