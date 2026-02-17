---
name: poc-checkpoint
description: Create a git checkpoint commit with structured session context from DEV-LOG. Use when saying "checkpoint", "save progress", or at the end of a productive POC session.
---

# POC Checkpoint

Create a meaningful git commit that captures session context — not just a code diff, but what was proven, what failed, and what's next.

## When to Use

- User says "checkpoint", "commit", "save progress"
- End of a productive POC session
- After a significant milestone (requirement proven, major fix applied)

**MANDATORY FIRST OUTPUT:**
```
POC :: CHECKPOINT
```

## Context Sources

- `docs/poc/DEV-LOG.md` — Current session data for commit message
- `git status` — Changed files

## Process

1. **Read session context:** Read `docs/poc/DEV-LOG.md`. Find the last `## Session:` heading. Extract:
   - Session timestamp
   - Objective
   - Status table (to summarize proven/remaining)
   - Blockers

2. **Check git status:** Run `git status` to identify changed files.

3. **If no changes exist:** Inform the user "No changes to commit" and stop. Do NOT create an empty commit.

4. **Stage files selectively:**

   | Category | Action |
   |----------|--------|
   | `docs/poc/DEV-LOG.md` | Always stage if changed |
   | `docs/**/*.md` | Always stage if changed |
   | `poc/**` (POC app source) | Always stage if changed |
   | SDK source directories (`src/`, `next/src/`, etc.) | Always stage if changed |
   | `.logs/`, `.env*`, `node_modules/` | NEVER stage |
   | `*.local`, `*.secret`, credentials files | NEVER stage |
   | Files outside expected directories | Ask user before staging |

5. **Compose commit message** from DEV-LOG session data:

   ```
   poc: {one-line summary of session objective or main achievement}

   Session: {ISO-8601 timestamp}
   Objective: {from DEV-LOG}

   Proven:
   - {requirements with status=pass, from Status table}

   Remaining:
   - {requirements with status=wip/fail/untested}

   Blockers:
   - {from Blockers section, or "None" if empty}
   ```

6. **Create the commit** using the composed message.

7. **Output:** Commit hash, number of files committed, summary of what was included.

## Graceful Degradation

| Missing Resource | Behavior |
|-----------------|----------|
| `docs/poc/DEV-LOG.md` | Use a generic commit message: `poc: checkpoint — no session context available`. Warn user: "Consider using /poc-debug to record observations before checkpointing." |
| No Status table in DEV-LOG | Omit Proven/Remaining sections from commit message. Use Objective and Observations instead. |
| No changes to commit | Inform user, do not create empty commit |

## Anti-Patterns

- Do NOT stage `.env*` files, credentials, or `.logs/` directory
- Do NOT create empty commits
- Do NOT amend previous commits — always create new commits
- Do NOT push to remote — checkpoint is local only
- Do NOT skip reading DEV-LOG — the structured commit message is the primary value of this skill
