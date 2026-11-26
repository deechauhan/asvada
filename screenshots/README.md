# Screenshots

Visual progress log. One folder per issue, named after the issue number:

```
screenshots/
  2/launch.png        ← from PR for #2
  12/entry-detail.png
```

**How they get here:** the **Nightly** workflow runs every UI test on an iOS simulator (PRs run
only a smoke set), exports every screenshot attachment from the test results and uploads them as
`screenshots-<shard>` artifacts. The autopilot batches them into one docs PR per night (see
`docs/AUTOPILOT.md`). By hand:

```bash
scripts/fetch-screenshots.sh   # → screenshots/<issue>/, issue taken from the branch name
git add screenshots && git commit -m "docs: screenshots for #<issue>"
```

They then land on `main` with the squash merge.

If artifact downloads are blocked (e.g. in a sandboxed session), CI also prints each PNG as
base64 in the job log; recover them with
`gh api repos/<owner>/<repo>/actions/jobs/<job-id>/logs | scripts/screenshots-from-log.py screenshots/<issue>`.

To add one by hand, drop a PNG into the issue's folder in the same PR.

To capture a new screen in a UI test:

```swift
let shot = XCTAttachment(screenshot: app.screenshot())
shot.name = "entry-detail"      // becomes entry-detail.png
shot.lifetime = .keepAlways
add(shot)
```
