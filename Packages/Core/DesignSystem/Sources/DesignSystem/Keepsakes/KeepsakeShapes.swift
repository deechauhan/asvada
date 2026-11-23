import Foundation
import SwiftUI

/// The keepsake template each kind of collection uses. Custom collections get the luggage tag.
public enum KeepsakeStyle: String, CaseIterable, Sendable {
    case receipt
    case menuCard
    case passportStamp
    case postcard
    case boardingPass
    case ticketStub
    case luggageTag
}

/// Dates and times as keepsakes print them: day·month·year with middots, in every locale.
public enum KeepsakeDate {
    /// "03·04·25".
    public static func short(_ date: Date) -> String {
        let parts = components(of: date)
        return String(format: "%02d·%02d·%02d", parts.day ?? 0, parts.month ?? 0, (parts.year ?? 0) % 100)
    }

    /// "03·04·25 08:12", for receipts.
    public static func withTime(_ date: Date) -> String {
        let parts = components(of: date)
        return short(date) + String(format: " %02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    private static func components(of date: Date) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.dateComponents([.day, .month, .year, .hour, .minute], from: date)
    }
}

/// A slip whose bottom edge is torn into a zig-zag, like a till receipt.
struct ZigZagFoot: Shape {
    var tooth: CGFloat = 10
    var depth: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - depth))
        let teeth = max(1, Int((rect.width / tooth).rounded()))
        let step = rect.width / CGFloat(teeth)
        for index in 0 ..< teeth {
            let right = rect.maxX - CGFloat(index) * step
            path.addLine(to: CGPoint(x: right - step / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: right - step, y: rect.maxY - depth))
        }
        path.closeSubpath()
        return path
    }
}

/// A card with a hand-torn (deckled) edge: every side wobbles a little, the same way each time.
struct DeckledRectangle: Shape {
    let seed: String
    var amplitude: CGFloat = 1.6
    var step: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        var state = Seed.hash(seed) | 1
        func wobble() -> CGFloat {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return (CGFloat(state % 1000) / 1000 - 0.5) * 2 * amplitude
        }
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY),
        ]
        var path = Path()
        path.move(to: corners[0])
        for side in 0 ..< 4 {
            let start = corners[side]
            let end = corners[(side + 1) % 4]
            let length = hypot(end.x - start.x, end.y - start.y)
            let segments = max(1, Int(length / step))
            // Unit normal pointing outwards for a clockwise walk.
            let normal = CGPoint(x: (end.y - start.y) / length, y: -(end.x - start.x) / length)
            for index in 1 ... segments {
                let fraction = CGFloat(index) / CGFloat(segments)
                let offset = index == segments ? 0 : wobble()
                let along = CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction)
                path.addLine(to: CGPoint(x: along.x + normal.x * offset, y: along.y + normal.y * offset))
            }
        }
        path.closeSubpath()
        return path
    }
}

/// A ticket: a rounded card with half-circle notches bitten from the top and bottom edges where
/// it tears, a fixed distance from one edge so they meet the perforation at any width.
struct NotchedTicket: Shape {
    enum Tear {
        case fromLeading(CGFloat)
        case fromTrailing(CGFloat)
    }

    let tear: Tear
    var notch: CGFloat = 9
    var radius: CGFloat = Radius.keepsake + 3

    func path(in rect: CGRect) -> Path {
        let x = switch tear {
        case let .fromLeading(distance): rect.minX + distance
        case let .fromTrailing(distance): rect.maxX - distance
        }
        let card = RoundedRectangle(cornerRadius: radius).path(in: rect)
        let top = Path(ellipseIn: CGRect(x: x - notch, y: rect.minY - notch, width: notch * 2, height: notch * 2))
        let bottom = Path(ellipseIn: CGRect(x: x - notch, y: rect.maxY - notch, width: notch * 2, height: notch * 2))
        return card.subtracting(top).subtracting(bottom)
    }
}

/// The dotted tear line between a ticket's two parts.
struct Perforation: View {
    let ink: Color

    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: 1)
            .overlay(
                Line()
                    .stroke(ink.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.5, 5])),
            )
            .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY + 12))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 12))
            return path
        }
    }
}

/// A decorative barcode generated from an id: same id, same bars. It encodes nothing.
public struct Barcode: View {
    let seed: String
    let ink: Color

    public init(seed: String, ink: Color) {
        self.seed = seed
        self.ink = ink
    }

    /// Bar widths (1–3 units) for `seed`, alternating bar and gap, starting with a bar.
    static func widths(for seed: String, count: Int = 40) -> [Int] {
        var state = Seed.hash(seed) | 1
        return (0 ..< count).map { _ in
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return Int(state % 3) + 1
        }
    }

    public var body: some View {
        Canvas { context, size in
            let widths = Self.widths(for: seed)
            let unit = size.width / CGFloat(widths.reduce(0, +))
            var x: CGFloat = 0
            for (index, width) in widths.enumerated() {
                let barWidth = CGFloat(width) * unit
                if index.isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: x, y: 0, width: barWidth, height: size.height)), with: .color(ink))
                }
                x += barWidth
            }
        }
        .accessibilityHidden(true)
    }
}

/// Small caps label with its value beneath, as printed on tickets and passes: "SEAT / 14A".
struct TicketField: View {
    let label: String
    let value: String
    let ink: Color
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(label)
                .typeToken(.ticketLabel)
                .foregroundStyle(ink.opacity(0.8))
            Text(value)
                .font(.system(.callout, design: .monospaced, weight: .semibold))
                .foregroundStyle(Palette.textPrimary.color)
        }
    }
}

/// The relish scale's words, from one ā to five: how a keepsake says how something landed.
public enum Relish {
    public static let words = ["Forgettable", "Fine", "Good", "Lovely", "Unforgettable"]

    /// The word for a 1–5 rating (rounded, clamped), or `nil` when unrated.
    public static func word(for rating: Double?) -> String? {
        guard let rating, rating > 0 else { return nil }
        let step = min(max(Int(rating.rounded()), 1), words.count)
        return words[step - 1]
    }
}
