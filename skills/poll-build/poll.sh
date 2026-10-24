#!/bin/bash
# Poll CircleCI for the latest pipeline on a branch, play a sound on terminal state.
# Usage: poll.sh [branch] [repo-dir]
# ponytail: token read straight out of ~/.claude.json, no separate config file
set -uo pipefail

REPO_DIR="${2:-$PWD}"
BRANCH="${1:-$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)}"
SLUG=$(git -C "$REPO_DIR" remote get-url origin | sed -E 's#.*github.com[:/]##; s#\.git$##')
PROJECT="gh/$SLUG"
SOUND_OK="/System/Library/Sounds/Submarine.aiff"
SOUND_FAIL="/System/Library/Sounds/Basso.aiff"

TOKEN=$(python3 -c "
import json,os
d=json.load(open(os.path.expanduser('~/.claude.json')))
print(d['mcpServers']['circleci-mcp-server']['env']['CIRCLECI_TOKEN'])
")
[ -z "$TOKEN" ] && { echo "no CIRCLECI_TOKEN in ~/.claude.json"; exit 1; }

api() { curl -sS -H "Circle-Token: $TOKEN" "https://circleci.com/api/v2/$1"; }

echo "polling $PROJECT @ $BRANCH"
for i in $(seq 1 40); do
  PID=$(api "project/$PROJECT/pipeline?branch=$BRANCH" | python3 -c "
import json,sys
p=json.load(sys.stdin).get('items',[])
print(p[0]['id'] if p else '')
")
  if [ -z "$PID" ]; then
    echo "[$(date +%H:%M:%S)] no pipeline for $BRANCH yet"
  else
    read -r STATUS NAMES <<<"$(api "pipeline/$PID/workflow" | python3 -c "
import json,sys
w=json.load(sys.stdin).get('items',[])
s=[x['status'] for x in w]
term={'success','failed','error','canceled','not_run','failing'}
if not w: agg='pending'
elif any(x in ('failed','error','failing') for x in s): agg='failed'
elif all(x in term for x in s): agg='success' if all(x in ('success','not_run') for x in s) else 'done'
else: agg='running'
print(agg, ','.join(f\"{x['name']}={x['status']}\" for x in w))
")"
    echo "[$(date +%H:%M:%S)] poll $i: $STATUS  $NAMES"
    case "$STATUS" in
      success) afplay "$SOUND_OK"; afplay "$SOUND_OK"; echo "BUILD PASSED: $NAMES"; exit 0 ;;
      failed|done) afplay "$SOUND_FAIL"; afplay "$SOUND_FAIL"; echo "BUILD FAILED: $NAMES"; exit 1 ;;
    esac
  fi
  sleep 30
done
echo "timed out after 40 polls (~20 min)"
afplay "$SOUND_FAIL"
exit 2
