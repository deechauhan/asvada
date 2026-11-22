# Ways of working

Asvada is a solo project run with lightweight Scrum: two-week sprints, a groomed backlog on the
GitHub Project board, and one issue in progress at a time.

## Roles

| Role | Who |
|---|---|
| Product owner, developer, reviewer | Deepak |
| Pair / implementer | Claude (Claude Code on the Mac for building; any session for docs/planning) |

## Artefacts

| Artefact | Where |
|---|---|
| Product backlog | GitHub Issues, ordered on the **Asvada** Project board |
| Releases | Milestones `M0`–`M5` (see `ROADMAP.md`) |
| Sprints | Project **Sprint** field (2-week iterations) |
| Epics | Issues labelled `type:epic`; stories are their sub-issues |
| Decisions | `docs/DECISIONS/NNNN-title.md` (ADRs) |
| Source of truth for seeding | `backlog/backlog.yaml` → `scripts/bootstrap_github.py` |

## Issue types (labels)

- `type:epic` — a large outcome spanning several stories.
- `type:story` — user-visible value, written as *As a … I want … so that …* with acceptance criteria.
- `type:task` — technical/enabling work with no direct user value.
- `type:spike` — time-boxed research ending in an ADR or a decision comment.
- `type:bug` — something broken.

Plus `area:*` (which part of the app) and `priority:P0|P1|P2`.
Estimates are **story points** (Fibonacci 1, 2, 3, 5, 8, 13) in the Project **Points** field.
Anything bigger than 8 gets split.

## Board columns (Status)

Cards move automatically (`.github/workflows/project.yml`): pushing the issue's branch → In progress,
opening its PR → In review, merging (issue closed) → Done.

`Backlog` → `Ready` → `In progress` → `In review` → `Done`

- **Backlog** — captured, not yet refined.
- **Ready** — meets the Definition of Ready.
- **In progress** — a branch exists; WIP limit **1**.
- **In review** — PR open, CI green, awaiting self-review / merge.
- **Done** — meets the Definition of Done; issue closed by the PR.

## Definition of Ready

- Clear title and user story (or task description).
- Acceptance criteria are testable.
- Estimated in points (≤ 8).
- Dependencies identified and unblocked.
- Design notes or a sketch linked if it has UI.

## Definition of Done

- Acceptance criteria met and demoed on a device or simulator.
- Unit tests for logic; UI test for new critical flows.
- CI green (build, tests, lint).
- No new warnings; accessibility basics (labels, Dynamic Type) checked.
- Docs/ADR updated if behaviour or architecture changed.
- PR merged to `main` with a Conventional Commit squash message; issue auto-closed.

## Git workflow

- Trunk-based: `main` is always releasable and protected (PR + green CI required).
- One branch per issue: `feat/12-entry-model`, `fix/40-map-crash`, `chore/3-ci`, `docs/7-adr-sync`, `spike/9-clustering`.
- PR title = Conventional Commit; body includes `Closes #<issue>`.
- Squash merge; delete branch after merge.
- Every merge to `main` publishes a patch release (`v0.<m>.<n>`) with generated notes; closing a
  milestone publishes `v0.<k+1>.0` (M5 → `v1.0.0`). Releases are the changelog.

## Ceremonies (solo-sized)

| When | What | Time |
|---|---|---|
| Sprint start (Mon) | **Planning** — pull Ready items into the sprint up to capacity; set a sprint goal | 30 min |
| Each work session | **Stand-up note** — comment on the in-progress issue: done / next / blocked | 2 min |
| Mid-sprint | **Refinement** — split, estimate, and add AC to the next sprint's items | 30 min |
| Sprint end (Sun) | **Review** — demo what's done; update milestone progress | 20 min |
| Sprint end | **Retro** — one thing to keep, one to change, as a comment on the sprint's tracking issue | 10 min |

Default capacity: **~14 points per sprint** (side-project pace). Adjust after Sprint 1 using actuals.

## Working with Claude

- Start a session by naming the issue: "Work on #12". Claude reads `CLAUDE.md`, the issue, and its epic.
- Claude creates the branch, implements, writes tests, opens the PR with `Closes #12`, and moves the card.
- Builds, simulator runs and UI tests happen on the Mac (Claude Code locally).
