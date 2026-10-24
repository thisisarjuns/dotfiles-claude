---
name: cfl-edit
description: Safe Confluence page edit workflow — fetch, diff, gate on user approval, apply, then verify version bump and content diff. Use when user asks to edit, update, modify, or change a Confluence page (e.g. "edit cfl page 12345", "update confluence page", "change cfl content"). Mutations only — reads stay free.
allowed-tools: Read, Edit, Write, Bash, AskUserQuestion
---

## Scope

Triggers on Confluence **page edit** intent. Page reads, listing, search → run `cfl` directly, no skill needed.

In scope: `cfl page edit`, `cfl page create` only when explicitly requested as part of edit flow.
Out of scope: delete, attachment ops, space ops — defer to user.

## Hard rule

**Never** call `cfl page edit` without explicit user approval in the current turn. Memory of past approvals does not count. Each edit = fresh approval.

## Workflow

### 1. Fetch current state

```
cfl page view <page-id> --content-only > /tmp/cfl-edit-<page-id>-before.md
cfl page view <page-id> --output json | jq '{id, title, version: .version.number, parentId}' > /tmp/cfl-edit-<page-id>-meta.json
```

Capture: page ID, title, current version number, current content.

### 2. Build proposed content

Edit `/tmp/cfl-edit-<page-id>-before.md` → `/tmp/cfl-edit-<page-id>-after.md` with intended change. Use Read/Edit/Write tools on the temp file. Never pipe edits straight to `cfl page edit`.

### 3. Show diff + halt for approval

```
diff -u /tmp/cfl-edit-<page-id>-before.md /tmp/cfl-edit-<page-id>-after.md
```

Then call `AskUserQuestion`:
- Question: "Apply this edit to page <id> '<title>' (v<n> → v<n+1>)?"
- Options: `Apply`, `Revise`, `Cancel`

Block until answer. `Revise` → loop back to step 2. `Cancel` → stop, leave page untouched.

### 4. Apply

```
cfl page edit <page-id> --file /tmp/cfl-edit-<page-id>-after.md
```

Capture exit code + stdout. Non-zero → report error verbatim, do not retry silently.

### 5. Verify (both checks required)

**Version bump:**
```
cfl page view <page-id> --output json | jq '.version.number'
```
Must be exactly `before_version + 1`. If not — report mismatch, flag possible concurrent edit.

**Content diff:**
```
cfl page view <page-id> --content-only > /tmp/cfl-edit-<page-id>-applied.md
diff -u /tmp/cfl-edit-<page-id>-after.md /tmp/cfl-edit-<page-id>-applied.md
```

Markdown ↔ ADF roundtrip may add cosmetic whitespace/format diffs. Ignore those. Flag any **semantic** divergence (missing sections, changed values, dropped content).

### 6. Report

One-line outcome:
```
✓ Page <id> '<title>' updated v<old> → v<new>. Verified.
```
Or on divergence:
```
⚠ Page <id> updated but verify failed: <what differs>
```

## Cleanup

Leave temp files in `/tmp/cfl-edit-*` for the session — useful for re-runs. Do not auto-delete.

## Edge cases

- **Title-only change**: skip content diff, still version-check. Use `cfl page edit <id> --title "..."`.
- **Parent move**: same approval gate. Verify new `parentId` post-edit.
- **Storage-format edit** (raw XHTML): same flow, use `--storage` flag, diff with `--raw` view.
- **Legacy editor**: pass `--legacy` on both view+edit for lossless roundtrip.
- **Concurrent edit detected** (version jumped >1): abort, refetch, re-diff against new base, re-approve.
- **Soft-wrapped markdown**: cfl's markdown→ADF converter joins wrapped lines with *no space* ("side effect of**reading**"). Unwrap paragraphs and list items to one line each before `cfl page edit`.
- **Long markdown pages corrupt in cfl's converter (v1.0.27)**: a ~200-line page with ~28 inline code spans came back with sections duplicated and a raw `CFCODE2ENDC` placeholder in place of `<code>`. For any page over a few sections, render it yourself and push storage instead: `python3 -c "import markdown; print(markdown.markdown(open(f).read(), extensions=['tables','sane_lists'], tab_length=2, output_format='xhtml'))"` (add a blank line before lists that follow a paragraph, and set `<table data-layout="default">`), check well-formedness, then `cfl page edit <id> --storage --file x.xhtml`. Verify the `h2` count and order equal the source's `##` count, and grep for `CFCODE` = 0.
- **Verify against storage, not the markdown roundtrip**: `--content-only` re-renders ADF→markdown and adds padded table cells and `\#`/`\_` escapes that are not on the page. Check `jq -r '.body.storage.value'` instead (count `ac:name="code"`, `<table`, `<h1/2/3`). Never verify with `--raw`: it truncates at 5000 chars and reads like a lost push.

## Anti-patterns

- ❌ `echo "..." | cfl page edit` without showing diff first
- ❌ Approving once, then making "small follow-up" edit without re-asking
- ❌ Skipping verify because edit command exited 0 — exit code ≠ correctness
- ❌ Auto-resolving cosmetic diff as "fine" without showing user what changed
