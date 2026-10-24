---
name: poll-build
description: Poll CircleCI for the latest pipeline status on the current branch and play a sound when the build completes. Use when the user pushes code and wants to be notified when CI finishes.
---

# Poll Build

Poll CircleCI pipeline status for the current branch until it completes, then play a notification sound.

## Arguments

- `--bg` or `background`: Run polling in the background. Default is foreground with live status updates.

## Steps

1. Detect the current git branch and workspace root:
   ```bash
   git rev-parse --abbrev-ref HEAD
   git remote get-url origin
   pwd
   ```

2. Determine run mode:
   - If user passed `--bg` or `background`: run the entire poll loop via Bash with `run_in_background: true`
   - Otherwise: run in foreground with live status updates

3. Get initial pipeline status using the `mcp__circleci-mcp-server__get_latest_pipeline_status` tool with Option 3 (project detection):
   - `workspaceRoot`: result of `pwd`
   - `gitRemoteURL`: result of `git remote get-url origin`
   - `branch`: result of `git rev-parse --abbrev-ref HEAD`

4. Poll loop — repeat every **30 seconds** until a terminal state is reached:
   - Call `mcp__circleci-mcp-server__get_latest_pipeline_status` with the same params
   - Print a one-line status update each poll (e.g. `[12:34:05] Pipeline: running...`)
   - Terminal states: `success`, `failed`, `error`, `canceled`, `not_run`
   - Use `sleep 30` between polls via Bash
   - Maximum 40 polls (~20 min). If exceeded, notify user and stop.

5. On terminal state, play a notification sound **twice**:
   - On **success**: `Submarine.aiff`
   - On **failure/error/timeout**: `Basso.aiff`

   Do not use `Glass.aiff` or `Ping.aiff` — those are the global Stop/Notification hook sounds and would be mistaken for a normal turn ending.

6. Report final status to the user with a summary of what passed/failed.

## Background mode

MCP tools are unavailable inside a background Bash process, so background mode uses the bundled script instead:

```bash
~/.claude/skills/poll-build/poll.sh <branch> <repo-dir>
```

Run it with `run_in_background: true` and a long `timeout` (e.g. 1300000). It derives the CircleCI project slug from `git remote get-url origin`, reads `CIRCLECI_TOKEN` from `~/.claude.json` (`mcpServers.circleci-mcp-server.env`), and plays the sound itself on completion. Tail the task output file to report interim status.

## Notes

- Foreground mode uses the CircleCI MCP server; background mode uses `poll.sh` + the CircleCI v2 API directly
- Sound playback uses macOS `afplay` — works on macOS only
