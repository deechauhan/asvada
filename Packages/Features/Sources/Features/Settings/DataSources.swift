import Foundation

/// Where Asvada's data comes from and what, if anything, it sends there. Shown in About, and the
/// privacy seal is written to match it: keep the two in step.
struct DataSource: Identifiable, Equatable {
    let id: String
    let name: String
    /// What it gives Asvada.
    let provides: String
    /// What leaves the phone to reach it, or that nothing does.
    let sends: String
    /// The licence or terms it's used under.
    let licence: String
    let link: URL

    /// Whether anything leaves the phone for it.
    var isOnline: Bool {
        sends != Self.nothingSent
    }

    static let nothingSent = "Nothing. It's bundled in the app."

    /// TMDB's terms ask for exactly this line wherever their data is credited.
    static let tmdbNotice = "This product uses the TMDB API but is not endorsed or certified by TMDB."

    static let all: [DataSource] = [
        DataSource(
            id: "apple-maps",
            name: "Apple Maps",
            provides: "Place search for cafés, restaurants and cities, “near you” guesses, and map tiles.",
            sends: """
            What you type in a place search. Where you are, roughly, only if you allow location \
            and ask for guesses from it. Map tiles for the area on screen.
            """,
            licence: "Apple Maps terms. Map data © Apple and its data providers.",
            link: URL(string: "https://www.apple.com/legal/internet-services/maps/")!,
        ),
        DataSource(
            id: "tmdb",
            name: "TMDB (The Movie Database)",
            provides: "Film search, posters and what's showing now.",
            sends: "The film title you type, and your country to find what's showing near you.",
            licence: tmdbNotice,
            link: URL(string: "https://www.themoviedb.org")!,
        ),
        DataSource(
            id: "natural-earth",
            name: "Natural Earth",
            provides: "Country shapes for the ink map and stamping countries.",
            sends: nothingSent,
            licence: "Public domain.",
            link: URL(string: "https://www.naturalearthdata.com")!,
        ),
        DataSource(
            id: "openflights",
            name: "OpenFlights",
            provides: "Airline names and codes.",
            sends: nothingSent,
            licence: "© OpenFlights contributors, under the Open Database License (ODbL).",
            link: URL(string: "https://openflights.org/data")!,
        ),
        DataSource(
            id: "icloud",
            name: "Your iCloud",
            provides: "Backups of your keepsakes, once backup arrives.",
            sends: "Nothing yet. Backups will go to your own iCloud Drive, only if you turn them on.",
            licence: "Your Apple Account. Asvada has no server of its own.",
            link: URL(string: "https://www.apple.com/icloud/")!,
        ),
    ]
}
