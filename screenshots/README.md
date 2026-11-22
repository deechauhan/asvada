# Screenshots

Visual progress log. One folder per issue, named after the issue number:

```
screenshots/
  2/launch.png        ← from PR for #2
  12/entry-detail.png
```

**How they get here:** the CI `app` job runs the UI tests on an iOS simulator, exports every
screenshot attachment from the test results, shows them in the run summary and uploads them
as the `screenshots` artifact. Before merging, pull them into the PR:

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
