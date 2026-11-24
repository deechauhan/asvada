#!/usr/bin/env python3
"""Sets every tracked file's modification time to the time of the last commit that changed it.

A fresh checkout stamps every file with "now", so Xcode and SwiftPM see every source as changed and
rebuild everything, even with their build products restored from the cache. With commit times,
unchanged files look unchanged and only what a commit touched is recompiled.

Needs the full history (actions/checkout with fetch-depth: 0). Usage: restore-mtimes.py [repo-root]
"""
import os
import subprocess
import sys

root = sys.argv[1] if len(sys.argv) > 1 else "."
tracked = set(subprocess.run(["git", "-C", root, "ls-files", "-z"], capture_output=True, check=True,
                             text=True).stdout.split("\0")) - {""}
log = subprocess.run(["git", "-C", root, "log", "--format=%x00%ct", "--name-only", "--no-renames"],
                     capture_output=True, check=True, text=True).stdout

stamped = 0
when = None
for line in log.splitlines():
    if line.startswith("\0"):
        when = int(line[1:])
    elif line and line in tracked:
        # Newest commit first, so the first time seen is the last change.
        tracked.discard(line)
        path = os.path.join(root, line)
        if os.path.isfile(path) and not os.path.islink(path):
            os.utime(path, (when, when))
            stamped += 1
print(f"restored modification times for {stamped} files")
