import Foundation

/// Anything that can perform an HTTP request: `URLSession` in the app, a fake in tests.
public protocol HTTPDataSource: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// The real network, through a `URLSession`.
public struct URLSessionDataSource: HTTPDataSource {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

/// A film as TMDB's search returns it.
public struct TMDBFilm: Sendable, Hashable, Identifiable, Decodable {
    public let id: Int
    public let title: String
    /// "2023-06-02", or empty when TMDB doesn't know.
    public let releaseDate: String?
    /// e.g. "/abc123.jpg"; nil when the film has no poster.
    public let posterPath: String?
    public let overview: String?

    /// The year it came out, if known.
    public var year: Int? {
        guard let releaseDate, releaseDate.count >= 4 else { return nil }
        return Int(releaseDate.prefix(4))
    }

    /// How an item refers to this film: "tmdb:976893".
    public var externalRef: String {
        "tmdb:\(id)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case overview
    }
}

/// What can go wrong talking to TMDB, in terms the UI can explain.
public enum TMDBError: Error, Equatable, Sendable {
    /// No API key was configured at build time.
    case notConfigured
    /// The device is offline (or the request couldn't reach TMDB).
    case offline
    /// TMDB rejected the key (401).
    case unauthorized
    /// Any other HTTP status.
    case http(Int)
    /// The response wasn't the JSON we expected.
    case unreadable
}

/// Searches TMDB, the app's only online dependency. Read-only, no account: only the film title
/// typed by the user leaves the phone. Works with either kind of TMDB credential: a v4 read
/// access token (sent as a bearer token) or a v3 API key (sent as `api_key`).
public struct TMDBClient: Sendable {
    public static let apiBase = URL(string: "https://api.themoviedb.org/3/")!
    public static let imageBase = URL(string: "https://image.tmdb.org/t/p/")!

    private let configuration: TMDBConfiguration?
    private let http: HTTPDataSource
    private let language: String

    /// - Parameters:
    ///   - configuration: the key, or nil when none was configured (every call then throws
    ///     `.notConfigured`).
    ///   - http: the transport (the shared `URLSession` by default).
    ///   - language: BCP 47 language for titles, e.g. "en-GB" (the device's by default).
    public init(
        configuration: TMDBConfiguration?,
        http: HTTPDataSource = URLSessionDataSource(),
        language: String = Locale.current.identifier(.bcp47),
    ) {
        self.configuration = configuration
        self.http = http
        self.language = language
    }

    /// Films whose title matches `query`, best first. An empty query returns none without a request.
    public func searchFilms(_ query: String) async throws -> [TMDBFilm] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let request = try makeRequest(path: "search/movie", query: [
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "language", value: language),
        ])
        let data = try await send(request)
        do {
            return try JSONDecoder().decode(SearchPage.self, from: data).results
        } catch {
            throw TMDBError.unreadable
        }
    }

    /// Films in cinemas now, most popular first: the print head's "now showing" guesses. Sends
    /// only the language and region, nothing about the user.
    public func nowShowing(region: String? = Locale.current.region?.identifier) async throws -> [TMDBFilm] {
        var query = [URLQueryItem(name: "language", value: language)]
        if let region {
            query.append(URLQueryItem(name: "region", value: region))
        }
        let request = try makeRequest(path: "movie/now_playing", query: query)
        let data = try await send(request)
        do {
            return try JSONDecoder().decode(SearchPage.self, from: data).results
        } catch {
            throw TMDBError.unreadable
        }
    }

    /// The URL of a poster at a TMDB size ("w185" for thumbnails, "w342" for keepsakes).
    public static func posterURL(_ path: String, size: String = "w342") -> URL {
        imageBase.appending(path: size).appending(path: path.hasPrefix("/") ? String(path.dropFirst()) : path)
    }

    func makeRequest(path: String, query: [URLQueryItem]) throws -> URLRequest {
        guard let configuration else { throw TMDBError.notConfigured }
        var items = query
        let isReadToken = configuration.apiKey.hasPrefix("eyJ") // v4 tokens are JWTs
        if !isReadToken {
            items.append(URLQueryItem(name: "api_key", value: configuration.apiKey))
        }
        var components = URLComponents(url: Self.apiBase.appending(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = items
        guard let url = components?.url else { throw TMDBError.unreadable }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if isReadToken {
            request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await http.data(for: request)
        } catch {
            throw TMDBError.offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200 ..< 300: return data
        case 401: throw TMDBError.unauthorized
        default: throw TMDBError.http(status)
        }
    }
}

private struct SearchPage: Decodable {
    let results: [TMDBFilm]
}
