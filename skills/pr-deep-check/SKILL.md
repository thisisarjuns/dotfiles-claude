---
name: pr-deep-check
description: "Run three independent reviews over one PR in parallel background agents - code review, ponytail over-engineering review, and simplification. Triggers on /pr-deep-check, 'deep check this PR', 'pr deep check', 'run all three reviews', or a request to code-review plus ponytail plus simplify the same PR."
---

# pr-deep-check

Fan three review passes out over a single PR, each in its own background agent, then
relay the findings. The point is independence: three lenses that disagree are worth
more than one that self-agrees.

## Arguments

`/pr-deep-check <pr-number> [repo-path]`

- `<pr-number>` required. A bare number, a `#916`, or a full GitHub PR URL - take the number out of it.
- `[repo-path]` optional; default to the current working directory's repo. If the PR belongs to a different repo than the cwd, resolve the local clone under `~/Workspace` and say which one you used.

If no PR number is given, check for a PR on the current branch with
`gh pr list --head "$(git branch --show-current)" --json number`. If there is none,
ask rather than guessing.

## Before spawning

Gather this once, in the foreground, and pass it into every agent. Getting it wrong
wastes three agents at once.

1. `gh pr view <n> --json number,state,isDraft,headRefName,baseRefName,title,url`
2. `gh pr diff <n> --name-only` - the authoritative file list. **Do not use `git diff base..HEAD`**; if the branch merged the base at some point, a two-dot or even merge-base diff can attribute the base's files to this PR. Every agent must be told to scope itself to `gh pr diff` output only.
3. The head sha, so all three review the same tree and their findings stay comparable.
4. Whether the repo has a `CLAUDE.md` - if so, tell each agent to read it, since it carries house rules the agents will otherwise violate in their suggestions.

## The three agents

Spawn all three in one message so they run concurrently. Name them
`review-<n>`, `ponytail-<n>`, `simplify-<n>` so they are addressable later.

| Agent | subagent_type | Job |
|---|---|---|
| `review-<n>` | `oh-my-claudecode:code-reviewer` | Correctness, security, race conditions, error handling, test adequacy |
| `ponytail-<n>` | `general-purpose` | Invoke the `ponytail:ponytail-review` skill and follow its terse format exactly |
| `simplify-<n>` | `code-simplifier:code-simplifier` | Duplication, unearned abstraction, reimplemented helpers, dead code |

Pass `model: "opus"` explicitly. The session model may carry a `[1m]` suffix, which
sub-agents cannot inherit, so omitting the model gets the call denied.

## What every agent's prompt must contain

Skipping any of these produces noise instead of findings:

- **Scope**: only the files in `gh pr diff <n> --name-only`. Say why - a base merge otherwise drags unrelated files in and the agent reports the base's debt as this PR's.
- **Intent**: two or three sentences on what the change does and why, with the ticket. An agent reviewing code it does not understand the purpose of invents problems.
- **Specific probes**: three to six concrete questions about *this* diff - the race you are unsure of, the guard that might be defeated, the field that might be dropped. Generic "review this" gets generic findings.
- **Known-and-settled list**: anything already found, already fixed, or deliberately chosen, with the reason. Without this you get the same three findings back every run, and deliberate trade-offs reported as bugs.
- **Report-only**: no edits, no pushes, no PR comments, no tickets. State it explicitly for all three - `code-simplifier` in particular will happily start editing.
- **Output path**: `/tmp/<agent>-<n>.md`, and return the findings too. The file survives an agent that goes idle without reporting.

## After they finish

Agents sometimes go idle without delivering. Check `/tmp/<agent>-<n>.md` exists before
concluding anything, nudge once via SendMessage, then read the artefact yourself and
report from it rather than waiting further.

Then:

1. **Deduplicate.** All three will often find the same thing from different angles. Report it once, noting it was found independently - that is signal about severity.
2. **Verify before relaying.** Agents are confidently wrong sometimes. For anything rated high, or anything that would change the code, check the claim against the source yourself and say whether you confirmed it. Never pass a finding to the user as fact because an agent asserted it.
3. **Separate real defects from taste.** Lead with what is wrong, then what is unnecessary, then what is merely stylistic. Cap the list; five ranked findings beat fifteen unranked.
4. **Say what nobody found.** If a pass came back clean, say so - that is a result, not an absence of one.

## Do not

- Do not apply any finding without asking. The reviews inform; the user decides.
- Do not run these against a huge PR without saying what it will cost. Three opus agents over a thousand-line diff is not free.
- Do not let an agent post to the PR. Findings come back to the user first.
