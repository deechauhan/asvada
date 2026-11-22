# Asvada

[![CI](https://github.com/deechauhan/asvada/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/deechauhan/asvada/actions/workflows/ci.yml)

> *āsvāda* (आस्वाद), Sanskrit — savouring, relish.

A private, local-first iOS app to record and rank what you've lived: cafés, restaurants,
countries, airlines, films and anything else, all stitched into a map collage of everywhere
you've been.

- **Private by design** — your data stays on your device; iCloud backup/sync is optional.
- **One place for everything** — taste and travel together, with a rating style that fits each category.
- **Map collage** — countries fill in, cities become photo stacks, places become pins.

## Status

Pre-development. Planning happens on the **Asvada** GitHub Project board; see
[`docs/ROADMAP.md`](docs/ROADMAP.md) for releases and sprints.

## Docs

| Doc | What's in it |
|---|---|
| [Product](docs/PRODUCT.md) | Vision, users, scope, MVP |
| [Architecture](docs/ARCHITECTURE.md) | Tech stack, data model, storage & sync, map design |
| [Roadmap](docs/ROADMAP.md) | Milestones and sprint plan |
| [Ways of working](docs/WAYS_OF_WORKING.md) | Agile process, Definition of Ready/Done, branching |
| [Decisions](docs/DECISIONS/) | Architecture decision records |

## Getting started

Requirements: macOS with Xcode 26+, [XcodeGen](https://github.com/yonaskolb/XcodeGen), and a free TMDB API key for film search (later).

```bash
brew install xcodegen
xcodegen generate        # creates Asvada.xcodeproj from project.yml (not committed)
open Asvada.xcodeproj
```

Run a module's unit tests without Xcode's UI: `swift test --package-path Packages/Core/Model`.

### Code style

[SwiftFormat](https://github.com/nicklockwood/SwiftFormat) and [SwiftLint](https://github.com/realm/SwiftLint) are enforced in CI (`.swiftformat`, `.swiftlint.yml`). Before pushing:

```bash
brew install swiftformat swiftlint
swiftformat .                 # fixes formatting in place
swiftlint lint --strict       # warnings fail CI
```

### Automation (GitHub Actions)

| Workflow | What it does |
|---|---|
| **CI** (`ci.yml`) | On every PR and push to `main`: `swift test` for each package, then builds the app, runs the UI tests on an iOS simulator and uploads screenshots |
| **Label PR** (`labeler.yml`) | Adds `area:*` labels from changed paths and `type:*` from the branch prefix |
| **Project board** (`project.yml`) | Adds new issues and PRs to the Asvada board; run it by hand to (re)seed the board from `backlog/backlog.yaml`. Needs a `PROJECT_TOKEN` secret (classic PAT, `repo` + `project` scopes) |
| **Release** (`release.yml`) | Every merge to `main` publishes a GitHub Release with a changelog of the PRs since the last one, grouped by type (patch bump, e.g. `v0.1.3` → `v0.1.4`). Closing a milestone publishes `v0.<k+1>.0` (M5 → `v1.0.0`) and sweeps stale branches. See [Releases](https://github.com/deechauhan/asvada/releases) |
| **Branch cleanup** (`branch-cleanup.yml`) | Deletes a PR's branch when it merges; weekly (and on demand) deletes branches whose PR is closed or that are already in `main`. Never deletes `main`, the default branch, branches with open PRs, or unmerged branches without a PR |

Progress screenshots live in [`screenshots/`](screenshots/).

### Layout

| Path | What |
|---|---|
| `App/` | App target: `@main` entry point, assets |
| `AppUITests/` | UI tests (launch + screenshot) |
| `Packages/Features` | Feature screens (SwiftUI) |
| `Packages/Core/*` | Model, Storage, Geo, Sources, Ranking, DesignSystem |
| `project.yml` | XcodeGen spec for the app project |
| `screenshots/` | Per-issue screenshots from CI |

## Licence

All rights reserved (to be decided).
