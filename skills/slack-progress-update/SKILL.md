---
name: slack-progress-update
description: Generate a concise, Slack-ready progress update on the current piece of work, grouped into Done / In Progress / Todo. Trigger when the user asks for a "slack update", "progress update", "status update", "what's my progress", "update for the team", "standup update", or wants to tell stakeholders where a project stands. Pulls live state from git, open PRs, ticket trackers, and active handoff docs, then writes it at a milestone level (not commit level) so non-technical readers can follow it.
---

# Slack Progress Update

## When to use

The user wants to tell their team / manager / stakeholders where a piece of work stands. The audience is **mixed** - some readers are non-technical (PMs, leads, other-team stakeholders). So the update describes *milestones and outcomes*, not commits or code. Each item should map to a ticket, PR, or a named deliverable a reader could recognize.

This is a reporting skill, not a working skill - gather state, then write. Do not start changing code.

## Core principles

- **Milestone level, not commit level.** "Addressed review comments, waiting for second review" - not "renamed NomCertificate to Nom151 in 4 sites." A non-technical reader should understand each line. If you catch yourself listing commits, zoom out.
- **Three sections, always: Done / In Progress / Todo.** This is the spine. Even if a section is empty, the reader expects the shape.
- **Done items point at the artifact.** A PR, a ticket, a merged branch - something the reader can click or reference. Pair the deliverable with its current gate ("PR raised → addressed comments, waiting for second review").
- **Surface blockers and gates inline**, attached to the item they block (e.g. "dashboards (to be done post production deployment)"), rather than burying them. If a Todo is gated on something, say what.
- **Terse but human.** Short lines. No code identifiers, file paths, or commit SHAs in the body unless the reader genuinely needs them.

## How to gather state

Pull the real picture before writing - don't invent progress. In parallel where possible:

1. **Git** - current branch, recent commits, whether work is pushed: `git log --oneline -15`, `git status -sb`. Use this to infer *what's actually done*, then translate up to milestone language.
2. **Open PRs** - state, review decision, unresolved threads. `gh pr view <n> --json state,reviewDecision,title,url`. For review-comment progress, count resolved vs unresolved threads (GraphQL `reviewThreads`). Translate to "addressed comments, waiting for review" / "N comments open."
3. **Handoff docs** - check `/tmp/handoff-*.md` for an active handoff on this work; it often already has the Done/Remaining breakdown. Reference it, don't re-derive from scratch.
4. **Tickets** - if a ticket key is in the branch name or commits (e.g. `PROJ-178`), use it as the anchor for the update.

Cross-repo work is common: a single update may span multiple repos/PRs (e.g. an engine PR + a downstream consumer change). Group by *deliverable*, not by repo.

If you can't determine something, ask the user one quick question rather than guessing - they know their roadmap. Especially: what's genuinely **in progress right now** vs **not started**, since git can't always tell you.

## Output format (Slack mrkdwn)

Slack uses `*bold*` (single asterisks), `•` bullets, and `_italic_`. Do not use Markdown `**` or `#`.

```
*<Project / ticket> - progress update*

*Done*
• <deliverable> → <current gate/state>
• <deliverable>

*In progress*
• <thing being actively worked on now>

*Todo*
• <upcoming deliverable>
• <deliverable> _(gated on <condition>)_
```

Keep it scannable. One line per item. Put gating conditions in `_italics_` right on the line they affect.

## Example

Context: PROJ-178 payments-retry work spanning a payments-service PR plus downstream client + schema changes. Engine PR is up and review comments are addressed; the core endpoint is being built; webhook/docs/test/dashboard work hasn't started.

```
*PROJ-178 payments-retry - progress update*

*Done*
• payments-service PR raised → review comments addressed, waiting for second review
• client + schema changes

*In progress*
• core endpoint

*Todo*
• webhook changes
• dev docs update
• e2e test
• dashboards _(to be done post production deployment)_
```

## Notes

- Default to the lightest gathering that gives an honest picture. A quick `git log` + `gh pr view` is usually enough; only dig into review threads or handoff docs when the user cares about review/comment progress.
- If the user gives you the breakdown themselves (which sits where), trust it - your job is then just to format and tighten, not to second-guess their roadmap.
- After producing the update, offer to refine sectioning or tone - some teams want more detail, others want one-liners.
