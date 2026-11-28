#!/usr/bin/env python3
"""Set an issue's Status on the "Artifacts" GitHub Project (adding it to the board if needed).

Usage: project_status.py <issue-number> <status>
Env:   GH_TOKEN (classic PAT with repo + project scopes), GITHUB_REPOSITORY, PROJECT_TITLE (default Artifacts)
Status names come from scripts/bootstrap_github.py: Backlog, Ready, In progress, In review, Done.
"""
import json
import os
import subprocess
import sys


def graphql(query: str, **variables):
    args = ["gh", "api", "graphql", "-f", f"query={query}"]
    for key, value in variables.items():
        args += ["-F" if isinstance(value, int) else "-f", f"{key}={value}"]
    out = subprocess.run(args, capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f"GraphQL failed: {out.stderr or out.stdout}")
    data = json.loads(out.stdout)
    if data.get("errors"):
        sys.exit(f"GraphQL errors: {data['errors']}")
    return data["data"]


def main():
    number, status = int(sys.argv[1]), sys.argv[2]
    owner, name = os.environ["GITHUB_REPOSITORY"].split("/")
    title = os.environ.get("PROJECT_TITLE", "Artifacts")

    data = graphql(
        """query($owner:String!,$name:String!,$number:Int!){
          repository(owner:$owner,name:$name){ issue(number:$number){ id projectItems(first:20){ nodes{ id project{ id } } } } }
          user(login:$owner){ projectsV2(first:50){ nodes{ id title
            field(name:"Status"){ ... on ProjectV2SingleSelectField{ id options{ id name } } } } } } }""",
        owner=owner, name=name, number=number,
    )
    issue = data["repository"]["issue"]
    if not issue:
        print(f"#{number} is not an issue; nothing to do")
        return
    # The board was titled "Asvada" before the app was renamed; either title is accepted.
    titles = {title, "Artifacts", "Asvada"} if "PROJECT_TITLE" not in os.environ else {title}
    projects = data["user"]["projectsV2"]["nodes"]
    project = next((p for t in (title, "Artifacts", "Asvada") if t in titles
                    for p in projects if p["title"] == t), None)
    if not project:
        print(f"::warning::Project '{title}' not found; run the Project board workflow to create it")
        return
    field = project["field"]
    option = next((o["id"] for o in field["options"] if o["name"].lower() == status.lower()), None)
    if not option:
        sys.exit(f"Status '{status}' not found; options are {[o['name'] for o in field['options']]}")

    item = next((n["id"] for n in issue["projectItems"]["nodes"] if n["project"]["id"] == project["id"]), None)
    if not item:
        item = graphql(
            """mutation($p:ID!,$c:ID!){ addProjectV2ItemById(input:{projectId:$p,contentId:$c}){ item{ id } } }""",
            p=project["id"], c=issue["id"],
        )["addProjectV2ItemById"]["item"]["id"]
        print(f"added #{number} to {title}")

    graphql(
        """mutation($p:ID!,$i:ID!,$f:ID!,$o:String!){ updateProjectV2ItemFieldValue(input:{projectId:$p,itemId:$i,fieldId:$f,
          value:{singleSelectOptionId:$o}}){ projectV2Item{ id } } }""",
        p=project["id"], i=item, f=field["id"], o=option,
    )
    print(f"#{number} → {status}")


if __name__ == "__main__":
    main()
