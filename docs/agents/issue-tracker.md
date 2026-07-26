# Issue tracker: GitHub

Issues and PRDs for this repository live in GitHub Issues for `acari-git/MLXServerManager`. Use the `gh` CLI for issue operations.

## Conventions

- Create: `gh issue create --title "..." --body "..."`
- Read: `gh issue view <number> --comments`
- List: `gh issue list --state open --json number,title,body,labels,comments`
- Comment: `gh issue comment <number> --body "..."`
- Apply or remove labels: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- Close: `gh issue close <number> --comment "..."`

Infer the repository from the current Git remote.

## Pull requests as a triage surface

**PRs as a request surface: no.**

## Skill behavior

When a skill says to publish to the issue tracker, create a GitHub issue. When it says to fetch a ticket, use `gh issue view <number> --comments`.

All externally visible GitHub changes still require explicit user authorization under the repository safety rules.
