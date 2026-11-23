# Roadmap

Generated from `backlog/backlog.yaml` by `scripts/gen_roadmap.py`. Edit the backlog and regenerate rather than editing this file.

Capacity assumption: **~14 points per two-week sprint** (side-project pace). Re-plan at each sprint review using actual velocity.

## Milestones (releases)

| Milestone | Target date | Scope |
|---|---|---|
| **M0 · Foundations** | 2027-01-03 | Repo, CI, Xcode workspace, design tokens, app shell and the data model. |
| **M1 · Log & Rank (MVP core)** | 2027-05-23 | Collections, item sources, quick-log, entries, rating modes incl. pairwise ranking, timeline and collection views. |
| **M2 · Map Collage** | 2027-06-20 | Map tab with country fill, clustered photo stacks and pins. |
| **M3 · Backup & Sync** | 2027-08-01 | iCloud Drive backup/restore, Files export, optional CloudKit sync. |
| **M4 · Look Back** | 2027-09-12 | Photo-library backfill, trips, stats, on-this-day, year in review, poster export. |
| **M5 · v1.0 Launch** | 2027-10-10 | Quality pass, accessibility, TestFlight and App Store release. |

## Epics

| Epic | Milestone | Points |
|---|---|---|
| E1 · Project setup & tooling | M0 | 13 |
| E2 · Design system & app shell | M0 | 7 |
| E3 · Data model & persistence | M0 | 13 |
| E4 · Collections | M1 | 15 |
| E15 · Keepsakes design language | M1 | 41 |
| E5 · Item sources — search and catalogs | M1 | 20 |
| E6 · Quick-log & entries | M1 | 23 |
| E7 · Rating modes & ranking engine | M1 | 18 |
| E8 · Timeline & browsing | M1 | 13 |
| E9 · Map collage | M2 | 23 |
| E10 · Backup, restore & sync | M3 | 34 |
| E11 · Photo backfill & trips | M4 | 18 |
| E12 · Look back — stats, on this day, year in review | M4 | 18 |
| E13 · Quality — testing, accessibility, performance, privacy | M5 | 16 |
| E14 · Release v1.0 | M5 | 8 |

## Sprint plan

### Sprint 0 · 23 Nov 2026 – 06 Dec 2026 · 13 pts

- [M0/E1] Create Xcode project and modular workspace — task, 3 pts, P0
- [M0/E1] Set up GitHub Actions CI (build + test on PRs) — task, 3 pts, P0
- [M0/E1] Add SwiftLint and SwiftFormat — task, 2 pts, P1
- [M0/E1] Secrets handling for the TMDB API key — task, 1 pt, P0
- [M0/E1] Protect main: branch rules and merge settings — task, 1 pt, P1
- [M0/E1] Spike: confirm minimum iOS version (ADR-0001) — spike, 2 pts, P0
- [M0/E1] Confirm name availability: App Store, domain, trademark — task, 1 pt, P1

### Sprint 1 · 07 Dec 2026 – 20 Dec 2026 · 14 pts

- [M0/E2] Design tokens: colour, type, spacing, light & dark — story, 3 pts, P0
- [M0/E2] App shell: tabs and global add button — story, 3 pts, P0
- [M0/E3] Define SwiftData models (CloudKit-compatible) — story, 5 pts, P0
- [M0/E3] Versioned schema and migration scaffold — task, 3 pts, P0

### Sprint 2 · 21 Dec 2026 – 03 Jan 2027 · 6 pts

- [M0/E2] App icon, launch screen and About screen — task, 1 pt, P2
- [M0/E3] Repository layer and in-memory container for tests/previews — task, 3 pts, P0
- [M0/E3] Seed built-in collections on first launch — story, 2 pts, P0

### Sprint 3 · 04 Jan 2027 – 17 Jan 2027 · 10 pts

- [M1/E4] Collections screen: list, reorder, hide — story, 3 pts, P0
- [M1/E4] Create a custom collection — story, 5 pts, P0
- [M1/E4] Edit and delete a collection safely — story, 2 pts, P1

### Sprint 4 · 18 Jan 2027 – 31 Jan 2027 · 13 pts

- [M1/E15] Design tokens v2: Aubergine & Saffron — task, 2 pts, P0
- [M1/E15] App icon v2 and Colophon About — task, 1 pt, P1
- [M1/E15] Keepsake kit I: base card, paper material, stamp and luggage-tag templates — story, 5 pts, P0
- [M1/E15] ā Seal: hold to savour — story, 3 pts, P0
- [M1/E15] Shell v2: Journal, Collections, Atlas and the savour accessory — story, 2 pts, P0

### Sprint 5 · 01 Feb 2027 – 14 Feb 2027 · 13 pts

- [M1/E15] Collections cabinet — story, 3 pts, P0
- [M1/E15] Keepsake kit II: receipt, menu card, ticket stub, boarding pass, postcard — story, 5 pts, P0
- [M1/E15] Share cards: keepsake, passport spread, top-5 menu — story, 3 pts, P1
- [M1/E15] Motion and haptics kit with Reduce Motion fallbacks — task, 2 pts, P0

### Sprint 6 · 15 Feb 2027 – 28 Feb 2027 · 16 pts

- [M1/E15] Ink world map (offline Canvas renderer of bundled polygons) — story, 3 pts, P0
- [M1/E15] Onboarding: stamp your passport — story, 5 pts, P0
- [M1/E5] Place search with MapKit (cafés, restaurants, cities) — story, 5 pts, P0
- [M1/E5] Bundled country catalog and polygons — task, 3 pts, P0

### Sprint 7 · 01 Mar 2027 – 14 Mar 2027 · 12 pts

- [M1/E5] Bundled airline catalog — task, 2 pts, P0
- [M1/E5] Manual item creation for any collection — story, 2 pts, P0
- [M1/E5] Film search with TMDB and poster caching — story, 5 pts, P0
- [M1/E5] Offline country lookup from coordinates — story, 3 pts, P0

### Sprint 8 · 15 Mar 2027 – 28 Mar 2027 · 13 pts

- [M1/E6] Quick-log flow (under 15 seconds) — story, 8 pts, P0
- [M1/E6] Entry details: date, notes, companions, tags — story, 5 pts, P0

### Sprint 9 · 29 Mar 2027 – 11 Apr 2027 · 13 pts

- [M1/E6] Attach photos to an entry — story, 5 pts, P0
- [M1/E6] Item detail: all entries and stats for one thing — story, 3 pts, P1
- [M1/E6] Edit and delete entries with undo — story, 2 pts, P1
- [M1/E7] Rating mode: stars — story, 3 pts, P0

### Sprint 10 · 12 Apr 2027 – 25 Apr 2027 · 10 pts

- [M1/E7] Rating mode: checklist with completion progress — story, 3 pts, P0
- [M1/E7] Rating mode: log (repeat entries) — story, 2 pts, P0
- [M1/E7] Ranking engine: pairwise binary insertion — task, 5 pts, P0

### Sprint 11 · 26 Apr 2027 – 09 May 2027 · 12 pts

- [M1/E15] Duel polish: stamped result and list re-flow — story, 2 pts, P1
- [M1/E7] Rating mode: ranked via 'which was better?' — story, 5 pts, P0
- [M1/E8] Timeline home grouped by month — story, 5 pts, P0

### Sprint 12 · 10 May 2027 – 23 May 2027 · 12 pts

- [M1/E15] Spike: Atlas styling — muted map, ink overlays, snapshot pins — spike, 2 pts, P0
- [M1/E8] Collection views: list, poster grid, ranked, progress — story, 5 pts, P0
- [M1/E8] Search across everything — story, 3 pts, P1
- [M2/E9] Spike: clustering approach — MKMapView vs ClusterMap (ADR-0003) — spike, 2 pts, P0

### Sprint 13 · 24 May 2027 – 06 Jun 2027 · 13 pts

- [M2/E9] Map: fill visited countries — story, 5 pts, P0
- [M2/E9] Map: clustered photo stacks with counts — story, 8 pts, P0

### Sprint 14 · 07 Jun 2027 – 20 Jun 2027 · 8 pts

- [M2/E9] Map: individual pins tinted by collection — story, 3 pts, P0
- [M2/E9] Map performance test with 5,000 entries — task, 2 pts, P1
- [M3/E10] Spike: sync strategy — SwiftData+CloudKit vs GRDB+CKSyncEngine (ADR-0002) — spike, 3 pts, P0

### Sprint 15 · 21 Jun 2027 – 04 Jul 2027 · 10 pts

- [M3/E10] Backup bundle format v1 — task, 5 pts, P0
- [M3/E10] Back up to iCloud Drive (manual and scheduled) — story, 5 pts, P0

### Sprint 16 · 05 Jul 2027 – 18 Jul 2027 · 10 pts

- [M3/E10] Restore from backup with merge — story, 5 pts, P0
- [M3/E10] Export and import via the Files app — story, 2 pts, P1
- [M3/E10] Settings: privacy info, data export and delete all data — story, 3 pts, P1

### Sprint 17 · 19 Jul 2027 – 01 Aug 2027 · 11 pts

- [M3/E10] Optional CloudKit sync (feature flag) — story, 8 pts, P1
- [M3/E10] Data-loss test suite (sign-out, toggle, reinstall) — task, 3 pts, P0

### Sprint 18 · 02 Aug 2027 – 15 Aug 2027 · 13 pts

- [M4/E11] Scan photo library on-device for visits — story, 8 pts, P1
- [M4/E11] Suggestions inbox: 'You were in Lisbon, add it?' — story, 5 pts, P1

### Sprint 19 · 16 Aug 2027 – 29 Aug 2027 · 18 pts

- [M4/E4] Custom fields for collections — story, 5 pts, P1
- [M4/E11] Trips: group entries and view a trip — story, 5 pts, P1
- [M4/E12] Stats dashboard — story, 5 pts, P2
- [M4/E12] On this day — story, 3 pts, P2

### Sprint 20 · 30 Aug 2027 – 12 Sep 2027 · 16 pts

- [M1/E15] Tear the stub (films) and split-flap codes (flights) — story, 2 pts, P2
- [M1/E15] Sound pack: paper, stamp, seal — task, 1 pt, P2
- [M4/E9] Map filters: collection, year, trip — story, 3 pts, P1
- [M4/E12] Year in review — story, 5 pts, P2
- [M4/E12] Poster export of a trip or year — story, 5 pts, P2

### Sprint 21 · 13 Sep 2027 – 26 Sep 2027 · 13 pts

- [M5/E13] UI tests for critical flows — task, 5 pts, P0
- [M5/E13] Accessibility pass — story, 5 pts, P0
- [M5/E13] Performance and memory profiling — task, 3 pts, P1

### Sprint 22 · 27 Sep 2027 – 10 Oct 2027 · 11 pts

- [M5/E13] Optional Face ID app lock — story, 3 pts, P2
- [M5/E14] TestFlight internal beta — task, 2 pts, P0
- [M5/E14] App Store listing and privacy label — task, 3 pts, P0
- [M5/E14] Privacy policy and support page — task, 2 pts, P0
- [M5/E14] Release v1.0 — task, 1 pt, P0

**Total:** 81 items across 15 epics, 280 points.
