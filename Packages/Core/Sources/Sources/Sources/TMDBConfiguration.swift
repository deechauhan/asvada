import Foundation

/// TMDB credentials read from the app's Info.plist (`TMDBAPIKey`, filled from the
/// `TMDB_API_KEY` build setting). `nil` when no key was configured, so film search can
/// degrade gracefully instead of crashing.
public struct TMDBConfiguration: Sendable, Equatable {
    public static let infoPlistKey = "TMDBAPIKey"

    public let apiKey: String

    public init?(infoDictionary: [String: Any]?) {
        guard let raw = infoDictionary?[Self.infoPlistKey] as? String else { return nil }
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // An unset build setting leaves the key empty; an unexpanded one leaves "$(TMDB_API_KEY)".
        guard !key.isEmpty, !key.hasPrefix("$(") else { return nil }
        apiKey = key
    }

    /// Reads the configuration from a bundle (the main bundle by default).
    public static func fromBundle(_ bundle: Bundle = .main) -> TMDBConfiguration? {
        TMDBConfiguration(infoDictionary: bundle.infoDictionary)
    }
}
