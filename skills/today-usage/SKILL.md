---
name: today-usage
description: Show today's Claude Code token usage and USD cost, local midnight to now. Use when the user says "today-usage", "today's usage", "how much did I spend today", "tokens today", "cost today", or asks for today's token/money spend.
---

Run, then show the table as-is plus one line: total tokens and cost.

```bash
TZ_NAME=$(readlink /etc/localtime | sed 's#.*zoneinfo/##'); D=$(date +%Y%m%d)
npx -y ccusage@latest daily --since "$D" --until "$D" --timezone "$TZ_NAME" --breakdown
```

- Cost is ccusage's API-price estimate from local `~/.claude/projects` logs, not a billed amount.
- Only this machine's sessions are counted.
