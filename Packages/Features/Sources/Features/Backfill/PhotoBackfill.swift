import Foundation
import Observation
import Storage

/// Looks through the photo library for places you've been (#64): reads where and when each photo
/// was taken, a page at a time, and groups them into visits on the phone. It can be paused and
/// carries on from where it stopped.
@MainActor
@Observable
final class PhotoBackfill {
    enum Phase: Equatable {
        case idle
        case denied
        case scanning
        case paused
        case finished
    }

    private(set) var phase = Phase.idle
    /// How many photos have been looked at, and how many the library holds.
    private(set) var looked = 0
    private(set) var total = 0
    /// The visits found: filled in once the scan finishes.
    private(set) var visits: [VisitCluster] = []
    private(set) var access: PhotoAccess
    /// How many photos had a place and a date.
    private(set) var placed = 0

    private let source: any PhotoLibrarySource
    private let pageSize: Int
    private var nextIndex = 0
    private var sightings: [PhotoSighting] = []
    private var pauseRequested = false

    init(source: any PhotoLibrarySource = SystemPhotoLibrary(), pageSize: Int = 500) {
        self.source = source
        self.pageSize = pageSize
        access = source.access()
    }

    /// 0...1.
    var progress: Double {
        total > 0 ? min(Double(looked) / Double(total), 1) : 0
    }

    /// Asks for access if it hasn't been asked for, then scans (or carries on scanning) until the
    /// library has been read or `pause()` is called. Does nothing without access.
    func run() async {
        guard phase != .scanning else { return }
        if access == .notDetermined {
            access = await source.requestAccess()
        }
        guard access.canRead else {
            phase = .denied
            return
        }
        pauseRequested = false
        phase = .scanning
        while !pauseRequested {
            let before = nextIndex
            let page = await source.page(from: before, limit: pageSize)
            sightings += page.sightings
            placed = sightings.count
            nextIndex = page.next
            looked = min(page.next, page.total)
            total = page.total
            // Done at the end of the library; a page that didn't move on would loop for ever, so
            // it counts as the end too.
            if page.next >= page.total || page.next <= before {
                visits = VisitClusterer.clusters(from: sightings)
                phase = .finished
                return
            }
        }
        phase = .paused
    }

    /// Small pictures of some of a visit's photos, to show with its suggestion.
    func thumbnails(for visit: VisitCluster) async -> [Data] {
        await source.thumbnails(for: visit.sampleIDs)
    }

    /// Stops after the page being read; `run()` carries on from there.
    func pause() {
        pauseRequested = true
    }

    /// Forgets everything found so far, to scan again from the start.
    func reset() {
        phase = .idle
        looked = 0
        total = 0
        placed = 0
        nextIndex = 0
        sightings = []
        visits = []
        pauseRequested = false
    }
}
