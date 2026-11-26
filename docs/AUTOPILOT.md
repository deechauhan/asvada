# Autopilot runbook

Unattended Claude Code sessions follow this runbook. A scheduled task starts a fresh cloud session
every few hours; each session reads GitHub to see where things stand and carries on. If a session
runs out of usage mid-ticket, nothing is lost: the branch and PR are on GitHub and the next run
resumes them.

Read `CLAUDE.md` and `docs/WAYS_OF_WORKING.md` first. Everything there still applies.

## Each run

1. **Sync.** `git fetch origin` and start from `origin/main`.
2. **Check last night's run.** PRs run only a smoke set of UI tests; the whole suite runs in the
   **Nightly** workflow (01:23 UTC). If the latest Nightly run is red, fixing it comes before
   anything else: read the failing job's log, fix the root cause on a `fix/` branch (one PR per
   cause, `Closes` an issue for it), and merge as below. A test that fails in Nightly is never
   skipped or moved out of the suite to get green.
   ```bash
   gh api "repos/deechauhan/asvada/actions/workflows/nightly.yml/runs?per_page=1" --jq '.workflow_runs[0] | "\(.conclusion) \(.html_url)"'
   ```
   If it's green and has screenshots for issues merged since the last batch, collect them
   (see Screenshots).
3. **Finish what's in flight.** List open PRs by `deechauhan` or Claude on `deechauhan/asvada`.
   For each (oldest first):
   - CI red → read the failing job log, fix the root cause on that PR's branch, push.
   - Merge conflict → merge `origin/main` into the branch (no rebase/force-push), push.
   - CI green and mergeable → squash-merge with a Conventional Commit title ending in `(#<pr>)`
     and `Closes #<issue>` in the body. No screenshot commit first: that re-ran the whole of CI.
   - CI still running → leave it; move on (the next run will merge it).
4. **Pick the next ticket** when no PR of yours is red or conflicted:
   - Open issues, not `type:epic`, not `ceremony`, not labelled `owner-only`.
   - Lowest planned sprint first (the `**Planned sprint:** Sprint N` line in the issue body),
     then the order in `backlog/backlog.yaml`.
   - Skip anything whose dependencies (stated in the issue or its epic) aren't merged yet.
5. **Do the ticket.** Branch `<type>/<issue#>-slug` off `origin/main` (`feat/` story, `chore/` task,
   `spike/` spike, `fix/` bug, `docs/` docs) and **push it straight away** so the board card moves to
   In progress (the PR moves it to In review; the merge to Done). Implement to the acceptance criteria with tests.
   Commit, push, open a PR using `.github/pull_request_template.md`, `Closes #<issue>`.
   Comment a short stand-up note on the issue (done / next / blocked).
   Lint locally before every push, and push to an open PR once per ticket where you can: each such
   push is a full CI run.
6. **Wait for CI** (about 5 minutes once a runner is free: lint, package tests, and the app and UI
   test target built with a smoke set of UI tests; docs-only PRs skip the Swift jobs). Fix failures,
   then merge as in step 3. New UI tests are compiled on the PR but first run in Nightly; a flow
   that must never break can join the smoke set in `ci.yml` if the smoke job stays near 5 minutes.
7. **Repeat** from step 4 while there's usage left. Stop after the run has merged 3 PRs, so a
   human can review the pace and direction.

## Design

Every UI ticket follows `docs/design/CONCEPT.md` (Keepsakes, Aubergine & Saffron) for the look and
`docs/design/INTERACTION.md` (Savour by hand) for gestures, motion and haptics: roll, pull, pinch,
hold, each with a tap path, a VoiceOver path and a Reduce Motion crossfade. Check the ticket's
**Design** and **Depends on** sections, reuse the keepsake kit, motion and haptics tokens, and
attach screenshots so the owner can judge the look. If a ticket's acceptance criteria conflict with the
concept, follow the concept and say so in the PR.

## Screenshots

For any PR that changes UI, add or update a UI test that attaches a named screenshot
(see `screenshots/README.md`). The screenshots arrive with the next green **Nightly** run, which
runs every UI test. Batch them: for each issue merged since the last batch, take the screenshot
names its PR's tests added, pull those from the Nightly run's three app jobs into
`screenshots/<issue>/`, look at each one, and open one docs PR (`docs: screenshots from nightly
<date>`). Docs-only PRs skip the Swift jobs, so it merges in a minute.

```bash
# once per Nightly app job: "App build + UI test (menus)", "(launch)" and "(features)"
gh api repos/deechauhan/asvada/actions/jobs/<app-job-id>/logs | python3 -I scripts/screenshots-from-log.py <tmp-dir>
```

A PR's smoke run also exports screenshots, for the few tests in the smoke set.

## Guardrails

- Never push to `main` directly; never force-push; never skip, disable or delete a test to get green.
- A job gets at most one re-run; "flaky" is not a root cause.
- If the same ticket's CI has failed 3 times in this run, or a decision belongs to the owner
  (product scope, design taste, anything needing money, accounts, secrets or repo settings):
  comment on the issue what's blocking and what's needed, add the `owner-only` label, and move on.
- Don't change `CLAUDE.md` decisions, the backlog structure, or workflows' permissions without
  an issue asking for it.
- Building and running happen only on CI (`macos-26`); you cannot run Xcode locally in a cloud session.
