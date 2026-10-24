---
name: peer-sync
description: Catch up on what another Claude session has done and get this session up to date. Use when the user says "get context from session X", "sync with <session>", "be up to date with <session>", "what did the other session do", or names a peer session (e.g. PROJ-123-refactor) as a source of truth. Read-only; reports conflicts with this session's own state.
---

## Rule
Read-only. Never edit Confluence, Jira, or the peer's files because the peer changed something. Conflicts go to the user as a question; decisions the peer logged as user-settled are not re-opened.

## Steps

1. **Find the peer.** `ListAgents`; match the name exactly. Note if it is busy (don't wait on it).

2. **Read its artifacts first, not the peer.** Artifacts are the truth; a peer's summary can be stale.
   - Shared decisions log (e.g. `~/notes/<ticket>/decisions.md`): `grep -n "<today>\|<yesterday>"` for dated entries, read sub-bullets under the decisions this session relies on.
   - Files it touched: `ls -lt <shared dir> | head` - new files since this session last looked.
   - Confluence pages either session owns: `cfl page view <id> --output json | jq '.version.number, .version.when'` and the h2/h3 outline from storage. A version higher than this session's pointer = someone else edited it.
   - Jira tickets this session created: REST `fields=updated,status,summary` per key; an `updated` later than this session's last write = changed elsewhere.

3. **Ask the peer only for gaps.** If something is unclear from artifacts, `SendMessage` one specific question. Don't ask for a full recap.

4. **Diff against this session's state.** List, per item: what the peer settled, and where this session's published work (pages, tickets, drafts) now contradicts it. Quote file:line or page section.

5. **Sync pointers only.** Update this session's own version pointers (memory, hub docs) to the live versions. Nothing else changes without the user.

6. **Report** in this order: what changed (dated), conflicts with this session's work (with the fix it implies), pointers synced. End with one next action.

## Gotchas
- Peer sessions edit the same Confluence page: always re-fetch and version-guard before any later push from this session.
- A decision in the log may have been reversed later the same day - read the whole dated chain, newest last.
- A memory pointer can be newer than the hub doc (or vice versa); trust the live system.
