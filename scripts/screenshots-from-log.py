#!/usr/bin/env python3
"""Recover CI screenshots from a job log (when artifact downloads aren't available).

Usage: gh api repos/OWNER/REPO/actions/jobs/JOB_ID/logs | scripts/screenshots-from-log.py screenshots/<issue>
"""
import base64
import re
import sys
from pathlib import Path

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
name, buf = None, []
for line in sys.stdin:
    line = re.sub(r"^\S+Z ", "", line.rstrip("\n"))  # strip the runner timestamp
    if line.startswith("SCREENSHOT-BEGIN "):
        name, buf = line.split(" ", 1)[1].strip(), []
    elif line.startswith("SCREENSHOT-END") and name:
        (out / name).write_bytes(base64.b64decode("".join(buf)))
        print(f"saved {out / name}")
        name = None
    elif name:
        buf.append(line.strip())
