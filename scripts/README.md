# Scripts

## `bootstrap_github.py`

Seeds GitHub from `backlog/backlog.yaml`: labels, milestones, epics and stories (linked as
sub-issues), a Sprint 0 tracking issue, and the **Artifacts** Project board with Status, Priority,
Points and Sprint fields. Safe to re-run; it matches existing labels, milestones and issues by name.

```bash
pip install pyyaml
gh auth login                 # once
gh auth refresh -s project    # Projects (v2) needs the project scope
python3 scripts/bootstrap_github.py --validate   # offline sanity check
python3 scripts/bootstrap_github.py              # create everything
```

After it runs, open the project and switch the default view to **Board** grouped by **Status**
(views can't be created through the API), and add a **Table** view grouped by **Sprint**.
