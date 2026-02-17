---
name: poc-status
description: POC state summary showing requirement coverage, blockers, and next steps. Use when asking about POC progress, starting a new session, or asking "where are we".
---

# POC Status

Single-command summary of current POC state: what's proven, what's broken, what's next.

## When to Use

- User asks "where are we", "what's the status", "what works"
- User starts a new session and needs context recovery
- User asks about progress or requirement coverage

**MANDATORY FIRST OUTPUT:**
```
POC :: STATUS
```

## Context Sources

- `docs/poc/DEV-LOG.md` — Session journal with Status tables
- `docs/requirement/REQUIREMENTS.md` — Full requirement list

## Process

1. **Read DEV-LOG:** Read `docs/poc/DEV-LOG.md`. Find the last `## Session:` heading. Extract:
   - Session timestamp
   - Objective
   - Status table (requirement coverage)
   - Blockers / Open Questions
   - Next Steps

2. **Read Requirements:** Read `docs/requirement/REQUIREMENTS.md`. Extract all requirement identifiers (FR-*, or table rows, or numbered items).

3. **Cross-reference:** Identify requirements present in REQUIREMENTS.md but absent from the DEV-LOG Status table — these are `untested`.

4. **Output the status report** in this format:

```
POC STATUS :: {project/feature name from DEV-LOG or directory name}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Last session: {timestamp from last ## Session heading}
Objective:    {objective from last session}

COVERAGE: {passed}/{total} requirements proven
  Pass:     {count} — {comma-separated list}
  WIP:      {count} — {comma-separated list}
  Failed:   {count} — {comma-separated list}
  Untested: {count} — {comma-separated list}

BLOCKERS:
  - {blocker from last session}

NEXT STEPS:
  - {next step from last session}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

5. **After the report:** If there are failed requirements or active blockers, briefly suggest which one to tackle first and why (based on dependency order or severity).

## Graceful Degradation

| Missing Resource | Behavior |
|-----------------|----------|
| `docs/poc/DEV-LOG.md` | Output: "No POC sessions recorded yet. Use /poc-debug to record your first observation or error." |
| `docs/requirement/REQUIREMENTS.md` | Show DEV-LOG status table as-is. Note: "Requirements doc not found — showing DEV-LOG status only." |
| DEV-LOG exists but has no Status table | Output last session's Objective, Changes, and Observations. Note: "No status table found — consider using /poc-debug to record a structured observation." |

## Anti-Patterns

- Do NOT modify any files — this is a read-only skill
- Do NOT re-read the entire DEV-LOG history — only the last session entry matters for current state
- Do NOT guess at requirement statuses — only report what's explicitly recorded
