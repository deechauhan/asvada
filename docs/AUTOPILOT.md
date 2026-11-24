# Autopilot runbook

Unattended Claude Code sessions follow this runbook. A scheduled task starts a fresh cloud session
every few hours; each session reads GitHub to see where things stand and carries on. If a session
runs out of usage mid-ticket, nothing is lost: the branch and PR are on GitHub and the next run
resumes them.

Read `CLAUDE.md` and `docs/WAYS_OF_WORKING.md` first. Everything there still applies.

## Each run

1. **Sync.** `git fetch origin` and start from `origin/main`.
2. **Finish what's in flight first.** List open PRs by `deechauhan` or Claude on `deechauhan/asvada`.
   For each (oldest first):
   - CI red → read the failing job log, fix the root cause on that PR's branch, push.
   - Merge conflict → merge `origin/main` into the branch (no rebase/force-push), push.
   - CI green and mergeable → collect screenshots (below), then squash-merge with a Conventional
     Commit title ending in `(#<pr>)` and `Closes #<issue>` in the body.
   - CI still running → leave it; move on (the next run will merge it).
3. **Pick the next ticket** when no PR of yours is red or conflicted:
   - Open issues, not `type:epic`, not `ceremony`, not labelled `owner-only`.
   - Lowest planned sprint first (the `**Planned sprint:** Sprint N` line in the issue body),
     then the order in `backlog/backlog.yaml`.
   - Skip anything whose dependencies (stated in the issue or its epic) aren't merged yet.
4. **Do the ticket.** Branch `<type>/<issue#>-slug` off `origin/main` (`feat/` story, `chore/` task,
   `spike/` spike, `fix/` bug, `docs/` docs) and **push it straight away** so the board card moves to
   In progress (the PR moves it to In review; the merge to Done). Implement to the acceptance criteria with tests.
   Commit, push, open a PR using `.github/pull_request_template.md`, `Closes #<issue>`.
   Comment a short stand-up note on the issue (done / next / blocked).
5. **Wait for CI** (it takes a few minutes on macOS runners; docs-only PRs skip the Swift jobs, and the
   app job reuses cached build products), fix failures, then merge as in step 2.
6. **Repeat** from step 3 while there's usage left. Stop after the run has merged 3 PRs, so a
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
(see `screenshots/README.md`). After CI is green, pull them into `screenshots/<issue>/`:

```bash
# once per app job: "App build + UI test (launch)" and "(features)"
gh api repos/deechauhan/asvada/actions/jobs/<app-job-id>/logs | python3 -I scripts/screenshots-from-log.py screenshots/<issue>
```

Commit them to the PR branch (`docs: screenshots for #<issue>`), wait for CI again, then merge.

## Guardrails

- Never push to `main` directly; never force-push; never skip, disable or delete a test to get green.
- A job gets at most one re-run; "flaky" is not a root cause.
- If the same ticket's CI has failed 3 times in this run, or a decision belongs to the owner
  (product scope, design taste, anything needing money, accounts, secrets or repo settings):
  comment on the issue what's blocking and what's needed, add the `owner-only` label, and move on.
- Don't change `CLAUDE.md` decisions, the backlog structure, or workflows' permissions without
  an issue asking for it.
- Building and running happen only on CI (`macos-26`); you cannot run Xcode locally in a cloud session.
