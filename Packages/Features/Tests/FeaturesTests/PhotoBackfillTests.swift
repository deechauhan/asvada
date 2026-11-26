import Foundation
import Geo
import Storage
import Testing
@testable import Features

/// A photo library made of a list, read a page at a time like the real one.
@MainActor
private final class FakeLibrary: PhotoLibrarySource {
    var current: PhotoAccess
    let granted: PhotoAccess
    let sightings: [PhotoSighting]
    /// Photos with no place in the library, on top of `sightings`.
    let unplaced: Int
    private(set) var asked = 0
    private(set) var pagesRead = 0
    /// Called as each page is read, with how many have been read so far.
    var onPage: ((Int) -> Void)?

    init(access: PhotoAccess = .full, granted: PhotoAccess = .full, sightings: [PhotoSighting], unplaced: Int = 0) {
        current = access
        self.granted = granted
        self.sightings = sightings
        self.unplaced = unplaced
    }

    func access() -> PhotoAccess {
        current
    }

    func requestAccess() async -> PhotoAccess {
        asked += 1
        current = granted
        return granted
    }

    func page(from index: Int, limit: Int) async -> PhotoPage {
        pagesRead += 1
        let total = sightings.count + unplaced
        let end = min(index + limit, total)
        let slice = index < sightings.count ? Array(sightings[index ..< min(end, sightings.count)]) : []
        onPage?(pagesRead)
        return PhotoPage(sightings: slice, next: end, total: total)
    }
}

@MainActor
struct PhotoBackfillTests {
    private let lisbon = GeoPoint(longitude: -9.14, latitude: 38.72)
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func holiday(_ count: Int) -> [PhotoSighting] {
        (0 ..< count).map { index in
            PhotoSighting(id: "p\(index)", date: start.addingTimeInterval(Double(index) * 3600), point: lisbon)
        }
    }

    @Test func aScanReadsTheWholeLibraryAndFindsTheVisit() async {
        let library = FakeLibrary(sightings: holiday(25), unplaced: 5)
        let backfill = PhotoBackfill(source: library, pageSize: 10)
        await backfill.run()
        #expect(backfill.phase == .finished)
        #expect(backfill.looked == 30)
        #expect(backfill.total == 30)
        #expect(backfill.placed == 25)
        #expect(backfill.progress == 1)
        #expect(backfill.visits.count == 1)
        #expect(backfill.visits.first?.countryCode == "PT")
        #expect(library.pagesRead == 3)
    }

    @Test func accessIsAskedForWhenItHasntBeenAndASecondRunDoesntAskAgain() async {
        let library = FakeLibrary(access: .notDetermined, sightings: holiday(5))
        let backfill = PhotoBackfill(source: library, pageSize: 10)
        #expect(backfill.access == .notDetermined)
        await backfill.run()
        #expect(library.asked == 1)
        #expect(backfill.phase == .finished)
        backfill.reset()
        await backfill.run()
        #expect(library.asked == 1)
    }

    @Test func refusedAccessScansNothing() async {
        let library = FakeLibrary(access: .notDetermined, granted: .denied, sightings: holiday(5))
        let backfill = PhotoBackfill(source: library)
        await backfill.run()
        #expect(backfill.phase == .denied)
        #expect(library.pagesRead == 0)
        #expect(backfill.visits.isEmpty)
    }

    @Test func limitedAccessScansWhatWasShared() async {
        let library = FakeLibrary(access: .limited, sightings: holiday(4))
        let backfill = PhotoBackfill(source: library)
        await backfill.run()
        #expect(backfill.phase == .finished)
        #expect(backfill.visits.count == 1)
    }

    @Test func aScanCanBePausedAndCarriesOnWhereItStopped() async {
        let library = FakeLibrary(sightings: holiday(40))
        let backfill = PhotoBackfill(source: library, pageSize: 10)
        library.onPage = { pages in
            if pages == 2 {
                backfill.pause()
            }
        }
        await backfill.run()
        #expect(backfill.phase == .paused)
        #expect(backfill.looked == 20)
        #expect(backfill.visits.isEmpty)
        #expect(library.pagesRead == 2)

        library.onPage = nil
        await backfill.run()
        #expect(backfill.phase == .finished)
        // Carried on from photo 20: two more pages, nothing read twice.
        #expect(library.pagesRead == 4)
        #expect(backfill.placed == 40)
        #expect(backfill.visits.count == 1)
        #expect(backfill.visits.first?.photoCount == 40)
    }

    @Test func anEmptyLibraryFinishesWithNoVisits() async {
        let backfill = PhotoBackfill(source: FakeLibrary(sightings: []), pageSize: 10)
        await backfill.run()
        #expect(backfill.phase == .finished)
        #expect(backfill.visits.isEmpty)
        #expect(backfill.progress == 0)
    }

    @Test func resettingStartsOver() async {
        let library = FakeLibrary(sightings: holiday(8))
        let backfill = PhotoBackfill(source: library, pageSize: 10)
        await backfill.run()
        backfill.reset()
        #expect(backfill.phase == .idle)
        #expect(backfill.looked == 0)
        #expect(backfill.visits.isEmpty)
    }
}

struct BackfillTextTests {
    @Test func progressReadsInWords() {
        #expect(BackfillText.progress(looked: 0, total: 0) == "Getting ready…")
        #expect(BackfillText.progress(looked: 1200, total: 8400).hasPrefix("Looked at "))
        #expect(BackfillText.progress(looked: 1200, total: 8400).hasSuffix("photos."))
    }

    @Test func theSummaryCountsVisits() {
        #expect(BackfillText.summary(photos: 10, placed: 4, visits: 0).hasSuffix("No visits found."))
        #expect(BackfillText.summary(photos: 10, placed: 4, visits: 1).hasSuffix("Found 1 visit."))
        #expect(BackfillText.summary(photos: 10, placed: 4, visits: 6).hasSuffix("Found 6 visits."))
    }

    @Test func photosAreSingularOrPlural() {
        #expect(BackfillText.photos(1) == "1 photo")
        #expect(BackfillText.photos(30) == "30 photos")
    }
}
