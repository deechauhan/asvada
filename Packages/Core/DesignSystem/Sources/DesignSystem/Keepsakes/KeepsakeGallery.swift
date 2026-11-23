import SwiftUI

/// Every keepsake template with sample content, in the Keepsakes paper world. Open it from the
/// design catalogue or launch the app with `-keepsakeGallery`.
public struct KeepsakeGallery: View {
    @State private var isSealed = false

    public init() {}

    private static let topCafes = [
        TopMenuCard.Course(name: "Prufrock Coffee", detail: "Clerkenwell"),
        TopMenuCard.Course(name: "Monmouth", detail: "Borough"),
        TopMenuCard.Course(name: "Kaffeine", detail: "Fitzrovia"),
        TopMenuCard.Course(name: "Workshop", detail: "Marylebone"),
        TopMenuCard.Course(name: "Origin", detail: "Shoreditch"),
    ]

    private static var sampleStamps: [StampEntry] {
        [
            StampEntry(country: "Japan", code: "JP", date: date("2025-04-03")),
            StampEntry(country: "Portugal", code: "PT", date: date("2024-09-14")),
            StampEntry(country: "India", code: "IN", date: date("2023-12-22")),
            StampEntry(country: "Iceland", code: "IS", date: date("2022-06-06")),
            StampEntry(country: "Peru", code: "PE"),
            StampEntry(country: "Kenya", code: "KE", date: date("2021-02-11")),
        ]
    }

    private static func date(_ string: String) -> Date {
        (try? Date(string, strategy: .iso8601.year().month().day())) ?? .now
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    Text("Passport")
                        .typeToken(.masthead)
                        .foregroundStyle(Palette.textPrimary.color)
                    KeepsakeCard(id: "passport-page") {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 110), spacing: Spacing.large)],
                            spacing: Spacing.large,
                        ) {
                            PassportStamp(country: "Japan", code: "JP", date: Self.date("2025-04-03"))
                            PassportStamp(country: "Portugal", code: "PT", date: Self.date("2024-09-14"))
                            PassportStamp(country: "India", code: "IN", date: Self.date("2023-12-22"))
                            PassportStamp(country: "Iceland", code: "IS", date: Self.date("2022-06-06"))
                            PassportStamp(country: "Peru", code: "PE")
                            PassportStamp(country: "Kenya", code: "KE", date: Self.date("2021-02-11"))
                        }
                        .padding(Spacing.large)
                    }
                    Text("Receipts & menus")
                        .typeToken(.masthead)
                        .foregroundStyle(Palette.textPrimary.color)
                    Receipt(
                        name: "Prufrock Coffee",
                        district: "Clerkenwell",
                        date: Self.date("2026-11-23"),
                        visits: 4,
                        rank: 2,
                    )
                    .rotationEffect(.degrees(Tilt.degrees(for: "prufrock")))
                    .frame(maxWidth: .infinity)
                    MenuCard(
                        name: "Dishoom",
                        cuisine: "Bombay café",
                        dishes: ["House black daal", "Bacon naan roll", "Chai"],
                        date: Self.date("2026-10-02"),
                        rank: 1,
                    )
                    .rotationEffect(.degrees(Tilt.degrees(for: "dishoom")))
                    .frame(maxWidth: .infinity)
                    Text("Tickets & passes")
                        .typeToken(.masthead)
                        .foregroundStyle(Palette.textPrimary.color)
                    TicketStub(title: "Perfect Days", year: 2023, date: Self.date("2026-03-08"), seat: "F12", relish: "Lovely")
                        .rotationEffect(.degrees(Tilt.degrees(for: "perfect-days")))
                    TicketStub(title: "Past Lives", year: 2023, date: Self.date("2026-06-21"), rewatches: 3)
                        .rotationEffect(.degrees(Tilt.degrees(for: "past-lives")))
                    BoardingPass(
                        airline: "British Airways",
                        code: "BA",
                        from: "LHR",
                        destination: "HND",
                        seat: "14A",
                        date: Self.date("2025-04-02"),
                        flights: 3,
                        barcodeSeed: "ba-sample",
                    )
                    .rotationEffect(.degrees(Tilt.degrees(for: "ba-sample")))
                    Text("Postcards")
                        .typeToken(.masthead)
                        .foregroundStyle(Palette.textPrimary.color)
                    Postcard(city: "Lisbon", country: "Portugal", date: Self.date("2024-09-14"), relish: "Unforgettable")
                        .rotationEffect(.degrees(Tilt.degrees(for: "lisbon")))
                    Text("Share cards")
                        .typeToken(.masthead)
                        .foregroundStyle(Palette.textPrimary.color)
                    TopMenuCard(collection: "Cafés", courses: Self.topCafes)
                        .frame(maxWidth: .infinity)
                    PassportSpreadCard(stamps: Self.sampleStamps)
                        .frame(maxWidth: .infinity)
                    KeepsakeShareCard(eyebrow: "Films", title: "Perfect Days") {
                        TicketStub(title: "Perfect Days", year: 2023, date: Self.date("2026-03-08"), relish: "Lovely")
                    }
                    .frame(maxWidth: .infinity)
                    Text("Tags")
                        .typeToken(.masthead)
                        .foregroundStyle(Palette.textPrimary.color)
                    LuggageTag(
                        collection: "Concerts",
                        title: "Radiohead, O2",
                        detail: "12·07·26 · with Asha",
                        icon: "music.note",
                        ink: CollectionAccent.city.token,
                    )
                    .rotationEffect(.degrees(Tilt.degrees(for: "radiohead")))
                    LuggageTag(
                        collection: "Hikes",
                        title: "Scafell Pike",
                        detail: "03·08·26",
                        icon: "figure.hiking",
                        ink: CollectionAccent.country.token,
                    )
                    .rotationEffect(.degrees(Tilt.degrees(for: "scafell")))
                    Text("Savour")
                        .typeToken(.masthead)
                        .foregroundStyle(Palette.textPrimary.color)
                    LuggageTag(
                        collection: "Cafés",
                        title: "Prufrock Coffee",
                        detail: "Clerkenwell · today",
                        icon: "cup.and.saucer.fill",
                        ink: CollectionAccent.cafe.token,
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if isSealed {
                            WaxSeal().padding(Spacing.small)
                        }
                    }
                    VStack(spacing: Spacing.small) {
                        SealButton { isSealed = true }
                        Text(isSealed ? "Savoured" : "Hold to savour")
                            .typeToken(.voice)
                            .foregroundStyle(Palette.textSecondary.color)
                        if isSealed {
                            Button("Unseal") { isSealed = false }
                                .typeToken(.callout)
                                .tint(Palette.brand.color)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(Spacing.large)
            }
            .background(Palette.background.color)
            .navigationTitle("Keepsakes")
        }
    }
}

#Preview("Light") {
    KeepsakeGallery()
}

#Preview("Dark") {
    KeepsakeGallery().preferredColorScheme(.dark)
}
