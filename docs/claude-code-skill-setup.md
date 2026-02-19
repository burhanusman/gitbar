# GitBar Tickets - Claude Code Skill Setup

This document explains how to set up the GitBar tickets skill for Claude Code on any computer.

## Overview

The skill allows Claude Code to manage local tickets stored in `.gitbar/tickets.jsonl` within any project. You can use commands like `/tickets list`, `/tickets create`, or ask naturally like "what tickets do I have?"

## Setup Instructions

### 1. Create the skill directory

```bash
mkdir -p ~/.claude/skills/gitbar-tickets
```

### 2. Create the skill file

Create `~/.claude/skills/gitbar-tickets/SKILL.md` with the following content:

```yaml
---
name: tickets
description: Manage GitBar project tickets. Use when organizing work, marking tasks complete, checking task status, or when the user mentions tickets/tasks/todos for this project.
allowed-tools: Read, Edit, Bash, Glob
---

# GitBar Tickets

Manage local tickets for the current project. Tickets are stored in `.gitbar/tickets.jsonl`.

## Ticket Format (JSONL)

Each line is a JSON object:
```json
{"id":1,"title":"Fix bug","description":"Details","status":"open","images":[],"created_at":"2024-01-01T00:00:00Z","updated_at":"2024-01-01T00:00:00Z"}
```

**ID:** Simple sequential integer (1, 2, 3, ...)
**Status values:** `open`, `in_progress`, `done`

## Commands

### List tickets
Read `.gitbar/tickets.jsonl` and display tickets grouped by status. Use the simple numeric ID (e.g., #1, #2).

### Mark ticket done
Edit the ticket's JSON line: change `"status":"open"` or `"status":"in_progress"` to `"status":"done"` and update `updated_at` to current ISO 8601 timestamp.

### Create ticket
Append a new JSON line with:
- `id`: next sequential integer (find max existing ID + 1, or 1 if empty)
- `status`: `open`
- `images`: `[]`
- `created_at` and `updated_at`: current ISO 8601 timestamp

### View ticket details
Read and display the full ticket including description and images.

## Task

$ARGUMENTS
```

### 3. Verify installation

Run Claude Code in any project directory and try:

```
/tickets list
```

Or ask naturally:
- "what tickets do I have?"
- "create a ticket for fixing the login bug"
- "mark ticket 1 as done"

## Per-Project Data

Tickets are stored per-project in `.gitbar/tickets.jsonl`. The skill reads from and writes to this file relative to your current working directory.

### Sample tickets.jsonl

```jsonl
{"id":1,"title":"Fix login bug","description":"The form fails silently on invalid input","status":"open","images":[],"created_at":"2025-02-15T10:00:00Z","updated_at":"2025-02-15T10:00:00Z"}
{"id":2,"title":"Add dark mode","description":"Support system appearance preference","status":"in_progress","images":[],"created_at":"2025-02-15T11:00:00Z","updated_at":"2025-02-15T12:00:00Z"}
```

## Integration with GitBar App

If you're using the GitBar macOS app, tickets created via Claude Code will automatically appear in the Tickets tab when viewing that project.
