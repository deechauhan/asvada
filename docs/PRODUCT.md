# Product

## Vision

A beautiful, private memory book of everything you've savoured — the cafés, meals, countries,
flights and films of your life — ranked your way and laid out on a living map.

## Problem

People already keep these lists, but scattered: Letterboxd for films, Beli for restaurants, a
country-counter app for travel, a notes file for cafés, and thousands of untagged photos. None of
them connect a trip's flight, food and places, and most want an account and a social feed.

## Target user

**Primary — "the curious collector" (the owner first):** travels a few times a year, eats out,
watches films, likes ranking things and looking back. Values privacy and owning their data.

**Secondary:** couples/friends who want a shared memory of trips (post-MVP, via export/sharing).

## Principles

1. **Private by default** — no account, data on device, optional iCloud.
2. **Fast to log** — any entry in under 15 seconds: pick collection → find item → rate → done.
3. **One model, many categories** — every category uses the same item/entry shape with its own rating style.
4. **Looking back is the reward** — timeline, map collage, "on this day", year in review.
5. **No dark patterns** — no streak guilt, no ads, no tracking.

## Scope

### MVP (M1 + M2): "Log, rank and see it on a map"

- Built-in collections: Cafés, Restaurants, Countries, Cities, Airlines, Films.
- Custom collections with custom fields.
- Rating modes: checklist, log, ranked (pairwise), stars.
- Quick-log flow with place search (MapKit), film search (TMDB), country/airline pickers.
- Entries with date, rating, notes, photos, companions, tags.
- Timeline home, collection views (list/grid/ranked/progress), entry detail.
- Map: country fill, clustered photo stacks, pins.
- Local storage only (SwiftData).

### Next (M3–M4)

- iCloud Drive backup & restore, then CloudKit sync.
- Photo-library backfill ("You were in Lisbon 12–16 Mar 2023 — add it?").
- Trips (group entries), stats, year in review, "on this day", poster export.

### Later / not now

- iPad & Mac apps, widgets, Apple Watch quick-log.
- Shared trips with friends, CSV/Letterboxd import, Android.
- Any social feed (deliberately out of scope).

## Success measures (personal project)

- The owner logs all past countries, airlines and favourite cafés within the first week.
- Logging a new entry takes < 15 s median.
- Zero data loss across app updates and restore-from-backup tests.
