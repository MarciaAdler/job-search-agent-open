---
description: Interview the user about their background and target role, then generate their personal profile.md and walk through Notion + companies.json setup
---

You are setting up this job-search agent for a new user who just cloned the
repo. Your job in this turn is to turn the generic template files
(`profile.example.md`, `notion-database-id.example.txt`) into their
personal, working copies (`profile.md`, `notion-database-id.txt`), and make
sure `companies.json` reflects what they actually want searched.

Do this conversationally — don't dump a giant form at the user. Ask a few
questions at a time, use judgment about what's already been answered, and
use the AskUserQuestion tool for genuinely discrete choices (e.g. "keep /
trim / add to the default company list"). Free-text background and
experience don't fit multiple-choice — just ask directly and let them
write paragraphs.

## Step 1: Check for existing personalization
Check whether `./profile.md` already exists. If it does, tell the user and
ask whether they want to (a) start over, (b) update specific sections, or
(c) leave it alone and just handle Notion/companies.json setup instead.
Don't silently overwrite a file they may have already customized.

## Step 2: Gather target role and seniority
Ask what job title(s) they're searching for — get every variant they'd
accept (e.g. "Senior Software Engineer" AND "Staff Software Engineer" are
different searches, not the same one). Also ask their seniority floor
(e.g. "mid-level and up", "senior and up", "IC only, no management track")
and, if relevant, whether title variants like "X II" or "Senior X" at a
smaller company should count as equivalent scope — the more explicit they
are here, the better the agent's hard-filter judgment calls will be later.

## Step 3: Gather background
Ask for:
- A 2-4 sentence identity/background summary (years of experience,
  industries, what makes them a strong candidate specifically)
- Company stage preference (the default `companies.json` is startup-
  focused — confirm that's still the right fit, or note if they want a
  different stage mix)
- Culture-fit notes, if any
- 3-6 concrete, quantified achievement bullets for match reasoning — push
  back gently on vague ones ("experienced engineer" → ask for a number or
  a concrete project)

## Step 4: Gather constraints
Ask for:
- Location constraint, as specific as possible (remote/hybrid/onsite,
  which cities, any relocation willingness)
- Compensation target range and whether it's base-only or total comp
- Known gaps / watch-outs — things a job posting might require that they
  don't have (this is one of the most valuable sections since it drives
  the Gaps column the agent writes to Notion; push for specificity)
- Tools & competencies keyword list

## Step 5: Gather tuning preferences (use sensible defaults, don't belabor)
- MIN_MATCH_SCORE_TO_LOG (default 4)
- MAX_NEW_JOBS_PER_RUN (default 20)
- LOOKBACK_FOR_DEDUPE in days (default 21)

## Step 6: Write profile.md
Using `profile.example.md` as the structural template, write `./profile.md`
with everything gathered above filled in. Keep the same section headers so
`agent-prompt.md` (which reads this file) finds what it expects.

## Step 7: Notion setup
Check whether `./notion-database-id.txt` already exists and has a real ID
in it (not the placeholder). If not, walk the user through:
1. Creating a Notion database with these properties: Job Title (title),
   Company (text), URL (url), Salary (text), Location (text), Match Score
   (number), Gaps (text), Date Added (date), Status (select: New,
   Reviewing, Applied, Rejected, Interviewing).
2. Connecting Notion to Claude Code — either `claude mcp add --transport
   http notion https://mcp.notion.com/mcp` (OAuth, recommended) or a local
   integration token (see README.md §2 for both options in full).
3. Running `/mcp` to confirm the `notion` server shows connected.
4. Asking them to paste the database ID (the 32-character string in the
   database's URL), then writing it to `./notion-database-id.txt`.

## Step 8: companies.json
Tell the user `companies.json` ships with 20 startup companies (sourced
from Lightspeed, Bessemer, Primary, 8VC, and Wing portfolio job boards) as
a starting point. Ask if they want to:
- Keep it as-is
- Add companies now (if they give you names, look up each one's ATS
  platform and board token, then verify the token actually works by
  fetching the matching public API URL before adding it — see README.md
  §1a for the exact method. Never guess a token without verifying it.)
- Remove any that don't fit their target role/industry

## Step 9: Wrap up
Run `chmod +x run-agent.sh` yourself right now (safe, idempotent) — a repo
clone/download doesn't always preserve the execute bit, and a
non-executable `run-agent.sh` makes cron fail silently later with no log
and no obvious error. Don't skip this even if it looks fine; just run it.

Remind them to test manually before scheduling cron:
```
claude -p "$(cat agent-prompt.md)"
```
Run it interactively (without `--dangerously-skip-permissions`) the first
time so they can approve tool calls and confirm it's searching sensibly.
Point them at README.md §4 for the cron scheduling step once they're happy
with a test run.

If they mention they're on macOS (or you can tell from context/tooling),
proactively flag README.md §4a: macOS won't run cron jobs while the machine
is asleep, and its overnight "DarkWake" maintenance cycles don't count as
awake for this purpose — a Mac that's normally asleep at the scheduled
time will silently never run the job. Give them the fix directly rather
than waiting for them to hit it:
```
sudo pmset repeat wake MTWRFSU 07:55:00
```
(adjust the time to ~5 minutes before whatever cron schedule they choose).
This needs their own password at the `sudo` prompt, so tell them to run it
themselves — you can't run `sudo` for them. Offer to verify afterward with
`pmset -g sched` once they confirm they've run it.
