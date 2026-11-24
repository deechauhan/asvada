import Foundation
import Testing
@testable import Sources

/// A scripted network: records requests and answers from a closure.
final class FakeHTTP: HTTPDataSource, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    private let respond: @Sendable (URLRequest) throws -> (Data, Int)

    init(_ respond: @escaping @Sendable (URLRequest) throws -> (Data, Int)) {
        self.respond = respond
    }

    var requests: [URLRequest] {
        lock.withLock { recorded }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lock.withLock { recorded.append(request) }
        let (data, status) = try respond(request)
        let url = request.url ?? TMDBClient.apiBase
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
        return (data, response ?? URLResponse())
    }
}

private let searchJSON = Data("""
{"page":1,"results":[
 {"id":976893,"title":"Perfect Days","release_date":"2023-11-10","poster_path":"/perfect.jpg",
  "overview":"Hirayama cleans toilets in Tokyo."},
 {"id":42,"title":"Untitled","release_date":"","poster_path":null}
],"total_results":2}
""".utf8)

private func key(_ value: String) -> TMDBConfiguration? {
    TMDBConfiguration(infoDictionary: [TMDBConfiguration.infoPlistKey: value])
}

struct TMDBClientTests {
    @Test func searchDecodesFilmsWithYearAndPoster() async throws {
        let http = FakeHTTP { _ in (searchJSON, 200) }
        let films = try await TMDBClient(configuration: key("v3key"), http: http, language: "en-GB").searchFilms("perfect days")
        #expect(films.map(\.title) == ["Perfect Days", "Untitled"])
        #expect(films[0].year == 2023)
        #expect(films[0].externalRef == "tmdb:976893")
        #expect(films[1].year == nil)
        #expect(films[1].posterPath == nil)
    }

    @Test func aV3KeyGoesInTheQueryWithTheTitleAndLanguage() async throws {
        let http = FakeHTTP { _ in (searchJSON, 200) }
        _ = try await TMDBClient(configuration: key("v3key"), http: http, language: "en-GB").searchFilms("  Past Lives ")
        let url = try #require(http.requests.first?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(url.path() == "/3/search/movie")
        #expect(items.contains(URLQueryItem(name: "query", value: "Past Lives")))
        #expect(items.contains(URLQueryItem(name: "api_key", value: "v3key")))
        #expect(items.contains(URLQueryItem(name: "language", value: "en-GB")))
        #expect(items.contains(URLQueryItem(name: "include_adult", value: "false")))
        #expect(http.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func aV4ReadTokenIsSentAsABearerToken() async throws {
        let http = FakeHTTP { _ in (searchJSON, 200) }
        _ = try await TMDBClient(configuration: key("eyJhbGciOi.token"), http: http).searchFilms("Aftersun")
        let request = try #require(http.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer eyJhbGciOi.token")
        #expect(request.url?.query()?.contains("api_key") == false)
    }

    @Test func anEmptyQueryAsksNothing() async throws {
        let http = FakeHTTP { _ in (searchJSON, 200) }
        let films = try await TMDBClient(configuration: key("k"), http: http).searchFilms("   ")
        #expect(films.isEmpty)
        #expect(http.requests.isEmpty)
    }

    @Test func failuresAreExplainable() async {
        let offline = FakeHTTP { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: TMDBError.offline) {
            try await TMDBClient(configuration: key("k"), http: offline).searchFilms("x")
        }
        let rejected = FakeHTTP { _ in (Data(), 401) }
        await #expect(throws: TMDBError.unauthorized) {
            try await TMDBClient(configuration: key("k"), http: rejected).searchFilms("x")
        }
        let broken = FakeHTTP { _ in (Data("<html>".utf8), 200) }
        await #expect(throws: TMDBError.unreadable) {
            try await TMDBClient(configuration: key("k"), http: broken).searchFilms("x")
        }
        await #expect(throws: TMDBError.notConfigured) {
            try await TMDBClient(configuration: nil, http: broken).searchFilms("x")
        }
    }

    @Test func posterURLsUseTheImageHost() {
        #expect(TMDBClient.posterURL("/perfect.jpg").absoluteString == "https://image.tmdb.org/t/p/w342/perfect.jpg")
        #expect(TMDBClient.posterURL("perfect.jpg", size: "w185").absoluteString == "https://image.tmdb.org/t/p/w185/perfect.jpg")
    }
}

struct PosterCacheTests {
    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "posters-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    @Test func downloadsOnceThenServesFromDisk() async throws {
        let http = FakeHTTP { _ in (Data([1, 2, 3]), 200) }
        let cache = PosterCache(directory: tempDirectory(), http: http)
        #expect(await cache.cached("/perfect.jpg") == nil)
        let first = try await cache.poster(for: "/perfect.jpg")
        let second = try await cache.poster(for: "/perfect.jpg")
        #expect(first == Data([1, 2, 3]))
        #expect(second == first)
        #expect(http.requests.count == 1)
        #expect(http.requests.first?.url?.absoluteString == "https://image.tmdb.org/t/p/w342/perfect.jpg")
        #expect(await cache.cached("/perfect.jpg") == first)
    }

    @Test func offlineWithAStoredPosterStillServesIt() async throws {
        let directory = tempDirectory()
        let online = PosterCache(directory: directory, http: FakeHTTP { _ in (Data([9]), 200) })
        _ = try await online.poster(for: "/a.jpg")
        let offline = PosterCache(directory: directory, http: FakeHTTP { _ in throw URLError(.notConnectedToInternet) })
        let poster = try await offline.poster(for: "/a.jpg")
        #expect(poster == Data([9]))
        await #expect(throws: TMDBError.offline) {
            try await offline.poster(for: "/missing.jpg")
        }
    }

    @Test func storedFilenamesAreSafe() async {
        let cache = PosterCache(directory: URL(filePath: "/tmp/p"), http: FakeHTTP { _ in (Data(), 200) })
        let url = await cache.fileURL(for: "/../../etc/passwd")
        #expect(url.deletingLastPathComponent().path() == "/tmp/p/")
        #expect(!url.lastPathComponent.contains("/"))
    }

    @Test func removingForgetsThePoster() async throws {
        let cache = PosterCache(directory: tempDirectory(), http: FakeHTTP { _ in (Data([5]), 200) })
        _ = try await cache.poster(for: "/b.jpg")
        await cache.remove("/b.jpg")
        #expect(await cache.cached("/b.jpg") == nil)
    }
}
