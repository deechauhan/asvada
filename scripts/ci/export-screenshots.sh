#!/usr/bin/env bash
# Usage: export-screenshots.sh <xcresult> <out-dir>
# Exports screenshot attachments from an .xcresult as <name>.png.
set -euo pipefail
result=$1; out=$2
tmp=$(mktemp -d)
xcrun xcresulttool export attachments --path "$result" --output-path "$tmp"
mkdir -p "$out"
python3 - "$tmp" "$out" <<'PY'
import json, os, re, shutil, sys
src, out = sys.argv[1], sys.argv[2]
manifest = json.load(open(os.path.join(src, "manifest.json")))
for test in manifest:
    for a in test.get("attachments", []):
        name = a.get("suggestedHumanReadableName") or a["exportedFileName"]
        # "launch_0_<uuid>.png" -> "launch.png"
        base = re.sub(r"_\d+_[0-9A-F-]{36}", "", os.path.splitext(name)[0], flags=re.I)
        # XCTest names debug attachments after the query ("Debug description for `"Keepsakes"
        # NavigationBar`"); upload-artifact rejects quotes, colons and the like, so swap them out.
        base = re.sub(r'[\\/"`:<>|*?\r\n]+', "-", base).strip("- ")
        ext = os.path.splitext(a["exportedFileName"])[1] or ".png"
        shutil.copy(os.path.join(src, a["exportedFileName"]), os.path.join(out, base + ext))
        print("exported", base + ext)
PY
