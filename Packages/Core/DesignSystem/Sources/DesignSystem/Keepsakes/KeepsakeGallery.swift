import SwiftUI

/// Every keepsake template with sample content, in the Keepsakes paper world. Open it from the
/// design catalogue or launch the app with `-keepsakeGallery`.
public struct KeepsakeGallery: View {
    public init() {}

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
