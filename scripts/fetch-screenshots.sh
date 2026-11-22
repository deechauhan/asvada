#!/usr/bin/env bash
# Downloads the latest CI screenshots for the current branch into screenshots/<issue>/.
# Usage: scripts/fetch-screenshots.sh   (needs gh authenticated for the repo)
set -euo pipefail
branch=$(git rev-parse --abbrev-ref HEAD)
issue=$(echo "$branch" | sed -nE 's#^[a-z]+/([0-9]+)-.*#\1#p')
[ -n "$issue" ] || { echo "branch '$branch' is not <type>/<issue>-slug" >&2; exit 1; }
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || git remote get-url origin | sed -E 's#.*github.com[:/](.*)\.git$#\1#; s#.*github.com[:/]##')
run=$(gh api "repos/$repo/actions/workflows/ci.yml/runs?branch=$branch&status=success&per_page=1" -q '.workflow_runs[0].id')
[ -n "$run" ] || { echo "no successful CI run for $branch yet" >&2; exit 1; }
art=$(gh api "repos/$repo/actions/runs/$run/artifacts" -q '.artifacts[] | select(.name=="screenshots") | .id')
[ -n "$art" ] || { echo "run $run has no screenshots artifact" >&2; exit 1; }
tmp=$(mktemp -d)
gh api "repos/$repo/actions/artifacts/$art/zip" > "$tmp/s.zip"
mkdir -p "screenshots/$issue"
unzip -o -q "$tmp/s.zip" -d "screenshots/$issue"
echo "saved to screenshots/$issue:"; ls "screenshots/$issue"
