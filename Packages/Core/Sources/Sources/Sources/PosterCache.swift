import Foundation

/// Film posters kept on the device, so the film log looks the same offline. Each poster is fetched
/// once (at TMDB's w342 size, which keepsakes and share cards use) and then served from disk.
///
/// Posters live in Application Support rather than Caches: the system may purge Caches, and a
/// poster that vanished while offline would leave a blank ticket stub.
public actor PosterCache {
    private let directory: URL
    private let http: HTTPDataSource
    private var inFlight: [String: Task<Data, Error>] = [:]

    /// - Parameters:
    ///   - directory: where posters are stored (created if missing).
    ///   - http: the transport (the shared `URLSession` by default).
    public init(directory: URL, http: HTTPDataSource = URLSessionDataSource()) {
        self.directory = directory
        self.http = http
    }

    /// The app's poster folder: Application Support/Posters.
    public static func defaultDirectory() throws -> URL {
        try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "Posters", directoryHint: .isDirectory)
    }

    /// The poster for a TMDB `posterPath`, from disk if it's there, otherwise downloaded and kept.
    /// Concurrent requests for the same poster share one download.
    public func poster(for posterPath: String) async throws -> Data {
        if let cached = cached(posterPath) {
            return cached
        }
        if let running = inFlight[posterPath] {
            return try await running.value
        }
        let task = Task { try await download(posterPath) }
        inFlight[posterPath] = task
        defer { inFlight[posterPath] = nil }
        return try await task.value
    }

    /// The poster if it's already on disk; never touches the network.
    public func cached(_ posterPath: String) -> Data? {
        try? Data(contentsOf: fileURL(for: posterPath))
    }

    /// Deletes a stored poster (e.g. when its film is deleted).
    public func remove(_ posterPath: String) {
        try? FileManager.default.removeItem(at: fileURL(for: posterPath))
    }

    func fileURL(for posterPath: String) -> URL {
        // TMDB paths are "/abc123.jpg"; keep only safe filename characters.
        let name = posterPath.filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" || $0 == "-" }
        return directory.appending(path: name.isEmpty ? "poster" : name)
    }

    private func download(_ posterPath: String) async throws -> Data {
        let request = URLRequest(url: TMDBClient.posterURL(posterPath), timeoutInterval: 20)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await http.data(for: request)
        } catch {
            throw TMDBError.offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200 ..< 300).contains(status), !data.isEmpty else { throw TMDBError.http(status) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL(for: posterPath), options: .atomic)
        return data
    }
}
