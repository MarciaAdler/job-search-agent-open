#!/bin/bash
# Daily job search agent — invoked by cron.
set -euo pipefail

# cron runs with a minimal PATH — extend it so `claude` and `node`/`npx` resolve.
# Adjust these to match `which claude` / `which node` on your machine.
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.claude/bin:$HOME/.npm-global/bin:$PATH"

cd "$(dirname "$0")"

if [ ! -f profile.md ]; then
  echo "profile.md not found — run '/setup' in Claude Code from this directory first." >&2
  exit 1
fi

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
echo "=== Run started: $TIMESTAMP ==="

# --dangerously-skip-permissions is required for a fully unattended cron run
# (there's no human to approve tool calls interactively). Only use this in a
# project directory you trust, since it also skips confirmation on file edits.
# If you'd rather not use it, see the README for the allowlisted-tools
# alternative in ~/.claude/settings.json.
claude -p "$(cat agent-prompt.md)" --dangerously-skip-permissions

echo "=== Run finished: $(date '+%Y-%m-%d %H:%M:%S') ==="
