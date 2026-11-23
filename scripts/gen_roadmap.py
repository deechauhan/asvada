#!/usr/bin/env python3
"""Regenerates docs/ROADMAP.md from backlog/backlog.yaml.

Usage: python3 scripts/gen_roadmap.py
"""
import datetime as dt
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
b = yaml.safe_load((ROOT / "backlog/backlog.yaml").read_text())
cfg = b["sprints"]


def sprint_dates(i):
    start = dt.date.fromisoformat(str(cfg["start"])) + dt.timedelta(days=cfg["length_days"] * i)
    return start, start + dt.timedelta(days=cfg["length_days"] - 1)


def pts(n):
    return f"{n} pt" if n == 1 else f"{n} pts"


lines = [
    "# Roadmap",
    "",
    "Generated from `backlog/backlog.yaml` by `scripts/gen_roadmap.py`. Edit the backlog and regenerate rather than editing this file.",
    "",
    "Capacity assumption: **~14 points per two-week sprint** (side-project pace). Re-plan at each sprint review using actual velocity.",
    "",
    "## Milestones (releases)",
    "",
    "| Milestone | Target date | Scope |",
    "|---|---|---|",
]
for m in b["milestones"].values():
    lines.append(f"| **{m['title']}** | {m['due']} | {m['description']} |")
lines += ["", "## Epics", "", "| Epic | Milestone | Points |", "|---|---|---|"]
for e in b["epics"]:
    lines.append(f"| {e['key']} · {e['title'].replace('Epic: ', '')} | {e['milestone']} | {sum(i['points'] for i in e['items'])} |")
lines += ["", "## Sprint plan", ""]
by_sprint = {}
for e in b["epics"]:
    for it in e["items"]:
        by_sprint.setdefault(it["sprint"], []).append((it, e))
for i in range(cfg["count"]):
    items = by_sprint.get(i, [])
    s, end = sprint_dates(i)
    lines.append(f"### Sprint {i} · {s:%d %b %Y} – {end:%d %b %Y} · {pts(sum(it['points'] for it, _ in items))}")
    lines.append("")
    for it, e in items:
        ms = it.get("milestone", e["milestone"])
        lines.append(f"- [{ms}/{e['key']}] {it['title']} — {it['type']}, {pts(it['points'])}, {it['priority']}")
    lines.append("")
n = sum(len(e["items"]) for e in b["epics"])
total = sum(i["points"] for e in b["epics"] for i in e["items"])
lines.append(f"**Total:** {n} items across {len(b['epics'])} epics, {total} points.")
(ROOT / "docs/ROADMAP.md").write_text("\n".join(lines) + "\n")
print(f"wrote docs/ROADMAP.md: {n} items, {total} points")
