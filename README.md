# Job Search Agent (Open Template)

An unattended, daily job-search agent that runs on [Claude Code](https://claude.com/claude-code)
and logs matching postings to a Notion database — scored and filtered
against *your* background, for *any* job title. It's not specific to any
one role; you tell it what you're looking for during setup.

The default company list (`companies.json`) is startup-focused, seeded from
five VC portfolio job boards (Lightspeed, Bessemer, Primary, 8VC, Wing) —
but it's just a starting point you extend as you go.

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
5. Schedule it with cron once you're happy with a test run.

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
- `run-agent.sh` — the script cron actually calls.
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
| Match Score  | Number |
| Gaps         | Text   |
| Date Added   | Date   |
| Status       | Select (options: New, Reviewing, Applied, Rejected, Interviewing) |

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
shows as connected before you rely on the cron job.

## 3. Test it manually first
From this directory:
```bash
claude -p "$(cat agent-prompt.md)"
```
Run it interactively (without `--dangerously-skip-permissions`) the first
time so you can approve each tool call and confirm it's searching sensibly
and writing to the right database. Check the Notion table afterward. Once
you're happy with the output, move to scheduling it.

## 4. Schedule it with cron
Edit your crontab:
```bash
crontab -e
```
This opens an editor (often vim) — type your line inside it, don't pass it
as an argument to `crontab -e` on the command line. Add (adjust the path to
wherever you cloned this repo):
```
0 8 * * * /Users/you/job-search-agent-open/run-agent.sh >> /Users/you/job-search-agent-open/logs/agent.log 2>&1
```
This runs every day at 8am, including weekends. Use `0 8 * * 1-5` instead
for weekdays only.

If you hit a "bad minute" or similar parse error, it's almost always a
stray character from copy-pasting into the editor. The more reliable path:
write the line to a plain text file with a real text editor, then run
`crontab <path-to-file>` to install it directly, avoiding the interactive
editor entirely.

Create the log folder if it doesn't exist:
```bash
mkdir -p /Users/you/job-search-agent-open/logs
```

## 4a. macOS: make sure the job can actually fire
Two macOS-specific gotchas caused a scheduled run to silently do nothing —
no log file, no new Notion entries, no error anywhere obvious. Both are
worth ruling out before you trust the schedule:

**1. `run-agent.sh` must be executable.** Cloning or downloading a repo
doesn't always preserve the execute bit. Check with:
```bash
ls -la run-agent.sh
```
You want to see `-rwxr-xr-x` (an `x` in there somewhere). If it's
`-rw-r--r--` instead, fix it with:
```bash
chmod +x run-agent.sh
```
If this is missing, cron fails with "permission denied" — but since that
error happens *before* the script's own log-redirect logic runs, you may
not see it anywhere except by testing manually.

**2. macOS won't run cron jobs while asleep — and "DarkWake" doesn't count.**
Overnight, Macs cycle through brief low-power "DarkWake" states for
background maintenance (Spotlight, Mail, iCloud sync) and go right back to
sleep. Cron jobs do **not** run during DarkWake; they need a real, full
wake. If your Mac is normally asleep at your scheduled time (lid closed,
no reason to be awake), the job will never fire, and there will be zero
trace of it anywhere.

The fix is to schedule an actual wake a few minutes before your cron time:
```bash
sudo pmset repeat wake MTWRFSU 07:55:00
```
(Adjust the time to ~5 minutes before whatever you put in your crontab.
`MTWRFSU` = every day; drop days you don't need, e.g. `MTWRF` for weekdays
only — but match whatever schedule you used in cron.) This requires your
Mac login password at the `sudo` prompt (no visible typing feedback — that's
normal). Verify it took with:
```bash
pmset -g sched
```
You should see `repeating wake at 7:55AM every day` (or your chosen time).

**How to tell which problem you have, if either:** run the script directly
once, with the machine awake, using the exact same redirect cron would use:
```bash
./run-agent.sh >> logs/agent.log 2>&1
```
If this fails immediately with "permission denied," it's #1. If it runs
fine manually but the scheduled run never produces a log entry, it's #2 —
check `pmset -g log | grep -E "Sleep|Wake"` around your scheduled time to
confirm the machine was actually asleep.

## 5. A note on `--dangerously-skip-permissions`
`run-agent.sh` uses this flag because cron has no human present to approve
tool calls interactively. It's reasonable here because this is a single-
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
