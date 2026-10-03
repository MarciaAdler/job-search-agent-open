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

# Skip if this looks like a DarkWake (a brief background maintenance wake —
# no display, no user present) rather than a real wake. A DarkWake can last
# well under a minute, nowhere near enough for a multi-minute agent run
# before the system drops back to sleep and kills the connection mid-
# request. (This happened in production: a launchd check-in landed inside
# a ~2m45s DarkWake window, the run started, and claude -p got cut off with
# "Connection closed mid-response" the moment sleep resumed.)
# `UserIsActive` in `pmset -g assertions` reflects genuine HID (keyboard/
# trackpad) activity — it's 0 during DarkWake and 1 during a real wake or
# active login session. Treated as advisory, not a hard gate: if the field
# is missing/unparseable for any reason, fall through and let the
# caffeinate wrap below guard the run instead, rather than silently
# stalling forever on a parsing issue.
# Captured into a variable rather than piped straight into awk: with
# `pipefail` set, awk's early `exit` (it matches near the top of pmset's
# output, which can run much longer) can close the pipe before pmset
# finishes writing, so pmset gets SIGPIPE and the whole script dies via
# `set -e` before logging anything — happened in production, silently
# stopping check-ins for hours until diagnosed.
pmset_assertions="$(pmset -g assertions 2>/dev/null)"
user_is_active="$(awk '/^[[:space:]]*UserIsActive/{print $2; exit}' <<< "$pmset_assertions")"
if [ "$user_is_active" = "0" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') Skip — system is in DarkWake (UserIsActive=0), not a real wake. Will retry next check-in."
  exit 0
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
#
# caffeinate holds a no-idle-sleep assertion for the duration of this one
# command, releasing it automatically when claude exits either way. This is
# the second half of the DarkWake defense above: that check is only a
# point-in-time read at the top of the script, so this covers the system
# drifting back to sleep mid-run even if the check passed a moment earlier.
#
# set -e is suspended for just this call so a failure doesn't exit the
# script before we've had a chance to inspect it: an expired Claude Code
# login session (a keychain credential shared with interactive `claude`
# sessions; this script can't complete the browser-based re-auth itself)
# has happened in production and previously failed silently on every
# 15-minute check-in for up to ~2 days before being noticed. Distinguishing
# it lets us surface it loudly instead.
AUTH_FAILURE_SENTINEL=".auth-failure-notified-at"
set +e
claude_output="$(caffeinate -i -s claude -p "$(cat agent-prompt.md)" --dangerously-skip-permissions 2>&1)"
claude_exit=$?
set -e
echo "$claude_output"

if [ "$claude_exit" -ne 0 ]; then
  if grep -qi "OAuth session expired\|Failed to authenticate" <<< "$claude_output"; then
    echo "=== AUTH FAILURE: run did not complete — the Claude Code login session expired. Run '/login' in an interactive Claude Code session to fix; this script cannot do it unattended. ==="
    # Re-notify at most once every 4 hours so a persistent failure doesn't
    # spam a notification on every check-in until a human runs /login.
    last_notified_iso=""
    [ -f "$AUTH_FAILURE_SENTINEL" ] && last_notified_iso="$(cat "$AUTH_FAILURE_SENTINEL")"
    last_notified_epoch="$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$last_notified_iso" +%s 2>/dev/null || echo "")"
    hours_since_notify=999999
    [ -n "$last_notified_epoch" ] && hours_since_notify=$(( (now_epoch - last_notified_epoch) / 3600 ))
    if [ "$hours_since_notify" -ge 4 ]; then
      osascript -e 'display notification "Run /login in Claude Code to fix — the job search agent has been unable to run." with title "Job Search Agent: login expired"' 2>/dev/null || true
      date -u +"%Y-%m-%dT%H:%M:%SZ" > "$AUTH_FAILURE_SENTINEL"
    fi
  else
    echo "=== Run failed (non-auth error — see output above) ==="
  fi
  exit 1
fi

# Clear any pending auth-failure sentinel now that a run has actually
# succeeded, so a future failure notifies fresh instead of staying silent.
rm -f "$AUTH_FAILURE_SENTINEL"

# Only record success after claude -p exits 0.
date -u +"%Y-%m-%dT%H:%M:%SZ" > "$LAST_RUN_FILE"

echo "=== Run finished: $(date '+%Y-%m-%d %H:%M:%S') ==="
