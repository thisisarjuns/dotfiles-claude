#!/usr/bin/env bash
# SessionStart hook: commit + push any pending ~/.claude config changes.
set -uo pipefail

REPO="$HOME/.claude"
cd "$REPO" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

git add -A
git diff --cached --quiet && exit 0 # clean, nothing to sync

# The .gitignore allowlist bounds what is tracked, but a skill or agent file could still
# carry a token. Never auto-push a credential: unstage and report instead.
if git diff --cached | grep -qE 'sk-ant-[A-Za-z0-9]|gh[pos]_[A-Za-z0-9]{20}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|xox[bp]-[0-9]'; then
  git reset -q
  echo '{"systemMessage":"claude-sync: credential pattern in pending changes - NOT committed. Inspect: git -C ~/.claude diff"}'
  exit 0
fi

n=$(git diff --cached --name-only | wc -l | tr -d ' ')
git commit -qm "auto: config sync $(date '+%Y-%m-%d %H:%M')" || exit 0

if git push -q 2>/dev/null; then
  echo "{\"systemMessage\":\"claude-sync: pushed $n file(s) to dotclaude\"}"
else
  echo "{\"systemMessage\":\"claude-sync: committed $n file(s) but push failed - run: git -C ~/.claude push\"}"
fi
