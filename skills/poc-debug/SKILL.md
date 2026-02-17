---
name: poc-debug
description: POC debug and observation recording. Use when reporting errors, failures, observations, or test results during POC development.
---

# POC Debug + Observe

Unified debug intake and observation recording for iterative POC development. Handles both error diagnosis (with SDK log correlation) and neutral observation journaling.

## When to Use

- User pastes an error, stack trace, or failure description
- User reports a test result or observation (success or failure)
- User shares a screenshot of browser/terminal output
- User describes unexpected behavior during POC testing

**MANDATORY FIRST OUTPUT:**
```
POC :: DEBUG
```

## Context Sources

- `.logs/sdk.jsonl` — SDK instrumentation output (JSONL, one event per line)
- `docs/poc/DEV-LOG.md` — Append-only session journal
- `docs/requirement/REQUIREMENTS.md` — Requirement coverage reference
- Source files identified from error stack traces or event names

## Process

### 1. Classify Input

Determine if the user input is an **error** or an **observation**:

- **Error indicators:** stack traces, error codes, HTTP status codes (4xx/5xx), "error", "fail", "crash", "TypeError", "invalid_grant", "ECONNREFUSED", exception names
- **Screenshot input:** Describe what's visible, extract error text or status information, then classify
- **Otherwise:** Treat as observation

### 2A. Error Mode

1. **Read SDK logs:** Read `.logs/sdk.jsonl` — last 200 lines.
   - If user provides a timestamp, filter to events within 60 seconds of that timestamp
   - Focus on `error` and `warn` level events first, then trace the flow via `info` and `debug` events
   - If `.logs/sdk.jsonl` does not exist, note "SDK logs not available — diagnosing from error text alone" and continue

2. **Read prior context:** Read `docs/poc/DEV-LOG.md` — find the last `## Session:` heading, read from there to end of file
   - This avoids re-investigating known issues from prior sessions
   - If DEV-LOG.md does not exist, skip this step

3. **Identify source files:** Extract file paths from stack traces or infer from SDK event names:
   - `auth:*` events → auth flow files (route handlers, auth client config)
   - `discovery:*` / `jwks:*` → OIDC client internals
   - `session:*` → session store / cookie handling
   - `mcd:*` → domain resolver, multi-domain config
   - `http:*` → network layer / fetch wrappers
   - Read the identified source files

4. **Correlate and diagnose:**
   - Match SDK event timeline with the reported error
   - Identify the last successful event before failure
   - Produce: **root cause hypothesis** with specific evidence from logs/source

5. **Apply fix:** Edit the identified source file(s) with the proposed fix

6. **Record in DEV-LOG:** Append an observation entry (see format below) including:
   - The error description
   - Root cause diagnosis
   - Fix applied
   - Updated requirement status if applicable

### 2B. Observation Mode

1. **Append to DEV-LOG:** Add a structured observation entry (see format below)
2. **Update Status table:** Carry forward all previous requirement statuses, update the ones affected by this observation
3. **Flag insights:** If the observation contradicts a prior assumption or reveals something new, explicitly call it out and suggest the next action

### 3. DEV-LOG Entry Format

If `docs/poc/DEV-LOG.md` does not exist, create it with a top-level heading `# POC Development Log` before the first entry.

Check if there is already a session entry for today (same date). If so, append observations to that session's Observations section rather than creating a new session entry.

If creating a new session entry, append:

```markdown
---
## Session: {current ISO-8601 timestamp}
### Objective
{What the user is working on — infer from context or ask}

### Changes
- {file}: {what changed and why}

### Observations
- {Observation with specific data from logs/testing}

### Status
| Requirement | Status | Notes |
|-------------|--------|-------|
| {req} | {pass/fail/wip/untested} | {detail} |

### Blockers / Open Questions
- {Active blockers or open questions}

### Next Steps
- {What to try next based on current state}
---
```

**Status values:** `pass` (proven working), `fail` (proven broken), `wip` (partially working), `untested` (not yet attempted)

### 4. Output

- **Error mode:** Diagnosis summary, fix applied, files changed, DEV-LOG updated
- **Observation mode:** Observation recorded, status updated, any insights flagged

## Graceful Degradation

| Missing Resource | Behavior |
|-----------------|----------|
| `.logs/sdk.jsonl` | Skip log reading, diagnose from error text alone |
| `docs/poc/DEV-LOG.md` | Create it with first entry |
| `docs/requirement/REQUIREMENTS.md` | Omit Status table from DEV-LOG entry |
| Stack trace not available | Ask user for more context about what they were doing when the error occurred |

## Anti-Patterns

- Do NOT ask the user to paste logs if `.logs/sdk.jsonl` exists — read it directly
- Do NOT skip recording in DEV-LOG even if the fix seems trivial
- Do NOT overwrite previous DEV-LOG entries — always append
- Do NOT include PII, tokens, or secrets in DEV-LOG entries
