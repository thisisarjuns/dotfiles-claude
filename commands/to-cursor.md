---
description: Hand the current session's context to a Cursor agent (pick up there with /from-claude)
argument-hint: "What the Cursor agent should do next (optional)"
---

Write a handoff for a Cursor agent that has seen none of this conversation.

1. Write it to `~/.agent-handoff/latest.md` (create the dir if missing). Before overwriting, move any existing `latest.md` to `~/.agent-handoff/<YYYY-MM-DD-HHMM>.md`.
2. Contents, in this order, short bullets:
   - **Task:** the goal, and `$ARGUMENTS` as the next step if given
   - **Where:** repo absolute path, branch, PR/ticket URLs
   - **State:** what's done (commit hashes), what's verified and how, what's left
   - **Decisions:** what was decided and must not be re-opened, one line each
   - **Gotchas:** local env traps hit this session (exact commands that worked)
   - **Next action:** one concrete first step
3. Reference files, diffs, PRs by absolute path or URL; don't paste their content.
4. Redact secrets, tokens, and customer data.
5. Run `pbcopy < ~/.agent-handoff/latest.md`, then reply with the path and: "In Cursor: `/from-claude`, or paste."
