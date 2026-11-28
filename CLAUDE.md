# Artifacts — project brief for Claude

Read this first in every session. It records decisions already made; don't re-litigate them unless the owner asks.

## What this is

**Artifacts** (formerly *Asvada*; renamed Nov 2026) is a private, local-first iOS app for
recording and ranking things you've experienced: cafés, restaurants, countries, cities, airlines,
films, and any custom category. Its signature view is a **map collage** of everywhere you've been.

The seal mark stays the serif **ā**, from Sanskrit *āsvāda* (आस्वाद, "savouring, relish"): every
keepsake is sealed with it. Bundle id `app.artifacts.Artifacts`; the GitHub repo is still `deechauhan/asvada`.

Tagline candidates: "Savour what you've lived" · "Places, plates & films, savoured".

Owner: Deepak (`deechauhan`). Solo side project, run as an agile project on GitHub.

## Core decisions (settled)

| Area | Decision |
|---|---|
| Platform | Native **iOS 26+**, SwiftUI, Swift 6. iPhone first; iPad/Mac later. (Minimum OS confirmed in ADR-0001.) |
| Storage | **Local-first**: SwiftData on device. No account, no server of our own. |
| Cloud | **Optional** iCloud. MVP: iCloud Drive *backup/restore* (JSON + photos bundle). Later: CloudKit private-database sync. |
| Schema | Must be CloudKit-compatible from day one: every attribute optional or defaulted, every relationship optional, no `@Attribute(.unique)`. |
| Maps | MapKit. SwiftUI `Map` for simple screens; `MKMapView` wrapper (or ClusterMap) where clustering is needed — SwiftUI `Map` has no clustering API. |
| Countries | Bundled Natural Earth country polygons (public domain), offline point-in-polygon. |
| Places | `MKLocalSearch` (no API key, privacy-friendly). No Google Places. |
| Films | TMDB API (only online dependency); cache posters locally. |
| Airlines | Bundled static airline list (IATA/ICAO codes). |
| Photos | Store downscaled copies in-app (`@Attribute(.externalStorage)`), not PHAsset references. |
| Privacy | No analytics SDKs, no tracking. Network only for TMDB, map tiles, and user-enabled iCloud. |
| Design | **"Keepsakes"** (approved Nov 2026, `docs/design/CONCEPT.md`): entries are category-shaped keepsakes (receipt, menu card, passport stamp, postcard, boarding pass, ticket stub, luggage tag) sealed by holding the serif **ā**. Palette **Aubergine & Saffron**: plum ink `#6B2D8C` on warm paper `#FAF6F0`, saffron `#F2A93B` for macron bars only (never text), aubergine hero field. New York serif for voice, SF for UI. Never ship a plain CRUD list or a bare "0" — use keepsakes, ghost states and serif numerals. |
| Interaction | **"Savour by hand"** (approved 24 Nov 2026, `docs/design/INTERACTION.md`, epic E16): one gesture grammar — roll to browse one thing at a time, pull to open, pinch to see everything, hold to commit. Collections is a turning cabinet (the grid becomes the chest), a drawer opens into a riffle of keepsakes, quick-log draws a blank keepsake from a hand on the savour pill and a print head suggests the item, countries are stamped. Every gesture has a visible handle, a tap path, a VoiceOver path and a Reduce Motion crossfade. |

## Domain model

```
Collection  — a category (Cafés, Countries, Films…); `ExperienceCollection` in code. Defines ratingMode, viewMode, itemSource, field schema.
Item        — the thing itself (a café, Japan, a film). Optional externalRef (ISO code, IATA, TMDB id, MKMapItem id), coordinates, metadata.
Entry       — one encounter with an Item: date, rating, notes, photos, companions, tags, extra fields.
Trip        — optional grouping of entries (a Japan trip = country + airline + restaurants…).
Tag / Person — lightweight labels.
```

`ratingMode`: `checklist` (been / not been, completion vs a known set — countries),
`log` (repeatable dated entries — films, flights), `ranked` (ordered list built by pairwise
comparison, Beli-style — cafés, restaurants), `stars` (fallback).

## Map collage (signature feature)

Zoom-dependent layers: (1) zoomed out → visited countries filled; (2) mid zoom → city clusters
rendered as photo stacks with counts; (3) zoomed in → individual photo pins tinted by collection;
(4) shareable poster export of a trip/year.

## Differentiation (competitors researched Nov 2026)

Chronicle (rank everything, A/B comparisons), Rate It, Hypelist, Rately — media/ranking, often social.
Stamps, Been, Pin Traveler, Everpin, Mapsake, Places — travel/map only. Nobody combines
**taste + travel + map collage + private/local-first** with per-category rating modes. Keep the
name and UX from sounding travel-only.

## How we work

- Backlog lives in **GitHub Issues + the "Artifacts" Project board**. Work one issue at a time, top of the current sprint first.
- Milestones = releases (M0–M5). Project "Sprint" iteration field = 2-week sprints.
- Issue types via labels: `type:epic`, `type:story`, `type:task`, `type:spike`, `type:bug`. Stories are sub-issues of epics.
- Branch per issue: `<type>/<issue#>-short-slug` (e.g. `feat/12-entry-model`). PR closes the issue (`Closes #12`).
- Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`).
- Definition of Ready / Done: see `docs/WAYS_OF_WORKING.md`.
- Building/running needs Xcode on macOS; cloud sessions can edit code and docs but cannot build or run the simulator.

## Repo map

- `docs/PRODUCT.md` — vision, personas, scope, MVP definition
- `docs/ARCHITECTURE.md` — modules, data model, sync, map design
- `docs/ROADMAP.md` — releases and sprint plan
- `docs/WAYS_OF_WORKING.md` — agile process, DoR/DoD, branching, reviews
- `docs/DECISIONS/` — ADRs (architecture decision records)
- `docs/design/CONCEPT.md` — the approved "Keepsakes" design: language, signature moments, screens, tokens v2
- `docs/design/INTERACTION.md` — the approved "Savour by hand" interaction design: cabinet, riffle, hand, print head, stamp pad, motion and haptics kit II (prototype in `docs/design/prototype/`)
- `docs/AUTOPILOT.md` — runbook for unattended scheduled sessions
- `backlog/backlog.yaml` — source of truth used to seed the GitHub board
- `scripts/bootstrap_github.py` — creates labels, milestones, issues and the Project board
