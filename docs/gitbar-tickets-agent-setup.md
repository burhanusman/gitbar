# GitBar Tickets Agent Setup

GitBar Tickets are local project tickets stored directly in a project folder. The GitBar app reads `.gitbar/tickets.jsonl` for the selected project, and image attachments live in `.gitbar/images/<ticket-id>/`.

## Use In Any Project

1. Open or add the project in GitBar. The folder may be a Git repository or a standalone folder containing `.gitbar/tickets.jsonl`.
2. Open the Tickets tab.
3. Create tickets in the app, or ask an agent with the GitBar Tickets skill to create them.
4. Add dependency IDs to `dependencies`, for example `"dependencies":[1,2]`. GitBar shows the ticket as blocked until those tickets are done.
5. Commit `.gitbar/tickets.jsonl` and `.gitbar/images/**` if tickets should travel with a Git repository.
6. Add `.gitbar/` to that repository's `.gitignore` if tickets should stay local.

## Codex Global Skill

Install this skill once at `~/.codex/skills/gitbar-tickets/SKILL.md`. Then use `$gitbar-tickets` or ask naturally about project tickets from any repo.

````yaml
---
name: gitbar-tickets
description: Manage GitBar local project tickets stored in .gitbar/tickets.jsonl, including dependencies, status, and image attachment metadata.
---

# GitBar Tickets

Manage local tickets for the current project. Tickets are stored in `.gitbar/tickets.jsonl`.

Each non-empty line is one JSON object:
```json
{"id":1,"title":"Fix bug","description":"Details","status":"open","images":[],"dependencies":[],"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
```

Status values are `open`, `in_progress`, and `done`.

When creating a ticket, append a new JSON line with the next integer ID, `images: []`, `dependencies: []`, and ISO 8601 timestamps. Dependency values are ticket IDs that must be done first. When updating a ticket, prefer appending the updated ticket as a new JSON line; GitBar loads the latest entry for each ID. Keep image metadata in the `images` array and store image files under `.gitbar/images/<ticket-id>/`.
````

## Claude Code

The same skill body can also be installed at `~/.claude/skills/gitbar-tickets/SKILL.md` for Claude Code.

## Current App/Website Coverage

The GitBar app exposes this through the Tickets tab for each project. The current public website does not describe this local `.gitbar/tickets.jsonl` workflow.
