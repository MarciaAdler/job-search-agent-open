# Job Search Agent (Open Template)

An unattended, daily job-search agent that runs on [Claude Code](https://claude.com/claude-code)
and logs matching postings to a Notion database — scored and filtered
against *your* background, for *any* job title. It's not specific to any
one role; you tell it what you're looking for during setup.

The default company list (`companies.json`) is startup-focused, seeded from
five VC portfolio job boards (Lightspeed, Bessemer, Primary, 8VC, Wing) —
but it's just a starting point you extend as you go.

**Before you clone: pick a location outside `~/Desktop`, `~/Documents`, or
`~/Downloads`.** macOS blocks background processes (like the scheduled
agent) from touching files in those specific folders unless you grant
Full Disk Access through System Settings — a fiddly, easy-to-forget step.
Anywhere else under your home folder (e.g. `~/job-search-agent-open` or
`~/Projects/job-search-agent-open`) avoids the problem entirely. If you've
already cloned it into one of those folders, just move the whole folder
before running `/setup`.

## How this works

Most "search the web for jobs" approaches run into two problems: search
results are often stale (a listing closed weeks ago but is still indexed),
and many job platforms (Lever, Ashby, etc.) block automated page fetches
outright. This agent avoids both by calling each company's own ATS
(applicant tracking system) API directly — Greenhouse, Lever, and Ashby all
expose free, unauthenticated, structured JSON endpoints for exactly this.
A closed posting simply can't appear in that response, so there's no
separate "is this still open" check needed. Web search is used only as a
supplementary discovery pass for companies not yet in your list.

## Quickstart

1. Clone this repo.
2. Open it in Claude Code.
3. Run `/setup`. It will interview you about your target role, background,
   location/comp constraints, and known gaps, then generate your personal
   `profile.md` and walk you through connecting Notion and reviewing
   `companies.json`.
4. Test it manually (the setup command will remind you how).
5. Set up the scheduled run once you're happy with a test run — `/setup`
   creates a `launchd` LaunchAgent for you (see §4 for why this instead of
   cron).

Everything below is the same walkthrough in longer form, if you'd rather
do it by hand instead of via `/setup`.

## Files in this repo
- `profile.example.md` — template for your background/target role/
  preferences. `/setup` turns this into your personal `profile.md`
  (gitignored — it's your data, not part of the template).
- `companies.json` — the company list the agent checks directly via ATS
  API. Ships with 20 startup companies as a starting point; edit anytime.
- `agent-prompt.md` — the task the agent runs every day.
- `notion-database-id.example.txt` — template; `/setup` turns this into
  your personal `notion-database-id.txt` (gitignored).
- `run-agent.sh` — the script the scheduler actually calls. Self-gates on
  `.last-run-at` (gitignored — local run state, not template content) so
  it's safe to invoke frequently; only actually runs the agent if ≥20 hours
  have passed since the last success.
- `.claude/commands/setup.md` — the `/setup` command itself.

## 1. Create the Notion database
Create a new database (as a full-page database, not inline) with these properties:

| Property     | Type   |
|---|---|
| Job Title    | Title  |
| Company      | Text   |
| URL          | URL    |
| Salary       | Text   |
| Location     | Text   |
| Match score  | Number |
| Gaps         | Text   |
| Date Added   | Date   |
| Status       | Select (options: New, Reviewing, Applied, Rejected, Interviewing) |

Property names are matched exactly, including case — Notion won't stop you
from typing `Match Score` instead of `Match score`, but the agent will treat
that as a schema mismatch at runtime (it'll still write to whatever property
actually exists, but it'll flag the mismatch in every run's summary until
someone fixes it). `/setup` checks this for you automatically once Notion is
connected (§2); if you're setting this up by hand, compare your database's
actual property names against this table before your first run.

Copy the database ID into `notion-database-id.txt` (instructions are already
in `notion-database-id.example.txt` — it's the 32-character string in the
database's URL).

## 1a. Maintain your company list (`companies.json`)
The agent's primary source for new postings is direct calls to each
company's own ATS API — not web search. A direct API call returns only
currently open postings, with the full description included, straight
from the source.

`companies.json` is a flat list you maintain yourself:
```json
{"name": "Confido", "ats": "ashby", "token": "confido", "source": "Primary VC"}
```
The agent reads this file fresh every run and never edits it itself (it
will only ever suggest additions in its end-of-run summary, for you to add).

**To add a company**, you need its ATS platform and board token. Fastest way:
1. Find the company's careers page and see which ATS it redirects to
   (URL will contain `boards.greenhouse.io/<token>`, `jobs.lever.co/<token>`,
   or a company subdomain on `jobs.ashbyhq.com/<token>`).
2. Confirm the token works by opening the matching API URL directly in a
   browser — it should show raw JSON, not an error:
   - Greenhouse: `https://boards-api.greenhouse.io/v1/boards/<token>/jobs`
   - Lever: `https://api.lever.co/v0/postings/<token>?mode=json`
   - Ashby: `https://api.ashbyhq.com/posting-api/job-board/<token>`
3. Add a line to `companies.json` with that `ats` and `token`.

Not every company uses one of these three ATS platforms (Workday,
SmartRecruiters, BambooHR, and others don't have a simple public JSON
endpoint) — those companies just aren't candidates for this file. The
agent's supplementary `site:` searches (agent-prompt.md §3b) still cover
some of that ground, just with the staleness caveats noted there.

## 2. Connect Notion to Claude Code
Two options — pick one:

**Option A — Remote, OAuth (recommended, no token to manage):**
```bash
claude mcp add --transport http notion https://mcp.notion.com/mcp
```
Then inside Claude Code, run `/mcp`, select `notion`, and complete the OAuth
flow in the browser that opens. This handles token refresh automatically.

**Option B — Local, integration token:**
1. Go to https://www.notion.so/my-integrations → New integration → copy the
   token (starts with `ntn_` or `secret_`)
2. Open your job-tracking database in Notion → `•••` menu → **Connect to** →
   select your integration (this step is required — without it the
   integration can't see the database)
3. Add the server:
```bash
claude mcp add notion --env NOTION_TOKEN=ntn_your_token_here -- npx -y @notionhq/notion-mcp-server
```

Either way, run `/mcp` inside Claude Code once to confirm the `notion` server
shows as connected before you rely on the scheduled run.

## 3. Test it manually first
From this directory:
```bash
claude -p "$(cat agent-prompt.md)"
```
Run it interactively (without `--dangerously-skip-permissions`) the first
time so you can approve each tool call and confirm it's searching sensibly
and writing to the right database. Check the Notion table afterward. Once
you're happy with the output, move to scheduling it.

## 4. Schedule it with launchd (not cron)

**Why launchd instead of cron:** a fixed-clock-time cron job needs the Mac
to be fully awake at that exact minute, which turned out to be a deep
rabbit hole — macOS's overnight "DarkWake" maintenance cycles don't count
as awake (cron silently never fires), `pmset repeat wake` only reliably
produces a real wake on AC power (not battery), and even with a real wake,
a closed laptop lid without an external display drops straight back into
"Clamshell Sleep" within seconds — nowhere near enough time for a multi-
minute agent run. Three separate, genuinely obscure failure modes, all of
which look identical from the outside: no log, no error, nothing.

launchd sidesteps all three by not trying to force a wake at all. Instead,
`/setup` installs a LaunchAgent that checks in periodically (every 30
minutes) *while the machine is naturally awake* — at login, or whenever
you're already using it — and only actually runs the agent if `run-agent.sh`'s
own gate says ≥20 hours have passed since the last success. In practice
this means: open your laptop once a day, and within 30 minutes of your
first natural wake/login, it runs. Not at a fixed clock time, but reliably.

**`/setup` does this for you** (generates the plist with your actual paths,
loads it, removes any old crontab entry). To do it by hand instead:

1. Find your `claude` binary and make sure `run-agent.sh`'s `PATH` line
   includes its directory:
   ```bash
   which claude
   ```
   A background process (launchd or cron) doesn't inherit your full
   interactive-shell PATH, so if `claude` lives somewhere not already listed
   in `run-agent.sh`'s `export PATH=...` line, add it — otherwise the
   scheduled run fails with `claude: command not found` even though running
   the script by hand works fine.

2. Create `~/Library/LaunchAgents/com.jobsearchagent.daily.plist` (adjust
   the two path strings to wherever you cloned this repo):
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>Label</key>
       <string>com.jobsearchagent.daily</string>
       <key>ProgramArguments</key>
       <array>
           <string>/bin/bash</string>
           <string>/Users/you/job-search-agent-open/run-agent.sh</string>
       </array>
       <key>RunAtLoad</key>
       <true/>
       <key>StartInterval</key>
       <integer>1800</integer>
       <key>StandardOutPath</key>
       <string>/Users/you/job-search-agent-open/logs/launchd.log</string>
       <key>StandardErrorPath</key>
       <string>/Users/you/job-search-agent-open/logs/launchd.log</string>
   </dict>
   </plist>
   ```
   (`launchd.log` catches launchd-level startup failures only — the agent's
   actual output always goes to `logs/agent.log` via the script's own
   redirect, regardless of how it was invoked.)

3. Load it:
   ```bash
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.jobsearchagent.daily.plist
   ```
   `RunAtLoad` means this triggers an immediate check — harmless, since
   `run-agent.sh` will just skip if you tested manually within the last
   20 hours.

4. Verify:
   ```bash
   launchctl list com.jobsearchagent.daily
   ```
   Look for `"LastExitStatus" = 0`. If you see a nonzero value, check
   `logs/launchd.log` and `logs/agent.log` for what happened.

**If you already have a cron entry from an earlier setup**, remove it so
both don't fire:
```bash
crontab -l | grep -v run-agent.sh | crontab -
```

## 5. A note on `--dangerously-skip-permissions`
`run-agent.sh` uses this flag because a scheduled, unattended run has no
human present to approve tool calls interactively. It's reasonable here
because this is a single-
purpose project folder that only does web search + Notion writes — but the
flag also disables Claude Code's confirmation prompts for file edits and bash
commands generally. If you'd rather avoid it, pre-approve just the tools this
task needs in `~/.claude/settings.json` under `permissions.allow` (e.g.
`WebSearch`, `WebFetch`, and the `mcp__notion__*` tools) and drop the flag
from the script.

## 6. Ongoing maintenance
- Check `logs/agent.log` occasionally — the end-of-run summary will flag any
  schema mismatches, Notion auth failures, broken `companies.json` entries
  (token/ATS changed), or new companies it suggests adding.
- Update `profile.md` whenever your target role, comp, location rules, or
  experience changes — no code changes needed, it's read fresh every run.
- Grow `companies.json` over time (see §1a) — this is the highest-leverage
  way to improve result quality and freshness, more so than tuning the
  search queries themselves.
- If the table gets noisy, raise `MIN_MATCH_SCORE_TO_LOG` in profile.md.

## License
MIT — see `LICENSE`. Fork it, personalize it, use it for whatever job
search you're running.
