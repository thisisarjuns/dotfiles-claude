---
name: cp
description: Copy only the paste-ready snippet from the last answer (suggested wording, command, query, ticket text) to the macOS clipboard via pbcopy. Use when the user types /cp, says "copy to my clipboard", "copy that", "cp this". Unlike built-in /copy, it copies the deliverable only, not the whole response.
---

1. Pick the paste-ready deliverable from your previous answer: the quoted wording, code block, command or draft text. Not the explanation around it. If there are several and it's unclear, copy the last one and say which.
2. If the user passed args (`/cp the sql`), copy that item instead.
3. Copy with `pbcopy` using a quoted heredoc so backticks and `$` survive:
   ```bash
   pbcopy <<'EOF'
   <snippet>
   EOF
   ```
   Strip markdown blockquote `> ` prefixes; keep inline backticks unless the target is plain text (Jira ADF: no code inside bold).
4. Verify with `pbpaste | head -c 80`, then reply in one line: what was copied, character count.
