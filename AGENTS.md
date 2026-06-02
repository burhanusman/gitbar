# Agent Instructions

This project uses **GitBar Tickets** for local issue tracking. Tickets live in `.gitbar/tickets.jsonl` and image attachments live in `.gitbar/images/<ticket-id>/`.

Use the global Codex skill `$gitbar-tickets` when listing, creating, updating, or closing project tickets.

## Quick Reference

```bash
cat .gitbar/tickets.jsonl        # Inspect local tickets
mkdir -p .gitbar                 # Initialize ticket storage if needed
# Ticket statuses: open, in_progress, done
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File tickets for remaining work** - Create GitBar tickets for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update ticket status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
