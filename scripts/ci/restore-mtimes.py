#!/usr/bin/env python3
"""Sets every tracked file's modification time from its content, so build caches see real changes.

A fresh checkout stamps every file with "now", so Xcode and SwiftPM would see every source as
changed and rebuild everything, even with their build products restored from the cache. Instead,
each file's time comes from its git blob id: the same content always gets the same time, on any
branch, so unchanged files look unchanged and only what really changed recompiles.

Not commit times (#213): `git log --name-only` lists no files for merge commits, so after a branch
merged main a changed file could carry the very time main's cached build had seen, and the Swift
driver (which compares times, not content) kept the stale object.

Times are spread over 2001–2017, always in the past. Usage: restore-mtimes.py [repo-root]
"""
import os
import subprocess
import sys

BASE = 1_000_000_000  # Sep 2001
SPREAD = 500_000_000  # ~16 years

root = sys.argv[1] if len(sys.argv) > 1 else "."
listing = subprocess.run(["git", "-C", root, "ls-files", "-s", "-z"], capture_output=True, check=True,
                         text=True).stdout

stamped = 0
for record in listing.split("\0"):
    if not record:
        continue
    meta, path = record.split("\t", 1)
    _mode, blob, _stage = meta.split()
    full = os.path.join(root, path)
    if os.path.isfile(full) and not os.path.islink(full):
        when = BASE + int(blob[:12], 16) % SPREAD
        os.utime(full, (when, when))
        stamped += 1
print(f"stamped modification times from content for {stamped} files")
