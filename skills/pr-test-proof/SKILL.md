---
name: pr-test-proof
description: >-
  Add manual test-evidence scaffolding to a GitHub pull request description,
  organized as collapsible sections under a "Tests" heading. Each section holds a
  heading (e.g. Success, Failure, Error), an evidence link (logs, trace, dashboard), and a
  labeled blank space where the user will paste screenshots manually. Use this
  whenever the user wants to set up test proof, QA evidence, evidence links, or
  review-environment results on a PR — e.g. "add my test sections to the PR", "put
  this evidence link under Tests", "scaffold success and failure test cases on the PR",
  "add test proof headings". The skill collects a heading + evidence link per test case
  in a loop and updates the PR body via the gh CLI once the user says they're done.
  It does NOT add, host, or fetch screenshots — it only leaves room for them.
  Trigger even when the user does not say the word "skill".
---

# PR Test Proof

This skill scaffolds a clean, collapsible **Tests** section in a GitHub PR
description. It's for *integration work* and similar work where features are
validated by hand in a **review environment** (a dynamic, on-demand env that lasts
a few hours) rather than by automated unit tests. Each piece of proof is a heading
(e.g. "Success", "Failure", "Timeout") plus an **evidence
link**.

Crucially: **this skill does not write code tests and does not touch screenshots.**
The user pastes screenshots into the PR themselves after the fact — GitHub's image
hosting can't be reliably automated for private repos anyway, so trying would just
break. Your only job is to build the heading + evidence link and leave a clearly labeled
blank line where the user will drop their screenshot. Don't fetch, upload, or embed
images.

## The core loop

You gather one test case at a time and keep going until the user says they're
done. Each test case becomes one collapsible section.

1. **Identify the PR.** Run `gh pr view --json number,title,body,url` on the
   current branch. If there's no PR for the branch, ask the user for the PR
   number or URL and use `gh pr view <n> ...`. Keep the fetched `body` — you'll
   append to it, never overwrite the user's existing description.

2. **Collect a test case.** Ask the user for, or accept in a single JSON blob:
   - **heading** — the section title. Offer the three common defaults —
     **Success**, **Failure**, **Error** — and let the user pick one or type their
     own (e.g. "Timeout", "Provider error"). These three cover most
     step-development cases, so surfacing them saves typing; a custom heading is
     always fine.
   - **evidence link** — the evidence URL.
   
   If the user pastes a JSON blob, accept it as-is (see *Input formats*) and skip
   offering the defaults — they've already chosen. If they give pieces
   conversationally, take them as they come. A test case needs at least a heading;
   the evidence link is optional but usually present.

3. **Show the rendered section back** so the user can eyeball it, then ask:
   "Add another test case, or are you done?" Keep looping.

4. **On "done", update the PR.** Merge all collected sections under the Tests
   heading (see *Building the section*) and push with
   `gh pr edit <n> --body-file <tmpfile>`. Confirm with the PR URL and remind the
   user to drag their screenshots into the blank spots.

Don't update the PR after every single test case — that spams the PR's edit
history. Accumulate in memory and write once when the user is done. (If the user
explicitly asks to update incrementally, that's fine.)

## Input formats

Accept whatever the user gives. Two common shapes:

**Conversational** — they type a heading and paste a evidence link. Collect the pieces.

**JSON** — they paste a blob like this. Accept one object or an array of them:

```json
[
  {"heading": "Success", "link": "https://logs.example/case/abc123"},
  {"heading": "Provider error", "link": "https://logs.example/case/def456"}
]
```

Field names may vary (`vd_link`, `vdUrl`, `title`…). Map them sensibly rather than
rejecting the input. If a blob still carries a `screenshots` field from an old
habit, ignore it — this skill doesn't place images.

## Building the section

### One collapsible block per test case

Put the **evidence link first**, then a labeled blank line for the screenshot. The evidence
link is the entry point a reviewer clicks; the blank line is where the user will
later paste their screenshot. Use GitHub's `<details>` element so the Tests area
stays compact:

```markdown
<details>
<summary>Success</summary>

**Evidence:** https://logs.example/case/abc123

_Screenshot:_

</details>
```

What makes GitHub render this correctly, and why each piece matters:
- Keep the blank line after `<summary>` and before `</details>` — without them
  GitHub won't parse the markdown inside the block.
- The `_Screenshot:_` label followed by a blank line gives the user an obvious,
  consistent drop zone. When they click into the PR description and paste an
  image there, GitHub uploads it and inserts the markdown for them — so the spot
  needs to be visually clear, not pre-filled.
- If a test case has no evidence link, omit the `**Evidence:**` line but keep the screenshot
  label — the whole point of the block is to reserve that space.
- Never invent or embed an image URL. Leaving the space empty is the correct
  outcome here, not an omission to fix.

### Placing the Tests heading

Look at the PR body you fetched:

- **A `## Tests` (or `## Test`) heading already exists** → insert the new
  `<details>` blocks under it, after any sections already there. Match the
  existing heading's exact level and wording (`## Tests`, `### Tests`, etc.).
- **No Tests heading** → **append** a fresh `## Tests` heading and the blocks at
  the **end** of the description, separated from existing content by a blank line.

Preserve everything already in the description. You're adding to it, not rewriting.

## Writing the body safely

GitHub PR bodies contain markdown with backticks, quotes, and newlines that are
easy to mangle on a shell command line. Always write the final body to a temp file
and use `--body-file`, not `--body "..."`:

```bash
gh pr edit <number> --body-file /tmp/pr-body-<number>.md
```

Build that file from: the original body + (the merged-or-new Tests section). Then
clean up the temp file.

## Example end to end

The branch's PR body is:

```markdown
## Summary
Adds the foo-bar step executor.

## Tests
<details>
<summary>Success</summary>

**Evidence:** https://logs.example/case/old

_Screenshot:_

</details>
```

The user supplies a new case — heading "Failure", link `https://logs.example/case/new`.
Because a `## Tests` heading exists, you insert the new block *under* it, after the
existing Success block:

```markdown
## Summary
Adds the foo-bar step executor.

## Tests
<details>
<summary>Success</summary>

**Evidence:** https://logs.example/case/old

_Screenshot:_

</details>

<details>
<summary>Failure</summary>

**Evidence:** https://logs.example/case/new

_Screenshot:_

</details>
```

Then `gh pr edit <n> --body-file …`, report the PR URL, and tell the user where to
paste their screenshots.
