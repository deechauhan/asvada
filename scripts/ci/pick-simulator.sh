#!/usr/bin/env bash
# Prints the UDID of the newest available iPhone simulator.
set -euo pipefail
xcrun simctl list devices available -j | python3 -c '
import json, sys
devs = json.load(sys.stdin)["devices"]
best = None
for runtime, items in devs.items():
    if "iOS" not in runtime:
        continue
    ver = tuple(int(p) for p in runtime.rsplit("iOS-", 1)[-1].split("-") if p.isdigit())
    for d in items:
        if d["name"].startswith("iPhone") and (best is None or ver > best[0]):
            best = (ver, d["udid"], d["name"])
if not best:
    sys.exit("no iPhone simulator available")
print(best[1])
print(f"picked {best[2]} iOS {\".\".join(map(str, best[0]))}", file=sys.stderr)
'
