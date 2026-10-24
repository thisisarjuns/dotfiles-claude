Send context from this conversation to another Claude session via the SendMessage tool.

Call ListAgents first, every time — session names change between turns, and a stale name fails to resolve.

Parse $ARGUMENTS as `[target] [what to send]`. Both parts are optional:

- Target named and it matches a listed session → send there.
- Target named but no match → show the live list and ask which one. Never guess at a near-match.
- No target → pick the session whose name is the closest topical match to the content being sent, say which one you picked and why in one line, then send. Only ask if nothing is a plausible match.
- No description of what to send → send the substance of the current conversation.

Write the message to stand alone. The receiving session has none of this context, so:

- Lead with a one-sentence statement of what this is and why it was sent. The receiver's human sees only the first line as a preview.
- Include concrete `file:line` references, URLs, ticket ids, and branch names. Never write "as discussed" or "the file we looked at".
- Carry across decisions the user already made and reaffirmed, and mark them as settled so the receiver does not re-litigate them.
- Point at published artifacts (PRs, Confluence pages, handoff docs) by URL or path rather than restating them, but summarise enough that the message is useful without opening them.
- `@path` attaches nothing on the receiving side — send the text itself, not a pointer to a local file you expect it to read.

Redact secrets, tokens, keys and personal data.

After sending, report which session it went to in one line. Do not paste the message body back to the user — they just read it being composed. If a `[Cross-session delivery notice]` says the target held or refused the message, say so plainly; a queued message is delivered but not necessarily read yet.
