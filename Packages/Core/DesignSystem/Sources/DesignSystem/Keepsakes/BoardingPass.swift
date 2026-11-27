import SwiftUI

/// An airline keepsake: a two-part boarding pass. The big IATA code, an optional FROM → TO, seat
/// and date on the main part; the flight count and a decorative barcode (seeded from the entry)
/// on the stub.
public struct BoardingPass: KeepsakeTemplate {
    let airline: String
    let code: String
    let from: String?
    let destination: String?
    let seat: String?
    let date: Date?
    let flights: Int
    let barcodeSeed: String
    let ink: ColorToken

    /// - Parameters:
    ///   - airline: e.g. "British Airways".
    ///   - code: IATA code, e.g. "BA".
    ///   - from: departure airport, e.g. "LHR".
    ///   - destination: arrival airport, e.g. "HND".
    ///   - seat: e.g. "14A".
    ///   - date: the latest flight.
    ///   - flights: how many times flown.
    ///   - barcodeSeed: stable id (e.g. the entry's UUID) that fixes the barcode.
    ///   - ink: the collection's accent (Airlines is Sky).
    public init(
        airline: String,
        code: String,
        from: String? = nil,
        destination: String? = nil,
        seat: String? = nil,
        date: Date? = nil,
        flights: Int = 1,
        barcodeSeed: String? = nil,
        ink: ColorToken = CollectionAccent.airline.token,
    ) {
        self.airline = airline
        self.code = code.uppercased()
        self.from = from?.uppercased()
        self.destination = destination?.uppercased()
        self.seat = seat
        self.date = date
        self.flights = flights
        self.barcodeSeed = barcodeSeed ?? airline
        self.ink = ink
    }

    /// Width of the stub, right of the tear.
    static let stubWidth: CGFloat = 92

    private var route: String? {
        guard let from, let destination else { return nil }
        return "\(from) → \(destination)"
    }

    public var accessibilitySummary: String {
        var parts = ["Boarding pass", airline]
        if let from, let destination {
            parts.append("\(from) to \(destination)")
        }
        parts.append(flights == 1 ? "1 flight" : "\(flights) flights")
        return parts.joined(separator: ", ")
    }

    public var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "airplane")
                        .accessibilityHidden(true)
                    Text("Boarding pass")
                        .typeToken(.ticketLabel)
                }
                .foregroundStyle(ink.color)
                HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                    Text(code)
                        .font(.system(size: 40, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Palette.textPrimary.color)
                        // Split-flap: a new code rolls in letter by letter (#121).
                        .contentTransition(.numericText())
                        .animation(.snappy, value: code)
                    Text(airline)
                        .font(.system(.callout, design: .serif, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary.color)
                        .lineLimit(2)
                }
                if let route {
                    Text(route)
                        .font(.system(.title3, design: .monospaced, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary.color)
                }
                HStack(spacing: Spacing.large) {
                    if let date {
                        TicketField(label: "Date", value: KeepsakeDate.short(date), ink: ink.color)
                    }
                    if let seat {
                        TicketField(label: "Seat", value: seat, ink: ink.color)
                    }
                }
            }
            .padding(Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            Perforation(ink: ink.color)
            VStack(spacing: Spacing.small) {
                Text("Flown")
                    .typeToken(.ticketLabel)
                    .foregroundStyle(ink.color)
                Text("×\(flights)")
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                    .foregroundStyle(Palette.brand.color)
                Barcode(seed: barcodeSeed, ink: Palette.textPrimary.color)
                    .frame(width: 64, height: 30)
            }
            .padding(.vertical, Spacing.large)
            .frame(width: Self.stubWidth)
        }
        .frame(maxWidth: 360)
        .background(KeepsakePaper(seed: barcodeSeed))
        .overlay(alignment: .leading) {
            Rectangle().fill(ink.color).frame(width: 5).accessibilityHidden(true)
        }
        .clipShape(NotchedTicket(tear: .fromTrailing(Self.stubWidth)))
        .shadow(color: Palette.textPrimary.color.opacity(0.12), radius: 8, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }
}
