#!/usr/bin/env bash
# Deletes stale branches in $GITHUB_REPOSITORY (needs GH_TOKEN with contents: write).
# A branch is stale when it has no open PR AND either
#   - its most recent PR was merged or closed, or
#   - it is fully contained in main (nothing to lose).
# Never deletes main or the repository's default branch. Branches with no PR and unmerged
# commits are kept. Set DRY_RUN=1 to only print.
set -euo pipefail
repo=${GITHUB_REPOSITORY:?}
default=$(gh api "repos/$repo" -q .default_branch)
keep_re="^(main|${default})$"

gh api --paginate "repos/$repo/branches?per_page=100" -q '.[].name' | while read -r b; do
  [[ $b =~ $keep_re ]] && continue
  enc=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=""))' "$b")
  open=$(gh api "repos/$repo/pulls?state=open&head=${repo%%/*}:$enc" -q 'length')
  if [ "$open" != "0" ]; then echo "keep  $b (open PR)"; continue; fi
  last=$(gh api "repos/$repo/pulls?state=closed&head=${repo%%/*}:$enc&per_page=1" -q '.[0].number // empty')
  if [ -z "$last" ]; then
    behind=$(gh api "repos/$repo/compare/main...$enc" -q '.ahead_by')
    if [ "$behind" != "0" ]; then echo "keep  $b (no PR, $behind unmerged commits)"; continue; fi
    why="contained in main"
  else
    why="PR #$last closed"
  fi
  if [ "${DRY_RUN:-0}" = "1" ]; then echo "would delete $b ($why)"; else
    gh api -X DELETE "repos/$repo/git/refs/heads/$enc" && echo "deleted $b ($why)"
  fi
done
