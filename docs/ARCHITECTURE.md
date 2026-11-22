# Architecture

## Stack

| Layer | Choice |
|---|---|
| UI | SwiftUI, Swift 6 strict concurrency, `@Observable` view models |
| Persistence | SwiftData (SQLite store in the app container) |
| Backup | iCloud Drive ubiquity container: versioned export bundle (JSON + photos) |
| Sync (later) | SwiftData + CloudKit private database, or GRDB + `CKSyncEngine` if we need control (ADR) |
| Maps | MapKit; `MKMapView` via `UIViewRepresentable` where clustering is needed |
| Search | `MKLocalSearch` for places; TMDB for films; bundled datasets for countries/airlines |
| Geo | Bundled Natural Earth admin-0 GeoJSON; offline point-in-polygon for country lookup |
| Tests | Swift Testing for unit tests, XCUITest for key flows |
| CI | GitHub Actions on macOS runners: build + test on every PR |

## Modules (Swift packages inside one Xcode workspace)

```
AsvadaApp        — app target, navigation, composition root
Features/        — Timeline, QuickLog, Collections, EntryDetail, Map, Settings, Import
Core/Model       — SwiftData models + migrations (VersionedSchema)
Core/Storage     — ModelContainer setup, repositories, export/import (backup format)
Core/Geo         — country polygons, point-in-polygon, reverse-geocode helpers
Core/Sources     — PlaceSearch (MapKit), FilmSearch (TMDB), CountryCatalog, AirlineCatalog
Core/Ranking     — pairwise comparison ranking engine
Core/DesignSystem— colours, type, components
```

## Data model (CloudKit-compatible)

All attributes optional or defaulted; all relationships optional; no unique constraints
(dedupe in code by `externalRef`).

```swift
// Named ExperienceCollection to avoid clashing with Swift's `Collection` protocol.
@Model final class ExperienceCollection {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "star"
    var kind: CollectionKind = .custom      // cafes, restaurants, countries, cities, airlines, films, custom
    var ratingMode: RatingMode = .stars     // checklist, log, ranked, stars
    var defaultView: ViewMode = .list       // list, grid, ranked, progress, map
    var itemSource: ItemSource = .manual    // mapkit, tmdb, countryCatalog, airlineCatalog, manual
    var fieldSchemaJSON: Data? = nil        // custom field definitions
    var sortIndex: Int = 0
    @Relationship(deleteRule: .cascade, inverse: \Item.collection) var items: [Item]? = []
}

@Model final class Item {
    var id: UUID = UUID()
    var name: String = ""
    var externalRef: String? = nil          // "iso:JP", "iata:BA", "tmdb:12345", "mk:<id>"
    var latitude: Double? = nil
    var longitude: Double? = nil
    var countryCode: String? = nil
    var metadataJSON: Data? = nil           // poster path, address, flag, etc.
    var rankScore: Double? = nil            // for ranked collections
    var collection: ExperienceCollection? = nil
    @Relationship(deleteRule: .cascade, inverse: \Entry.item) var entries: [Entry]? = []
}

@Model final class Entry {
    var id: UUID = UUID()
    var date: Date = Date()
    var rating: Double? = nil               // stars / normalised score
    var notes: String = ""
    var extraJSON: Data? = nil              // values for custom fields
    var item: Item? = nil
    var trip: Trip? = nil
    @Relationship(deleteRule: .cascade, inverse: \Photo.entry) var photos: [Photo]? = []
    var tags: [Tag]? = []
    var people: [Person]? = []
}

@Model final class Photo {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var imageData: Data? = nil
    @Attribute(.externalStorage) var thumbnailData: Data? = nil
    var takenAt: Date? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var entry: Entry? = nil
}

@Model final class Trip { var id: UUID = UUID(); var name: String = ""; var start: Date? = nil; var end: Date? = nil
    @Relationship(inverse: \Entry.trip) var entries: [Entry]? = [] }
@Model final class Tag { var id: UUID = UUID(); var name: String = "" }
@Model final class Person { var id: UUID = UUID(); var name: String = "" }
```

## Ranking engine

Ranked collections use binary-insertion by pairwise comparison: a new item is compared against the
median of the current list, then the median of the remaining half, until placed (≈ log₂ n
questions). Stored as an ordered `rankScore` with gaps (e.g. 1000, 2000…) to allow inserts without
renumbering; periodic rebalance.

## Map collage

| Zoom | Layer |
|---|---|
| World / continent | Country polygons filled for visited countries (`MKMultiPolygon` overlays from bundled GeoJSON) |
| Country / region | Clustered annotations rendered as photo stacks with count badges (`MKClusterAnnotation`) |
| City / street | Individual photo pins tinted by collection colour |
| Export | `MKMapSnapshotter` + `ImageRenderer` → shareable poster |

## Storage, backup and sync

1. **M1–M2:** local SwiftData store only.
2. **M3:** Backup — versioned bundle (`manifest.json`, `data.json`, `photos/`) written to the app's
   iCloud Drive container on demand and on a schedule; restore with merge-by-id. Also exportable via Files.
3. **M3+:** Sync — evaluate (spike) SwiftData's CloudKit integration vs GRDB + `CKSyncEngine`.
   Known risks: toggling CloudKit at runtime requires rebuilding the `ModelContainer`; check
   `CKContainer.accountStatus` before enabling; never let account sign-out delete local data.

## Privacy & security

- No third-party analytics or ads SDKs. Privacy nutrition label: "Data not collected".
- TMDB key stored outside the repo (xcconfig not committed; CI secret).
- Optional app lock (Face ID) post-MVP.
