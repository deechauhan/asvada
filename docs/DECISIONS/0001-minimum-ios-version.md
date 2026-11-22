# 0001 — Minimum iOS version

- **Status:** Accepted
- **Date:** 2026-11-22
- **Issue:** #7

## Context

Asvada is a new, solo-built SwiftUI app planned to reach v1.0 around September 2027
(milestone M5). By then iOS 27 will be shipping, so whatever we pick, the app launches
supporting the current and previous major versions at most. The stack leans heavily on
SwiftData, SwiftUI and MapKit, all of which have improved a lot in each release. Each
older OS we support costs `#available` branches, a second set of UI checks and older,
buggier SwiftData behaviour.

## Options considered

1. **iOS 26+** — one code path on the current design language (Liquid Glass) and the
   latest SwiftData (model inheritance, fixes to relationships and history tracking) and
   SwiftUI APIs (native `WebView`, rich-text `TextEditor`, newer `Map` and scroll APIs).
   Matches Swift 6.2 / Xcode 26 defaults. Cost: excludes devices that cannot run iOS 26.
2. **iOS 18+** — reaches more devices. SwiftData on iOS 18 already has `#Index`, history
   and custom stores, which covers our schema. Cost: the app would look dated next to
   iOS 26 system apps without double styling, and we would be testing two OS versions
   on our own for a long tail of users this app is unlikely to have at launch.
3. **iOS 17+** — earliest SwiftData. Ruled out: too many SwiftData bugs and missing APIs
   in 17, for little reach by 2027.

## Decision

**iOS 26.0 minimum, iPhone first.** At launch (2027) that is "current minus one", which is
the usual target for a new indie app. Simplicity of one code path beats a small gain in
reach for a personal app with no existing users.

## Consequences

- `project.yml` sets `deploymentTarget: iOS: "26.0"`; every package declares `.iOS(.v26)`
  (and `.macOS(.v26)` so logic packages can run `swift test` on the Mac host).
- CI uses the `macos-26` runner with the latest stable Xcode 26.
- No `#available` checks below 26 are needed. Revisit when iOS 28 ships: consider bumping to 27.
- iPad and Mac (Catalyst or native) stay later work; the packages already compile for macOS.
