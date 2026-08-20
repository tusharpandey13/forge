---
name: forge
description: Dispatcher-based orchestrator for forge development workflow. Manages state, dispatches phases to task agents, tracks progress, and handles cascade detection. Use when starting features, checking status, or progressing through phases.
license: Proprietary
metadata:
  author: Auth0 SDKs Team <sdks@auth0.com>
---

# Forge — Orchestrator (Thin Router)

Orchestrator skill. Parses intent, applies policy, delegates all deterministic ops to the exec layer via `forge <verb>`. No pseudocode here — deterministic flows live in `bin/`.

## Key Design Principles

1. **State as Source of Truth:** `.forge/state.json` (machine-readable)
2. **Dispatcher Model:** Non-interactive phases run as background task agents; orchestrator displays status
3. **Hardened Git:** Defensive initialization isolates from user config (no GPG, no hooks) — `forge init` handles this
4. **Feature Namespacing:** All artifacts under `.forge/features/<feature-slug>/`
5. **Mandatory Status Display:** Bare `/forge` always runs `forge status` first (NFR-4)
6. **Cascade Detection:** After artifact changes, invalidate downstream phases via `forge invalidate-downstream`
7. **Anti-Phase-Jump Enforcement:** Forge NEVER permits skipping phases *within a chosen track*. Once a track is selected (Standard 12-phase or Lite 4-stage), all its stages run in strict order. No skipping, no improvised fast-paths mid-track.
8. **Scope-Adaptive Track Selection:** At feature creation, Forge selects a track by scope. Small, well-bounded tasks may run the **Lite Lane** (4 stages) instead of the full 12-phase pipeline. Track choice is explicit, gated by hard criteria, and user-confirmed. (See **Scope-Adaptive Lite Lane** below.)
9. **Caveman-Ultra Internal Artifacts:** All internal Forge artifacts are written in caveman-ultra to minimize tokens. Product code and user-facing docs are ALWAYS normal prose. (See **Caveman-Ultra Internal Artifacts** below.)

**References:**
- See [state-schema.md](./references/state-schema.md) for complete state.json structure
- See [cascade-detector.md](./references/cascade-detector.md) for dependency graph and invalidation logic
- See [git-hardening.md](./references/git-hardening.md) for defensive git operations
- See [task-agent-prompt-template.md](./references/task-agent-prompt-template.md) for prompt construction

## When to Use

- User types `/forge` or says "forge"
- User is starting a new feature
- User asks about workflow phases or status
- User needs to progress to next phase
- User wants to check phase timeline or review findings

## Exec-Layer Entrypoint

All deterministic ops go through a single dispatcher. Locate it relative to this SKILL.md:

```
FORGE_BIN="<skill_dir>/bin/forge"
# <skill_dir> = directory containing this SKILL.md (resolved once at runtime)
```

Invocation pattern: `$FORGE_BIN <verb> [args...]`

Available verbs: `init` | `status` | `slice` | `merge` | `save` | `mark-complete` | `invalidate-downstream` | `repair` | `ref` | `archive` | `ghost-snapshot` | `ghost-diff` | `ghost-guard` | `commit-phase` | `log-query` | `rollback` | `metadata` | `autowrite-phase` | `cascade-fix` | `resume` | `features`

Never invoke `bin/lib/*.sh` directly. Workers never read `state.json` directly — only via `forge slice` / `forge ref`.

## Dispatch Rule

- **Bare `/forge`** (no verb): run `forge status`, then proceed to Step 3 (nudge).
- **`/forge <verb>`** (rollback, cascade-fix, etc.): skip decorative timeline, go straight to the action.
- **Continue/resume intent** — user says "continue/resume/pick up/keep working on \<feature\>" (any phrasing naming a past feature, active OR completed): run `forge resume "<feature words>"`. It fuzzy-matches the feature across ALL statuses and prints status, last carry_forward, open todos, and a suggested next action. Act on that:
  - If it resolves to an ACTIVE feature with a pending phase → resume at that phase.
  - If it resolves to a COMPLETED feature with open todos → surface the todos and offer to start a follow-up feature seeded with them (do NOT silently reactivate a completed feature).
  - If ambiguous (multiple candidates printed) → ask the user which slug.
  This is the path for "let's continue X" — never make the user hand-run scripts or pass state paths.
- **Vague/descriptive resume intent** — resume phrasing with NO clear feature name (e.g. "there was a task where I made forge better", "the thing about tokens", "that performance work") OR when `forge resume <words>` returns no-match or ambiguous: use `forge features` as a cheap semantic catalog to reason over internally:
  1. Run `forge features` — read the compact catalog (slug, name, status, description, phase_progress, open_todo_count).
  2. Reason over descriptions BY MEANING (not string overlap) — pick the single best semantic match.
  3. Propose it to the user: "You mean **\<name\>** [\<slug\>]? (y/n)" — include 1-2 close alternates only if genuinely ambiguous.
  4. On confirmation, run `forge resume <slug>` and act on its output as above.
  **Rule:** the SCRIPT lists; the AGENT matches semantically. Never dump the full catalog to the user — reason over it internally and present only the best match (+ alternates when needed).

Determine invocation mode before Step 0.

## On Trigger: Main Orchestrator Flow

### Step 0: Git Guard (Every Invocation)

On EVERY `/forge` trigger, apply defensive git config:

```bash
if [[ -d .forge/.git ]]; then
    git -C .forge config commit.gpgsign false
    git -C .forge config core.hooksPath /dev/null
    git -C .forge config tag.gpgsign false
    git -C .forge config user.name "forge"
    git -C .forge config user.email "forge@local"
fi
```

Rationale: git config can revert to system defaults over time. Idempotent, ~100ms.

### Step 1: Workspace Initialization

If `.forge/` directory NOT found:

```
→ forge init
```

`forge init` creates directories, initializes the forge git repo with hardened config, writes `state.json` (v2), and commits the initial state. Output confirms workspace created. Next: run config detection (Step 4) if `.forge/FORGE-CONFIG.md` missing.

If `.forge/` found and `state.json` corrupted: offer recovery from last forge git commit:
```bash
git -C .forge show HEAD:state.json > .forge/state.json
```

### Step 2: Status (Mandatory for bare `/forge`)

```
→ forge status
```

`forge status` reads the active-feature thin-index slice and renders the phase timeline. If no active feature, outputs `FORGE :: NO ACTIVE FEATURE` and returns. For `/forge <verb>`, skip this step.

### Step 3: Dispatch or Nudge

Obtain current state from the slice (never raw state.json):

```
→ forge slice --json
```

Use `slice.track` to determine track-relative constants:
- `max_stage` = 4 (lite) | 12 (standard)
- `REVIEW_STAGES` = [4] (lite) | [3,5,7,9,11] (standard)
- `stage_word` = "Stage" (lite) | "Phase" (standard)

**Anti-phase-jump check (CRITICAL ORCHESTRATOR RULE):** If user requests a phase and any prerequisite is not approved/completed, REFUSE:

```
OUTPUT: "❌ PHASE JUMP BLOCKED"
OUTPUT: "Forge policy: NO PHASE SKIPPING, regardless of task size"
OUTPUT: "Blocker: [stage_word] <N> (<name>) is <status>, not approved"
OUTPUT: "Next: Complete [stage_word] <N> first"
RETURN
```

**By current phase status:**

| Status | Action |
|--------|--------|
| `pending` (phase 1) | Nudge: "Next: Start [stage_word] 1 — [name]" |
| `pending` (phase > 1) | Block: list incomplete prerequisites per anti-phase-jump check |
| `in_progress` | Poll for completion (see **Polling** below) |
| `completed` (review stage in REVIEW_STAGES) | Read gate from `→ forge ref <slug> <phase> --print`; show gate result (PASS/FAIL or ok-to-merge/needs-fix); nudge approve or iterate |
| `completed` (non-review) | Nudge: "Proceed to next [stage_word]" |
| `approved` (phase < max_stage) | Nudge: "Start [stage_word] <next> — <name>" |
| `approved` (phase == max_stage) | "Feature complete! All [max_stage] [stage_word]s approved." |
| `failed` | Show review findings from `→ forge ref <slug> <phase> --print`; nudge fix and retry |
| `invalidated` | Nudge: "Re-run this phase or use `forge cascade-fix`" |

### Step 4: Config Initialization (if needed)

Called once when `.forge/FORGE-CONFIG.md` doesn't exist. Detect codebase conventions by sampling 10+ source files:

1. Primary language + framework
2. Naming conventions (camelCase/snake_case/etc., confidence ≥80% = high)
3. Error handling patterns (try/catch, Result types, custom error classes)
4. Logging patterns (console.log, structured logger, etc.)
5. Test framework + location (co-located or separate) + mocking library
6. Quality gate commands (from package.json scripts / Makefile: test, lint, build)

Write `.forge/FORGE-CONFIG.md` with detected conventions. Prompt user for clarifications on low-confidence items.

## Phase Dispatch

When dispatching a phase to a task agent:

**1. Anti-phase-jump check** — reject with message if any prerequisite phase not approved/completed.

**2. Gather context** (slice + refs only, never inline skill file):

```
→ forge slice --json                          // active feature context, <1k tokens
→ forge ref <slug> <prev_phase> --json        // carry_forward ref for handoff
```

**3. Dispatch contract (C3 — no skill-file inlining):**

The worker prompt contains:
- **Skill name** to load (e.g., `forge-requirement-analysis`). The worker loads its own SKILL.md. The orchestrator does NOT read or embed the phase skill file.
- `forge slice` JSON (active feature, <1k tokens).
- `forge ref` pointer(s) for input artifacts from prior phases (locator + summary; worker derefs on demand).
- `feature_dir` absolute path and `config_path` (`.forge/FORGE-CONFIG.md`).
- Output path: `.forge/features/<slug>/.phase-<N>-output.json`.
- Quality gate for this phase.

The worker writes its output JSON to the output path and signals completion.

**4. Mark in_progress:**

```
→ forge mark-complete <slug> <phase> in_progress
```

**5. Dispatch async** to `qc-readonly` task agent. See [task-agent-prompt-template.md](./references/task-agent-prompt-template.md) for full prompt structure.

**6. Poll** (see **Polling** below).

## Polling for Phase Completion

Poll for output file at `.forge/features/<slug>/.phase-<N>-output.json`. Interval is track-aware: review stages in REVIEW_STAGES poll more frequently. Timeout: ~30 minutes.

On file detected — execute in order:

```
1. → forge merge <slug> <phase> <output-json>
       // writes bulk NN.json FIRST (BLK-3), then updates thin index
2. → forge mark-complete <slug> <phase> <status> --summary "<carry_forward>"
3. → forge commit-phase <slug> <phase>          // if WS-B present
4. If phase_output.artifacts not empty:
       → forge invalidate-downstream <slug> <phase>   // cascade check
       If any phases invalidated: report affected phases
5. Display phase completion summary
```

On timeout: output "Phase <N> timed out (no output file detected)". Offer: resume / retry / cancel.

## Post-Phase Validation

After output file detected, before `forge merge`, validate artifact boundaries:

- **Hard boundary:** All internal forge docs (REQUIREMENTS.md, DESIGN.md, IMPL-PLAN.md, review files, test plans) MUST be under `.forge/features/`. Auto-correct if misplaced; report correction.
- **Symlinks:** Check `.forge/features/` for symlinks; convert to real files.
- **Pollution check:** Scan project repo `git status` for unexpected internal forge docs in the project working tree. Report and prompt cleanup.

If index seems inconsistent: `→ forge repair`

## Rollback

When user requests rollback to phase N:

```
→ forge rollback <slug> <phase>
```

WARNING: Rollback permanently discards artifacts and state for all phases after N. Take note of the current phase before proceeding. If `rollback` verb is not yet available, fallback:
```
1. → forge invalidate-downstream <slug> <phase>
2. git -C .forge checkout <target-commit> -- .forge/features/<slug>/
```

## Cascade

On detecting artifact changes after phase completion:

```
→ forge invalidate-downstream <slug> <phase>
```

Report invalidated phases. Nudge: "Use `forge cascade-fix` to re-execute all invalidated phases in dependency order."

`forge cascade-fix` re-dispatches each invalidated phase in ascending phase order, waiting for completion before advancing.

## Error Cases

| Situation | Action |
|-----------|--------|
| `state.json` corrupted | Recover: `git -C .forge show HEAD:state.json > .forge/state.json`; confirm with user |
| Git commit timeout | Retry; if still fails, escalate to user |
| Task agent timeout (>30 min) | Mark timed out; offer resume / retry / cancel |
| Index/ref inconsistency | `→ forge repair` |

---

## Scope-Adaptive Lite Lane

Forge supports two tracks. The track is chosen once, at feature creation, and recorded in `state.json` as `feature.track` (`"standard"` | `"lite"`). It cannot be switched mid-feature — a scope change requires closing the feature and re-creating it.

### Tracks

| Track | Stages | Use when |
|-------|--------|----------|
| `standard` | 12 phases (Req→…→Docs) | Default. Any feature not meeting ALL Lite gates. |
| `lite` | 4 stages: **Plan → Build → Test → Review** | Small, bounded change meeting ALL Lite gates. |

### Lite Lane Gate (ALL must hold)

A feature qualifies for the Lite Lane ONLY if every condition is true:

1. Touches **≤ 3 files**.
2. Has **clear, testable acceptance criteria** stated up front.
3. **No architectural change** — no new module boundary, no cross-cutting refactor.
4. **No public API / contract change** (REST, exported types, DB schema).
5. **No security-sensitive surface** (auth, crypto, access control, secrets).
6. **User explicitly confirms** the Lite Lane after Forge proposes it.

If ANY gate fails → Standard track. When uncertain → Standard track. The Lite Lane is an optimization for genuinely small work, never a shortcut for risky work.

### Lite Lane Stages

Mirrors the raven workflow. Each stage is a dispatched task agent; the orchestrator enforces order (no skipping) exactly as in Standard.

| Stage | Name | Input | Output artifact | Review? |
|-------|------|-------|-----------------|---------|
| L1 | Plan | context, FORGE-CONFIG.md | `STORY.md` (context, objective, constraints, 3–8 step plan, acceptance criteria) | — |
| L2 | Build | STORY.md, named source files | code diffs + `BUILD-NOTES.md` (caveman-ultra) | — |
| L3 | Test | STORY.md, touched files | `VERIFY.md` (check table: PASS/FAIL/SKIP) | — |
| L4 | Review | diffs, STORY.md, VERIFY.md, FORGE-CONFIG.md | `LITE-REVIEW.md` + gate: `ok-to-merge` \| `needs-fix` | gate |

Lite Lane artifacts live under `.forge/features/<slug>/lite/`. State, git hardening, rollback, and artifact-boundary enforcement apply identically to Standard. On `needs-fix`, orchestrator loops L4→L2 with a caveman-ultra issue list (`[file:line] [problem] [fix]`).

### Track Selection at Feature Creation

```
FUNCTION select_track(feature_context):
    gate = evaluate_lite_gate(feature_context)   // returns pass/fail + reasons

    IF gate.all_pass:
        OUTPUT (normal English):
          "This looks like a small, bounded change (≤3 files, clear criteria,
           no API/arch/security impact). I can run the Lite Lane
           (Plan → Build → Test → Review) instead of the full 12-phase
           pipeline to save time and tokens. Proceed with Lite Lane? (yes/no)"
        IF user confirms:
            feature.track = "lite"
        ELSE:
            feature.track = "standard"
    ELSE:
        feature.track = "standard"
        // Optionally surface why (which gate failed) for transparency

    RETURN feature.track
END FUNCTION
```

**Status display:** the phase timeline shows 4 Lite stages instead of 12 phases when `feature.track == "lite"`. Anti-phase-jump enforcement (Principle 7) applies to whichever track is active.

---

## Caveman-Ultra Internal Artifacts

To minimize token usage without losing technical substance, all **internal** Forge artifacts are written in caveman-ultra.

**Applies to (internal):** REQUIREMENTS.md, DESIGN.md, IMPL-PLAN.md, TEST-PLAN.md, all review docs, STORY.md, BUILD-NOTES.md, VERIFY.md, operation notes, diff explanations, issue lists.

**Never caveman (always normal prose/syntax):**
- Product/source code and code comments.
- User-facing documentation (Phase 12 output destined for end users).
- Commit messages and PR descriptions.
- Any text shown directly to the user (status output, questions, warnings).
- Identifiers, file paths, commands, error strings — reproduce EXACTLY, never abbreviate.

**Caveman-ultra rules:** drop articles (a/an/the), filler, and pleasantries; fragments OK; pattern `[thing] [action] [reason]`; abbreviate common terms (DB/auth/config/req/res/fn/impl); arrows for causality (X → Y). Technical terms, identifiers, paths, and commands stay exact.

### Safety-Override Phrasing Rule (Hard)

Caveman compression MUST be dropped — reverting to clear, normal English — for any text where ambiguity is dangerous:

- Destructive or irreversible actions (`rm`, `DROP TABLE`, force-push, data deletion, migration rollback).
- Security rules, auth logic, access-control decisions.
- Multi-step sequences where fragment ordering could be misread.
- Any warning about non-reversible consequences.

For such items: write full sentences, prefix with `WARNING:` where a destructive action is involved, state the consequence explicitly, then resume caveman-ultra for the surrounding non-critical text.

Example (inside an otherwise caveman artifact):
> ...migration adds `is_active` col. Backfill default `true`.
> **WARNING:** The rollback step runs `DROP COLUMN is_active` and permanently deletes the column and its data. Take a database backup before applying the rollback.
> Resume: rollback tested on staging → OK.

---

## Glossary & Phase Names

### Standard Track — 12 phases in order:

| Phase | Name | Execution | Review |
|-------|------|-----------|--------|
| 1 | Requirement Analysis | task_agent | N/A |
| 2 | Design Creation | task_agent | N/A |
| 3 | Design Review | task_agent | Review (findings) |
| 4 | Implementation Planning | task_agent | N/A |
| 5 | Impl Plan Review | task_agent | Review (findings) |
| 6 | Test Planning | task_agent | N/A |
| 7 | Test Plan Review | task_agent | Review (findings) |
| 8 | Code Implementation | task_agent | N/A |
| 9 | Code Review | task_agent | Review (findings) |
| 10 | Test Implementation | task_agent | N/A |
| 11 | Test Review | task_agent | Review (findings) |
| 12 | Documentation | task_agent | N/A |

### Lite Track — 4 stages in order:

| Stage | Name | Execution | Review |
|-------|------|-----------|--------|
| L1 | Plan | task_agent | N/A |
| L2 | Build | task_agent | N/A |
| L3 | Test | task_agent | gate (all checks PASS) |
| L4 | Review | task_agent | gate (ok-to-merge \| needs-fix) |

## Implementation Assumptions

1. **Single Active Feature:** Currently one feature per state.json (architecture supports multi-feature via `.features[]` array)
2. **Absolute Paths:** All paths in state.json and prompts are absolute (no relative resolution)
3. **Idempotent Operations:** All initialization functions can be re-run safely
4. **Atomic Filesystem:** Handled by exec layer (temp file + rename, POSIX atomic)
5. **Task Agent Dispatch:** Task agents dispatched asynchronously; orchestrator polls output file
6. **Read-Only Task Agents:** Task agents use `qc-readonly` model (write-only to their output artifact)
7. **NO PHASE SKIPPING (within a track):** Standard = 1→2→…→12, Lite = L1→L2→L3→L4. Violation → explicit refusal with detailed reason.
8. **Track Immutability:** A feature's `track` cannot change mid-flight. Scope change → close feature, re-create on Standard track.
