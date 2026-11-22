# Architecture decision records

One file per decision: `NNNN-short-title.md`, using [`0000-template.md`](0000-template.md).
Status moves Proposed → Accepted → (Superseded by NNNN).

| ADR | Title | Status | Issue |
|---|---|---|---|
| [0001](0001-minimum-ios-version.md) | Minimum iOS version (iOS 26+) | Accepted | #7 |
| 0002 | Sync strategy: SwiftData + CloudKit vs GRDB + CKSyncEngine | Proposed | Spike in E10 |
| 0003 | Map clustering: MKMapView vs ClusterMap | Proposed | Spike in E9 |

Decisions already settled during planning (see `CLAUDE.md`): native SwiftUI, local-first SwiftData,
CloudKit-compatible schema from day one, MapKit for places, bundled Natural Earth polygons, TMDB for
films, photos stored in-app.
