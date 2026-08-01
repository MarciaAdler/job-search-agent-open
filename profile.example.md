# Candidate Profile — Job Matching Reference

> This file is what the agent scores every job posting against. It is
> read fresh on every run, so edits take effect the next time the agent
> runs — no code changes needed.
>
> If you're setting this up for the first time, run `/setup` in Claude Code
> instead of editing this by hand — it will interview you and generate a
> real `profile.md` from this template. This file (`profile.example.md`)
> is the template; `profile.md` (gitignored) is your personal copy.

## Identity
[2-4 sentences: your background, years of experience, industries you've
worked in, and your signature strength as a candidate — the thing that
makes you stand out relative to other applicants for your target role.]

## Target Role
- Job title(s)/keywords to search for: [list every title variant you'd
  accept, e.g. "Senior Software Engineer", "Staff Software Engineer",
  "Software Engineer III" — the agent matches postings against these]
- Seniority level: [e.g. "Mid-level and above", "Senior and above",
  "IC only, no people management" — be explicit about what does NOT count]
- Company stage: [e.g. "primarily startups/smaller companies" — this
  should generally line up with the kind of companies in companies.json]
- Culture fit: [e.g. "fast-moving, low-hierarchy, high ownership" — used
  as color when scoring, not a hard filter]

## Location
- [Your location constraint, as specific as possible — e.g. "Remote (US)
  OR Hybrid/Onsite specifically in Austin, TX" or "Onsite in Boston,
  willing to relocate for the right role". This is a hard filter — the
  agent rejects anything that doesn't match.]

## Compensation
- Target: $[X]–$[Y] [base/total comp — say which]. [Any notes on
  equity/bonus flexibility.]

## Core Experience Highlights
[Bullet list of concrete achievements, projects, and skills the agent
should use for match reasoning — the more specific and quantified, the
better the scoring will be. Weak: "Experienced engineer." Strong: "Led
migration of a 200k-LOC monolith to microservices, cutting p95 latency
40%."]
-
-
-

## Known Gaps / Watch-outs
Flag these explicitly in the "Gaps" column whenever a posting calls for
them — this is one of the most useful sections, since it lets the agent
warn you about real risks instead of generic hedging:
-
-

## Tools & Competencies (for keyword matching)
[Comma-separated list of tools, languages, frameworks, methodologies —
whatever's relevant to your target role.]

## Agent Tuning
- MIN_MATCH_SCORE_TO_LOG = 4   (jobs scoring below this are skipped entirely —
  raise this if the Notion table gets too noisy)
- MAX_NEW_JOBS_PER_RUN = 20    (safety cap so one run doesn't flood the table)
- LOOKBACK_FOR_DEDUPE = 21 days (how far back to check existing Notion entries
  before treating a listing as new)
---
*Edit this file (or re-run `/setup`) whenever your background, preferences,
or comp target change — the agent reads it fresh on every run, so updates
take effect the next morning.*
