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

## Step 0: Check the folder location (macOS only)
If running on macOS, check whether the current directory is inside
`~/Desktop`, `~/Documents`, or `~/Downloads`. If it is, warn the user
clearly: macOS blocks background processes (the scheduled agent) from
touching files in those folders unless Full Disk Access is explicitly
granted via System Settings, which is fiddly and easy to get wrong. Ask if
they want to move the whole folder now to somewhere else under their home
directory (e.g. `~/job-search-agent-open`) before continuing — if so, move
it and continue setup from the new location. If they decline, proceed but
remind them again at Step 9 before setting up the scheduled run.

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
   Company (text), URL (url), Salary (text), Location (text), Match score
   (number), Gaps (text), Date Added (date), Status (select: New,
   Reviewing, Applied, Rejected, Interviewing).
2. Connecting Notion to Claude Code — either `claude mcp add --transport
   http notion https://mcp.notion.com/mcp` (OAuth, recommended) or a local
   integration token (see README.md §2 for both options in full).
3. Running `/mcp` to confirm the `notion` server shows connected.
4. Asking them to paste the database ID (the 32-character string in the
   database's URL), then writing it to `./notion-database-id.txt`.
5. Once connected, fetch the actual database schema via the Notion MCP tools
   and compare its property names against the table in `agent-prompt.md`
   §7 (Job Title, Company, URL, Salary, Location, Match score, Gaps, Date
   Added, Status). Notion doesn't enforce a naming convention, so it's easy
   to end up with e.g. `Match Score` instead of `Match score` even when
   following this guide exactly. Property names are matched literally at
   runtime, so any mismatch here means every future run flags it in its
   summary instead of just working. Don't ask the user to go rename
   anything in Notion — their database is the source of truth. Instead,
   edit `agent-prompt.md`'s schema table in this project's copy so it
   matches their actual property names exactly, then confirm back to the
   user what (if anything) you changed.

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

## Step 8a: (Optional) speedrun-talent MCP server
Ask if they're targeting startup roles and want to also pull from the a16z
speedrun talent network's jobs board (see README.md §1b and
`agent-prompt.md` §3d). This is optional — if they don't want it or don't
have it connected, skip and move on; the agent runs fine without it. If
they do want it, point them at README.md §1b to connect the MCP server,
then confirm with `/mcp` that it's showing as connected before continuing.
Mention explicitly that two of its tools (`express_interest`,
`join_network`) register real interest on their behalf and the agent never
calls them unattended — it only flags candidates in its summary.

## Step 9: Wrap up
Run `chmod +x run-agent.sh` yourself right now (safe, idempotent) — a repo
clone/download doesn't always preserve the execute bit, and a
non-executable `run-agent.sh` fails silently later with no log and no
obvious error. Don't skip this even if it looks fine; just run it.

Remind them to test manually first:
```
claude -p "$(cat agent-prompt.md)"
```
Run it interactively (without `--dangerously-skip-permissions`) the first
time so they can approve tool calls and confirm it's searching sensibly.

## Step 10: Set up the scheduled run (launchd, not cron)
Once they're happy with a manual test, set up the LaunchAgent yourself
rather than just pointing at docs — this is the part most likely to go
wrong if left to manual copy-paste. See README.md §4 for the full
rationale (short version: fixed-clock-time cron ran into three separate
macOS sleep/wake failure modes that all look identical — no log, no error,
nothing; launchd's periodic-check-while-naturally-awake model sidesteps
all three, and `run-agent.sh` itself guards against a fourth — a check-in
landing inside a too-short DarkWake — via a `UserIsActive` check plus a
`caffeinate` wrap around the actual run).

**Before loading the LaunchAgent, confirm the Step 9 manual test has fully
finished** — check `logs/agent.log` for its `=== Run finished ===` line, not
just that it started. `RunAtLoad` (below) fires an immediate check the
moment the LaunchAgent loads, and if a manual run is still in flight at that
exact moment, both can end up running concurrently and racing on the same
Notion writes. If unsure, just wait a minute and check the log before
proceeding.

1. Run `which claude` and check its directory is included in
   `run-agent.sh`'s `export PATH=...` line. If not, add it — a background
   process doesn't inherit the user's full interactive-shell PATH, and a
   missing entry here causes `claude: command not found` at schedule time
   even though manual runs work fine.
2. Write `~/Library/LaunchAgents/com.jobsearchagent.daily.plist` (and a
   copy in the project folder for reference) using the exact absolute path
   to this project's `run-agent.sh` and `logs/launchd.log`. Use the plist
   template in README.md §4 as the structure — `Label`
   `com.jobsearchagent.daily`, `RunAtLoad` true, `StartInterval` 900 (15
   minutes — see README.md §4 for why not longer: a 30-minute interval means
   up to a 30-minute wait after opening the laptop before the first
   check-in, which is a worse experience than it needs to be for something
   meant to just quietly run once a day).
3. Validate it with `plutil -lint`, then load it:
   ```
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.jobsearchagent.daily.plist
   ```
4. Check if an old crontab entry exists from a previous setup attempt and
   remove it so both schedulers don't fire:
   ```
   crontab -l | grep -v run-agent.sh | crontab -
   ```
5. Verify: `launchctl list com.jobsearchagent.daily` should show
   `"LastExitStatus" = 0`. `RunAtLoad` means loading it triggers an
   immediate check — this will just skip harmlessly if they tested manually
   within the last 20 hours (check `logs/agent.log` for a "Skip" line to
   confirm it ran cleanly rather than erroring).
6. Tell the user plainly: after this, opening the laptop doesn't run the
   agent instantly — expect roughly 15 minutes before the next check-in
   lands during a real wake and runs it (see README.md §4). If they want a
   run right now instead of waiting, they can always run `./run-agent.sh` or
   `claude -p "$(cat agent-prompt.md)"` directly.
