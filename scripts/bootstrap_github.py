#!/usr/bin/env python3
"""Seed GitHub from backlog/backlog.yaml.

Creates (idempotently, matching by name/title):
  - labels
  - milestones (releases)
  - epic and story/task/spike issues, with stories linked as sub-issues of their epic
  - a "Sprint 0" ceremony tracking issue
  - a GitHub Projects (v2) board linked to the repo, with Status / Priority / Points / Sprint
    fields, every issue added and its fields set

Requirements: GitHub CLI (`gh`) authenticated with `repo` and `project` scopes
(`gh auth refresh -s project`), Python 3.9+, PyYAML (`pip install pyyaml`).

Usage:
  python3 scripts/bootstrap_github.py            # do everything
  python3 scripts/bootstrap_github.py --dry-run  # print what would happen
  python3 scripts/bootstrap_github.py --skip-project
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
import time
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
BACKLOG = ROOT / "backlog" / "backlog.yaml"

STATUS_OPTIONS = [
    ("Backlog", "GRAY", "Captured, not yet refined"),
    ("Ready", "BLUE", "Meets the Definition of Ready"),
    ("In progress", "YELLOW", "Being worked on (WIP limit 1)"),
    ("In review", "PURPLE", "PR open, awaiting merge"),
    ("Done", "GREEN", "Meets the Definition of Done"),
]
PRIORITY_OPTIONS = [("P0", "RED", "MVP-critical"), ("P1", "ORANGE", "Important"), ("P2", "YELLOW", "Nice to have")]

DRY = False


# ───────────────────────────── gh helpers ─────────────────────────────

def gh(args: list[str], payload: dict | None = None, ok_fail: bool = False):
    cmd = ["gh", "api", *args]
    if payload is not None:
        cmd += ["--input", "-"]
    res = subprocess.run(cmd, input=json.dumps(payload) if payload is not None else None,
                         capture_output=True, text=True)
    if res.returncode != 0:
        if ok_fail:
            return None
        sys.exit(f"gh api {' '.join(args)} failed:\n{res.stderr or res.stdout}")
    return json.loads(res.stdout) if res.stdout.strip() else None


def rest(method: str, path: str, payload: dict | None = None, ok_fail: bool = False):
    if DRY and method != "GET":
        print(f"  [dry-run] {method} {path} {json.dumps(payload)[:120] if payload else ''}")
        return {"number": 0, "id": 0, "node_id": "DRY"}
    return gh(["-X", method, path], payload, ok_fail)


def paginate(path: str) -> list:
    out, page = [], 1
    while True:
        sep = "&" if "?" in path else "?"
        batch = gh(["-X", "GET", f"{path}{sep}per_page=100&page={page}"]) or []
        out += batch
        if len(batch) < 100:
            return out
        page += 1


def graphql(query: str, variables: dict | None = None, ok_fail: bool = False):
    if DRY and query.lstrip().startswith("mutation"):
        print(f"  [dry-run] graphql {query.split('(')[0].split()[-1]} {json.dumps(variables)[:120]}")
        return None
    res = gh(["graphql"], {"query": query, "variables": variables or {}}, ok_fail)
    if res and res.get("errors"):
        if ok_fail:
            return None
        sys.exit(f"GraphQL error: {json.dumps(res['errors'], indent=2)}")
    return res["data"] if res else None


# ───────────────────────────── content ─────────────────────────────

def sprint_dates(cfg: dict, index: int) -> tuple[dt.date, dt.date]:
    start = dt.date.fromisoformat(str(cfg["start"])) + dt.timedelta(days=cfg["length_days"] * index)
    return start, start + dt.timedelta(days=cfg["length_days"] - 1)


def item_body(item: dict, epic: dict, sprints: dict) -> str:
    s, e = sprint_dates(sprints, item["sprint"])
    parts = []
    if item.get("story"):
        parts += ["## User story", "", item["story"], ""]
    if item.get("body"):
        parts += ["## What and why" if item["type"] != "spike" else "## Question", "", item["body"], ""]
    parts += ["## Acceptance criteria", ""] + [f"- [ ] {a}" for a in item["ac"]] + [""]
    if item.get("design"):
        parts += ["## Design", "", item["design"], "", "See `docs/design/CONCEPT.md`.", ""]
    parts += [
        "---",
        f"**Epic:** {epic['key']} · {epic['title'].replace('Epic: ', '')}  ",
        f"**Estimate:** {item['points']} pts · **Priority:** {item['priority']} · "
        f"**Planned sprint:** Sprint {item['sprint']} ({s:%d %b} – {e:%d %b %Y})",
        "",
        "_Seeded from `backlog/backlog.yaml`. Definition of Ready/Done: `docs/WAYS_OF_WORKING.md`._",
    ]
    return "\n".join(parts)


def epic_body(epic: dict) -> str:
    pts = sum(i["points"] for i in epic["items"])
    lines = ["## Outcome", "", epic["summary"], "", f"**Size:** {len(epic['items'])} items, {pts} points", "",
             "## Stories and tasks", "", "Attached as sub-issues (see the panel on the right).", ""]
    lines += [f"- {i['title']} ({i['type']}, {i['points']} pts)" for i in epic["items"]]
    return "\n".join(lines)


# ───────────────────────────── steps ─────────────────────────────

def ensure_labels(repo: str, labels: list[dict]):
    print("Labels")
    existing = {l["name"]: l for l in paginate(f"repos/{repo}/labels")}
    for l in labels:
        if l["name"] in existing:
            rest("PATCH", f"repos/{repo}/labels/{l['name'].replace(':', '%3A')}",
                 {"color": l["color"], "description": l["description"]})
        else:
            rest("POST", f"repos/{repo}/labels", l)
        print(f"  ✓ {l['name']}")


def ensure_milestones(repo: str, milestones: dict) -> dict[str, int]:
    print("Milestones")
    existing = {m["title"]: m for m in paginate(f"repos/{repo}/milestones?state=all")}
    numbers = {}
    for key, m in milestones.items():
        payload = {"title": m["title"], "description": m["description"], "due_on": f"{m['due']}T23:59:59Z"}
        if m["title"] in existing:
            num = existing[m["title"]]["number"]
            rest("PATCH", f"repos/{repo}/milestones/{num}", payload)
        else:
            num = rest("POST", f"repos/{repo}/milestones", payload)["number"]
        numbers[key] = num
        print(f"  ✓ {m['title']} (#{num})")
    return numbers


def ensure_issues(repo: str, b: dict, ms_numbers: dict) -> list[dict]:
    """Returns records: {title, number, id, node_id, kind, item, epic}."""
    print("Issues")
    existing = {i["title"]: i for i in paginate(f"repos/{repo}/issues?state=all") if "pull_request" not in i}
    records = []

    def upsert(title, body, labels, milestone):
        payload = {"title": title, "body": body, "labels": labels, "milestone": milestone}
        if title in existing:
            iss = rest("PATCH", f"repos/{repo}/issues/{existing[title]['number']}", payload)
        else:
            iss = rest("POST", f"repos/{repo}/issues", payload)
            time.sleep(1.0)  # stay under secondary rate limits for content creation
        return iss

    for epic in b["epics"]:
        labels = ["type:epic", f"area:{epic['area']}", f"priority:{epic['priority']}"]
        iss = upsert(epic["title"], epic_body(epic), labels, ms_numbers[epic["milestone"]])
        records.append({"title": epic["title"], "number": iss["number"], "id": iss["id"],
                        "node_id": iss["node_id"], "kind": "epic", "item": None, "epic": epic,
                        "state": iss.get("state", "open")})
        print(f"  ✓ #{iss['number']} {epic['title']}")
        for item in epic["items"]:
            labels = [f"type:{item['type']}", f"area:{epic['area']}", f"priority:{item['priority']}"]
            if item.get("owner_only"):
                labels.append("owner-only")
            milestone = ms_numbers[item.get("milestone", epic["milestone"])]
            iss = upsert(item["title"], item_body(item, epic, b["sprints"]), labels, milestone)
            records.append({"title": item["title"], "number": iss["number"], "id": iss["id"],
                            "node_id": iss["node_id"], "kind": "item", "item": item, "epic": epic,
                            "state": iss.get("state", "open")})
            print(f"    ✓ #{iss['number']} {item['title']}")

    # Sprint 0 ceremony tracker
    s, e = sprint_dates(b["sprints"], 0)
    title = "Sprint 0 · plan, review & retro"
    body = "\n".join([
        f"**Dates:** {s:%a %d %b} – {e:%a %d %b %Y}", "",
        "## Sprint goal", "", "A buildable, tested, CI-checked Xcode workspace with the key early decisions recorded.", "",
        "## Planning", "", "- [ ] Confirm sprint scope on the board (Sprint = Sprint 0)", "- [ ] Every item meets the Definition of Ready", "",
        "## Review", "", "- [ ] Demo what's Done", "- [ ] Update milestone progress", "",
        "## Retro", "", "Comment below: one thing to keep, one thing to change.",
    ])
    iss = upsert(title, body, ["ceremony"], ms_numbers["M0"])
    records.append({"title": title, "number": iss["number"], "id": iss["id"], "node_id": iss["node_id"],
                    "kind": "ceremony", "item": None, "epic": None, "state": iss.get("state", "open")})
    print(f"  ✓ #{iss['number']} {title}")

    # Issues created outside backlog.yaml (bugs, ad-hoc tasks) still belong on the board.
    seeded = {r["title"] for r in records}
    for t, i in existing.items():
        if t not in seeded:
            records.append({"title": t, "number": i["number"], "id": i["id"], "node_id": i["node_id"],
                            "kind": "extra", "item": None, "epic": None, "state": i["state"]})
            print(f"  ✓ #{i['number']} {t} (not in backlog.yaml)")
    return records


CLOSES_RE = re.compile(r"\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#(\d+)", re.I)


def issues_in_review(repo: str) -> set[int]:
    """Issue numbers referenced with Closes/Fixes/Resolves #N by open PRs."""
    if DRY:
        return set()
    return {int(n) for pr in paginate(f"repos/{repo}/pulls?state=open") for n in CLOSES_RE.findall(pr.get("body") or "")}


def board_status(r: dict, records: list[dict], in_review: set[int]) -> str:
    """Status for a seeded card: closed → Done, open PR → In review, otherwise from the plan."""
    if r["kind"] == "epic":
        children = [c for c in records if c["kind"] == "item" and c["epic"]["key"] == r["epic"]["key"]]
        if r["state"] == "closed" or (children and all(c["state"] == "closed" for c in children)):
            return "Done"
        return "In progress" if any(c["state"] == "closed" or c["number"] in in_review for c in children) else "Backlog"
    if r["state"] == "closed":
        return "Done"
    if r["number"] in in_review:
        return "In review"
    if r["kind"] == "item":
        return "Ready" if r["item"]["sprint"] == 0 else "Backlog"
    if r["kind"] == "ceremony":
        return "In progress"
    return "Backlog"


def link_sub_issues(repo: str, records: list[dict]):
    print("Sub-issues (epic → stories)")
    epics = {r["epic"]["key"]: r for r in records if r["kind"] == "epic"}
    for key, er in epics.items():
        current = {s["id"] for s in (gh(["-X", "GET", f"repos/{repo}/issues/{er['number']}/sub_issues?per_page=100"],
                                        ok_fail=True) or [])} if not DRY else set()
        for r in records:
            if r["kind"] == "item" and r["epic"]["key"] == key and r["id"] not in current:
                rest("POST", f"repos/{repo}/issues/{er['number']}/sub_issues", {"sub_issue_id": r["id"]})
        print(f"  ✓ {key} #{er['number']}")


def ensure_project(repo: str, b: dict, records: list[dict]):
    print("Project board")
    owner, name = repo.split("/")
    d = graphql("""query($owner:String!,$name:String!){
        repository(owner:$owner,name:$name){ id owner{ id login } }
        user(login:$owner){ projectsV2(first:50){ nodes{ id title number url } } } }""",
                {"owner": owner, "name": name})
    repo_id, owner_id = d["repository"]["id"], d["repository"]["owner"]["id"]
    project = next((p for p in d["user"]["projectsV2"]["nodes"] if p["title"] == b["project_title"]), None)
    if not project:
        r = graphql("""mutation($o:ID!,$t:String!,$r:ID!){
            createProjectV2(input:{ownerId:$o,title:$t,repositoryId:$r}){ projectV2{ id number url } } }""",
                    {"o": owner_id, "t": b["project_title"], "r": repo_id})
        if DRY:
            print("  [dry-run] would create project and fields")
            return
        project = r["createProjectV2"]["projectV2"]
    pid = project["id"]
    print(f"  ✓ {b['project_title']} → {project['url']}")
    graphql("""mutation($p:ID!){ updateProjectV2(input:{projectId:$p,
        shortDescription:"Asvada — agile backlog (see docs/WAYS_OF_WORKING.md)",
        readme:"Board columns follow Status. Milestones = releases; Sprint = 2-week iterations. Source of truth: backlog/backlog.yaml"}){ projectV2{ id } } }""",
            {"p": pid}, ok_fail=True)

    def fields():
        q = graphql("""query($p:ID!){ node(id:$p){ ... on ProjectV2{ fields(first:50){ nodes{
            ... on ProjectV2FieldCommon{ id name dataType }
            ... on ProjectV2SingleSelectField{ options{ id name } }
            ... on ProjectV2IterationField{ configuration{ iterations{ id title startDate } } } } } } } }""",
                    {"p": pid})
        return {f["name"]: f for f in q["node"]["fields"]["nodes"] if f}

    fs = fields()

    # Status: replace default options with our columns
    status = fs["Status"]
    if [o["name"] for o in status.get("options", [])] != [o[0] for o in STATUS_OPTIONS]:
        graphql("""mutation($f:ID!,$opts:[ProjectV2SingleSelectFieldOptionInput!]){
            updateProjectV2Field(input:{fieldId:$f,singleSelectOptions:$opts}){ projectV2Field{ ... on ProjectV2FieldCommon{ id } } } }""",
                {"f": status["id"], "opts": [{"name": n, "color": c, "description": d} for n, c, d in STATUS_OPTIONS]},
                ok_fail=True)

    if "Priority" not in fs:
        graphql("""mutation($p:ID!,$opts:[ProjectV2SingleSelectFieldOptionInput!]){
            createProjectV2Field(input:{projectId:$p,dataType:SINGLE_SELECT,name:"Priority",singleSelectOptions:$opts}){ projectV2Field{ ... on ProjectV2FieldCommon{ id } } } }""",
                {"p": pid, "opts": [{"name": n, "color": c, "description": d} for n, c, d in PRIORITY_OPTIONS]})
    if "Points" not in fs:
        graphql("""mutation($p:ID!){ createProjectV2Field(input:{projectId:$p,dataType:NUMBER,name:"Points"}){ projectV2Field{ ... on ProjectV2FieldCommon{ id } } } }""",
                {"p": pid})
    if "Sprint" not in fs:
        cfg = b["sprints"]
        its = [{"title": f"Sprint {i}", "startDate": str(sprint_dates(cfg, i)[0]), "duration": cfg["length_days"]}
               for i in range(cfg["count"])]
        ok = graphql("""mutation($p:ID!,$c:ProjectV2IterationFieldConfigurationInput!){
            createProjectV2Field(input:{projectId:$p,dataType:ITERATION,name:"Sprint",iterationConfiguration:$c}){ projectV2Field{ ... on ProjectV2FieldCommon{ id } } } }""",
                     {"p": pid, "c": {"startDate": str(cfg["start"]), "duration": cfg["length_days"], "iterations": its}},
                     ok_fail=True)
        if ok is None:  # API without iteration support → fall back to a single-select field
            print("  ! Iteration field not supported by API; using single-select 'Sprint'")
            graphql("""mutation($p:ID!,$opts:[ProjectV2SingleSelectFieldOptionInput!]){
                createProjectV2Field(input:{projectId:$p,dataType:SINGLE_SELECT,name:"Sprint",singleSelectOptions:$opts}){ projectV2Field{ ... on ProjectV2FieldCommon{ id } } } }""",
                    {"p": pid, "opts": [{"name": i["title"], "color": "GRAY",
                                         "description": f"{i['startDate']} · 2 weeks"} for i in its]})
    fs = fields()

    def opt(field, name):
        return next((o["id"] for o in fs[field].get("options", []) if o["name"] == name), None)

    sprint_field = fs["Sprint"]
    sprint_ids = ({it["title"]: it["id"] for it in sprint_field["configuration"]["iterations"]}
                  if sprint_field.get("dataType") == "ITERATION" else
                  {o["name"]: o["id"] for o in sprint_field.get("options", [])})

    def set_field(item_id, field, value):
        graphql("""mutation($p:ID!,$i:ID!,$f:ID!,$v:ProjectV2FieldValue!){
            updateProjectV2ItemFieldValue(input:{projectId:$p,itemId:$i,fieldId:$f,value:$v}){ projectV2Item{ id } } }""",
                {"p": pid, "i": item_id, "f": fs[field]["id"], "v": value})

    in_review = issues_in_review(repo)
    for r in records:
        added = graphql("""mutation($p:ID!,$c:ID!){ addProjectV2ItemById(input:{projectId:$p,contentId:$c}){ item{ id } } }""",
                        {"p": pid, "c": r["node_id"]})
        item_id = added["addProjectV2ItemById"]["item"]["id"]
        if r["kind"] == "item":
            it = r["item"]
            status_name = board_status(r, records, in_review)
            set_field(item_id, "Status", {"singleSelectOptionId": opt("Status", status_name) or opt("Status", "Todo")})
            set_field(item_id, "Priority", {"singleSelectOptionId": opt("Priority", it["priority"])})
            set_field(item_id, "Points", {"number": it["points"]})
            sid = sprint_ids.get(f"Sprint {it['sprint']}")
            if sid:
                key = "iterationId" if sprint_field.get("dataType") == "ITERATION" else "singleSelectOptionId"
                set_field(item_id, "Sprint", {key: sid})
        elif r["kind"] == "epic":
            status_name = board_status(r, records, in_review)
            set_field(item_id, "Status", {"singleSelectOptionId": opt("Status", status_name) or opt("Status", "Todo")})
            set_field(item_id, "Priority", {"singleSelectOptionId": opt("Priority", r["epic"]["priority"])})
            set_field(item_id, "Points", {"number": sum(i["points"] for i in r["epic"]["items"])})
        elif r["kind"] == "extra":
            status_name = board_status(r, records, in_review)
            set_field(item_id, "Status", {"singleSelectOptionId": opt("Status", status_name) or opt("Status", "Todo")})
        else:
            status_name = board_status(r, records, in_review)
            set_field(item_id, "Status", {"singleSelectOptionId": opt("Status", status_name) or opt("Status", "Todo")})
            sid = sprint_ids.get("Sprint 0")
            if sid:
                key = "iterationId" if sprint_field.get("dataType") == "ITERATION" else "singleSelectOptionId"
                set_field(item_id, "Sprint", {key: sid})
        print(f"  ✓ board ← #{r['number']} ({status_name})")
    print(f"\nBoard: {project['url']}")


def validate(b: dict):
    labels = {l["name"] for l in b["labels"]}
    titles, problems, n, pts = set(), [], 0, 0
    for e in b["epics"]:
        for lab in (f"area:{e['area']}", f"priority:{e['priority']}"):
            if lab not in labels:
                problems.append(f"{e['key']}: unknown label {lab}")
        if e["milestone"] not in b["milestones"]:
            problems.append(f"{e['key']}: unknown milestone")
        for it in e["items"]:
            if it.get("milestone") and it["milestone"] not in b["milestones"]:
                problems.append(f"{it['title']}: unknown milestone {it['milestone']}")
        for it in e["items"]:
            n += 1
            pts += it["points"]
            if it["title"] in titles:
                problems.append(f"duplicate title: {it['title']}")
            titles.add(it["title"])
            if f"type:{it['type']}" not in labels:
                problems.append(f"{it['title']}: unknown type")
            if it["points"] not in (1, 2, 3, 5, 8):
                problems.append(f"{it['title']}: points {it['points']} not in 1,2,3,5,8")
            if not it.get("ac"):
                problems.append(f"{it['title']}: no acceptance criteria")
            if not (0 <= it["sprint"] < b["sprints"]["count"]):
                problems.append(f"{it['title']}: sprint out of range")
            item_body(it, e, b["sprints"])
    print(f"{len(b['epics'])} epics, {n} items, {pts} points, {len(labels)} labels, {len(b['milestones'])} milestones")
    print("\n".join(problems) if problems else "OK — no problems found")
    sample = b["epics"][5]
    print("\n--- sample body ---\n" + item_body(sample["items"][0], sample, b["sprints"]))


def main():
    global DRY
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--skip-project", action="store_true")
    ap.add_argument("--validate", action="store_true", help="offline: check the backlog and render bodies only")
    args = ap.parse_args()
    DRY = args.dry_run
    b = yaml.safe_load(BACKLOG.read_text())
    if args.validate:
        validate(b)
        return
    repo = b["repo"]
    ensure_labels(repo, b["labels"])
    ms = ensure_milestones(repo, b["milestones"])
    records = ensure_issues(repo, b, ms)
    if not DRY:
        link_sub_issues(repo, records)
    if not args.skip_project:
        ensure_project(repo, b, records)


if __name__ == "__main__":
    main()
