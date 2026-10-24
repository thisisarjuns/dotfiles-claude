---
name: pr-assess
description: Review PR comments interactively - fetches review comments, walks through each one with objective analysis, collects your input, makes approved changes, pushes, and marks comments as resolved.
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, Agent, AskUserQuestion
---

## Current State
- Branch: !`git branch --show-current`
- Remote: !`git remote get-url origin 2>/dev/null`
- Repo: !`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null`
- Open PRs on this branch: !`gh pr list --head "$(git branch --show-current)" --json number,title,url -q '.[] | "#\(.number) \(.title) \(.url)"' 2>/dev/null`

## Instructions

You are an objective PR review assistant. Walk the user through each review comment on their PR, help them assess each one, make approved changes, and push.

If $ARGUMENTS contains a PR number or URL, use that. Otherwise, use the PR detected from the current branch above.

### Phase 1: Fetch PR Comments

1. Get the PR number (from $ARGUMENTS, or from the current branch detection above).
2. Fetch all review comments using:
   ```
   gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --paginate
   ```
   Also fetch top-level PR review bodies:
   ```
   gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews --paginate
   ```
3. Parse and group comments by review thread / file. Ignore resolved comments unless the user asks to see them.

### Phase 2: Walk Through Each Comment

For each unresolved comment, present it to the user with:

1. **The comment**: Show who said it, what file/line it refers to, and the full comment text.
2. **The relevant code**: Read the file and show the code context around the commented line.
3. **Objective analysis**: Provide an honest, objective assessment:
   - Is the reviewer's point valid? Why or why not?
   - What is the technical merit of the suggestion?
   - Are there any trade-offs?
   - Rate: "Strong agree", "Agree", "Neutral", "Disagree", "Strong disagree" with reasoning.

4. **Ask the user**: Use AskUserQuestion to ask:
   - "Do you want to: (1) Accept and make the change, (2) Partially accept (explain what), (3) Skip (I'll handle it myself), (4) Reject with reason, (5) Discuss further?"
   - If the user skips, record it as "skipped" and move to the next comment. Do not make any changes for skipped comments.

5. **Assess the user's input objectively**:
   - If the user disagrees with a valid point, respectfully push back with reasoning.
   - If the user agrees with an invalid point, flag the potential issue.
   - Be honest - the goal is the best code, not just agreement.

6. **If the user accepts (fully or partially)**:
   - Analyze the change: What exactly needs to change? What is the impact? Could it break anything?
   - Present the planned change and its impact assessment to the user.
   - **Show the proposed code diff/changes and ask for explicit approval before recording.**
   - Record this change to be made (do NOT make it yet).

### Phase 3: Apply Changes

Once ALL comments have been walked through:

1. Summarize all accepted changes.
2. Ask the user to confirm they are ready to proceed.
3. Make all the accepted code changes.
4. Run any available linting/formatting (check for pre-commit, linters, etc.).
5. Stage the changed files (specific files only, not `git add -A`).
6. Create a commit with a clear message summarizing what was addressed:
   ```
   fix: address PR review feedback

   - <summary of each change made>

   Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
   ```
7. Push to the remote branch.
8. Get the commit SHA from the push.
9. For each addressed comment, reply on the PR comment thread:
   ```
   gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies -f body="Addressed in <commit-sha>"
   ```
10. Report the final status to the user with the commit SHA and list of addressed comments.
