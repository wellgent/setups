# Issue tracker: GitHub Issues

Plans for this repo live as GitHub issues on it.
Use the `gh` CLI for every operation. It takes the repo from the checkout, and `{owner}/{repo}` in a `gh api` path stands for it.
The tracker is the working surface for `wayfinder` maps and their decision tickets.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for a multi-line body.
- **Read an issue**: `gh issue view <number> --comments`.
- **List issues**: `gh issue list --state open --json number,title,labels` with `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`.
- **Apply or remove labels**: `gh issue edit <number> --add-label "..."` or `--remove-label "..."`.
- **Close**: `gh issue close <number> --comment "..."`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, titled `Map: <name>` so maps stand out in the issue list and in browser tabs, holding the Destination, Notes, Decisions so far, Not yet specified and Out of scope body. `gh issue create --label wayfinder:map`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue: `gh api --method POST repos/{owner}/{repo}/issues/<map>/sub_issues -F sub_issue_id=<child-db-id>`, where `<child-db-id>` is the child's numeric database id (`gh api repos/{owner}/{repo}/issues/<n> --jq .id`), not its number. It carries one label, `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling` or `wayfinder:task`. Its title starts with the type as a word, `Research: `, `Prototype: `, `Grilling: ` or `Task: `, then a lowercase summary.
- **Blocking**: GitHub's native issue dependencies, which show in the tracker's own pages. Add an edge with `gh api --method POST repos/{owner}/{repo}/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, with the blocker's database id. GitHub reports the open blockers as `issue_dependencies_summary.blocked_by`. A ticket is unblocked when every blocker is closed.
- **Frontier query**: list the map's open children (`gh api repos/{owner}/{repo}/issues/<map>/sub_issues`), and drop any with an open blocker or an assignee. The first in map order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me`, the session's first write. An open ticket with an assignee is taken.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then add one line to the map's Decisions so far: the gist of the answer and a link to the ticket.
- **Research findings** land as `research/r-YYYYMMDD-<slug>.md` on `main`, linked from the ticket's resolution comment, so they outlive the ticket.
- **A prototype** is linked from its ticket and never lands on `main`. Only the decision it led to does.
- **No branch outlives its work.** Every branch other than `main` is deleted when its ticket closes. What it held either lands on `main` or lives with its ticket.
- **A decision that outlives its map** is written into this repo's pages, citing the ticket that settled it. The map stays an index of decisions, and the pages hold what is true.
