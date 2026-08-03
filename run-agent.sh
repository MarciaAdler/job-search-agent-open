#!/bin/bash
# Daily job search agent — invoked by launchd on login/wake (see the
# LaunchAgent plist /setup generates), not by a fixed-clock-time scheduler.
# This script gates itself: it only actually runs the agent if enough time
# has passed since the last successful run, so it's safe to invoke this
# frequently (e.g. every 30 minutes while the machine is awake) without
# spamming runs.
set -euo pipefail

# launchd/cron run with a minimal PATH — extend it so `claude` and
# `node`/`npx` resolve. IMPORTANT: run `which claude` yourself and make sure
# its directory is in this list — a missing entry here is a common cause of
# "claude: command not found" when this script is invoked by launchd/cron
# even though it works fine when you run it by hand (your interactive shell
# has a fuller PATH than a background process does).
export PATH="$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:$HOME/.claude/bin:$HOME/.npm-global/bin:$PATH"

cd "$(dirname "$0")"

# Self-contained logging: append everything from here on to logs/agent.log,
# regardless of how this script was invoked (launchd, cron, or by hand).
mkdir -p logs
exec >> logs/agent.log 2>&1

MIN_HOURS_BETWEEN_RUNS=20
LAST_RUN_FILE=".last-run-at"

now_epoch="$(date +%s)"
have_prior_run=false
last_run_iso=""
elapsed_hours=0
if [ -f "$LAST_RUN_FILE" ]; then
  last_run_iso="$(cat "$LAST_RUN_FILE")"
  last_run_epoch="$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$last_run_iso" +%s 2>/dev/null || echo "")"
  if [ -n "$last_run_epoch" ]; then
    have_prior_run=true
    elapsed_hours=$(( (now_epoch - last_run_epoch) / 3600 ))
  fi
fi

if [ "$have_prior_run" = true ] && [ "$elapsed_hours" -lt "$MIN_HOURS_BETWEEN_RUNS" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') Skip — only ${elapsed_hours}h since last run (need ${MIN_HOURS_BETWEEN_RUNS}h). Last run: ${last_run_iso}"
  exit 0
fi

if [ ! -f profile.md ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') profile.md not found — run '/setup' in Claude Code from this directory first." >&2
  exit 1
fi

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
if [ "$have_prior_run" = true ]; then
  echo "=== Run started: $TIMESTAMP (${elapsed_hours}h since last run: $last_run_iso) ==="
else
  echo "=== Run started: $TIMESTAMP (no prior run recorded — first run) ==="
fi

# --dangerously-skip-permissions is required for a fully unattended run
# (there's no human to approve tool calls interactively). Only use this in a
# project directory you trust, since it also skips confirmation on file edits.
# If you'd rather not use it, see the README for the allowlisted-tools
# alternative in ~/.claude/settings.json.
claude -p "$(cat agent-prompt.md)" --dangerously-skip-permissions

# Only record success after claude -p exits 0 (set -e means a failure above
# skips this line entirely, so a failed run gets retried next check rather
# than being treated as done).
date -u +"%Y-%m-%dT%H:%M:%SZ" > "$LAST_RUN_FILE"

echo "=== Run finished: $(date '+%Y-%m-%d %H:%M:%S') ==="
