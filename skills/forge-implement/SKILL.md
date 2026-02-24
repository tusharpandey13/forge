---
name: forge-implement
description: Implement code from IMPL-PLAN.md. Use when implementing features, writing code from plan, or in phase 8 of forge workflow.
---

# Code Implementation

Translates implementation plan pseudocode into production code. Manages unit execution order, parallelism decisions, and quality gates.

## When to Use

- User asks to implement code from IMPL-PLAN.md
- Phase 8 of the forge workflow
- User says "implement" after plan review is approved

## Context Sources

- `.forge/FORGE-CONFIG.md` — conventions, quality gate command, paths
- `.forge/FORGE-LOGS.md` — current state, verify phase 7 approved
- `{plan-dir}/IMPL-PLAN.md` — primary input (pseudocode units)
- `{design-dir}/DESIGN.md` — contracts and wire formats for reference
- Codebase source files — for integration points

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: IMPLEMENT
```

### 1. Verify Prerequisites

Read FORGE-LOGS.md. Confirm:
- Phase 7 (Test Plan Review) status is `approved`
- IMPL-PLAN.md exists and is approved

If not met → stop and nudge user to complete prior phases.

### 2. Parse Implementation Units

Read IMPL-PLAN.md. Extract:
- All implementation units with their dependencies
- File paths for each unit
- Pseudocode for each unit

### 3. Build Execution Plan

Analyze unit dependencies and build a tiered execution plan:

```
Tier 1 (no dependencies): Unit A, Unit B — can run in parallel
Tier 2 (depends on Tier 1): Unit C — sequential after Tier 1
Tier 3 (depends on Tier 2): Unit D — sequential after Tier 2
```

**Auto-decide parallelism:**
- Tier has >1 independent unit → parallelize (use subagents if orchestrated)
- Tier has 1 unit → sequential
- All units sequential → no parallelism
- Log the decision in FORGE-LOGS.md

Output the execution plan:
```
FORGE :: EXECUTION PLAN
  Tier 1 (parallel): Unit 1, Unit 2
  Tier 2 (sequential): Unit 3 (depends on Unit 1)
  Tier 3 (sequential): Unit 4 (depends on Unit 2, Unit 3)
  Quality gate: [command from config]
```

### 4. Implement Each Unit

For each unit, in tier order:

1. Read the pseudocode from IMPL-PLAN.md
2. Read FORGE-CONFIG.md conventions (naming, error handling, logging patterns)
3. Translate pseudocode to production code following conventions
4. Run local quality gate (build + lint only, skip full test suite):
   - Pass → unit done
   - Fail → fix in-place, re-run (max 2 attempts)
   - Still failing → mark unit as blocked, log reason, continue to next unit
5. Update FORGE-LOGS.md with unit completion

If the plan doesn't work as written (runtime issue, API mismatch, missing dependency):
- **Minor deviation** (naming, parameter order, extra helper): adapt and document
- **Moderate deviation** (different algorithm, restructured logic): document rationale, continue
- **Major deviation** (design flaw, impossible as specified): HALT, report to user, may need rollback to phase 4

### 5. Integration Check

After all tiers complete:

1. Run full quality gate (from FORGE-CONFIG.md):
   ```
   [quality gate command]
   ```
2. If full gate fails:
   - Diagnose which unit(s) caused the failure
   - Fix targeted units
   - Re-run full gate (max 2 attempts)
   - Still failing → report to user with diagnostic info
3. If full gate passes → phase complete

### 6. Update State

Update FORGE-LOGS.md:
```markdown
### Phase 8: Code Implementation — completed
- Started: [timestamp]
- Completed: [timestamp]
- Execution strategy: [N] tiers, [parallel/sequential]
- Units completed: [N]/[total]
- Deviations:
  - Unit 3: used async iterator instead of callback (minor, better fit for existing pattern)
- Quality gate: passed
- Commit: [SHA]
```

Commit forge artifacts:
```bash
git -C .forge add -A && git -C .forge commit -m "forge: phase 8 — code implementation complete"
```

## Deviation Report

If any deviations from the plan occurred, append to the phase log:

```
- Deviations:
  - [Unit]: [what changed] ([severity]: [rationale])
```

Deviations are informational for the code review phase. The reviewer should verify deviations are justified.

## Parallelism Notes for Orchestrated Mode

When running under forge-autopilot with subagents:
- Each tier's independent units can be dispatched to separate subagents
- Each subagent receives: unit pseudocode, config conventions, relevant source files
- Local gate failures in one subagent don't block others
- After all subagents in a tier complete, run integration check before proceeding to next tier

## Anti-Patterns

- Do NOT implement without an approved IMPL-PLAN.md
- Do NOT skip the local quality gate per unit
- Do NOT silently deviate from the plan — always document
- Do NOT continue past a major deviation — halt and escalate
- Do NOT run the full test suite as part of per-unit gates (too slow, tests may not exist yet)

## Handoff

**Output:** Production source code + FORGE-LOGS.md updated

**Next Phase:** forge-review (code review)
