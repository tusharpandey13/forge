---
name: forge-implement
description: Implement code from IMPL-PLAN.md. Use when implementing features, writing code from plan, or in phase 8 of forge workflow.
license: Proprietary
metadata:
  author: Auth0 SDKs Team <sdks@auth0.com>
---

# Code Implementation

Translates implementation plan pseudocode into production code. Manages unit execution order, parallelism, and quality gates.

## When to Use

- User asks to implement code from IMPL-PLAN.md
- Phase 8 of the forge workflow
- User says "implement" after plan review is approved

## Context Sources

- `.forge/FORGE-CONFIG.md` — conventions, quality gate command, paths
- `.forge/state.json` — current state (verify phase 7 approved)
- `{feature_dir}/plan/IMPL-PLAN.md` — primary input (pseudocode units)
- `{feature_dir}/design/DESIGN.md` — contracts and wire formats
- Codebase source files — integration points

See references/shared-phase-spec.md § feature-dir-note

## Process

See references/shared-phase-spec.md § mandatory-first-output — emit `FORGE :: IMPLEMENT`

### 1. Verify Prerequisites

Via `forge slice` — confirm Phase 7 (Test Plan Review) status is "approved" and IMPL-PLAN.md exists. If not met → stop, nudge user to complete prior phases.

### 2. Parse Implementation Units

Read IMPL-PLAN.md. Extract: all units with dependencies, file paths, pseudocode.

### 3. Build Execution Plan

Build tiered execution plan from unit dependencies:

```
Tier 1 (no dependencies): Unit A, Unit B — parallel
Tier 2 (depends on Tier 1): Unit C — sequential after Tier 1
Tier 3 (depends on Tier 2): Unit D — sequential after Tier 2
```

**Auto-decide parallelism:**
- Tier >1 independent unit → parallelize (subagents if orchestrated)
- Tier 1 unit → sequential
- Record parallelism decision in `.phase-8-output.json` decisions[]

Output the execution plan:
```
FORGE :: EXECUTION PLAN
  Tier 1 (parallel): Unit 1, Unit 2
  Tier 2 (sequential): Unit 3 (depends on Unit 1)
  Quality gate: [command from config]
```

### 4. Implement Each Unit

Per unit, in tier order:

1. Read pseudocode from IMPL-PLAN.md
2. Read FORGE-CONFIG.md conventions (naming, error handling, logging)
3. Translate pseudocode to production code following conventions
4. Run local quality gate (build + lint only, skip full test suite):
   - Pass → unit done
   - Fail → fix in-place, re-run (max 2 attempts)
   - Still failing → mark unit blocked, log reason, continue
5. Record unit completion in `.phase-8-output.json`

Deviation handling:
- **Minor** (naming, parameter order, extra helper): adapt and document
- **Moderate** (different algorithm, restructured logic): document rationale, continue
- **Major** (design flaw, impossible as specified): HALT, report to user, may need rollback to phase 4

### 5. Integration Check

After all tiers complete:

1. Run full quality gate (from FORGE-CONFIG.md). **Apply Proof-of-Work Protocol** (see ../forge/references/verification-protocol.md#protocol-a):
   - Capture tool version: `which <tool> && <tool> --version`
   - Extract work_count (files checked, tests run, items analyzed)
   - work_count == 0 → gate FAILS even if exit code is 0
   - Log evidence in `.phase-8-output.json`
2. Full gate fails → diagnose units, fix targeted, re-run (max 2 attempts); still failing → report to user
3. Full gate passes → phase complete

### 6. Update State

Write `.phase-8-output.json` sidecar (schema: see references/shared-phase-spec.md § sidecar-schema).
Phase-specific: include quality_gate object with tool_version, work_count, exit_code, deviations[].

See references/shared-phase-spec.md § orchestrator-note

## Deviation Report

If deviations from plan occurred, append to phase log:
```
- Deviations:
  - [Unit]: [what changed] ([severity]: [rationale])
```
Deviations are informational for code review. Reviewer should verify they're justified.

## Parallelism Notes for Orchestrated Mode

- Each tier's independent units → dispatch to separate subagents
- Each subagent receives: unit pseudocode, config conventions, relevant source files
- Local gate failure in one subagent doesn't block others
- After all subagents in tier complete → run integration check before next tier

## Error Handling

### Before Starting

See references/shared-phase-spec.md § error-cases (cases 1–4).

- Case 2 for this phase: Phase 7 (Test Plan Review) must be "approved"
- Case 3 (Config not found) → ERROR: "FORGE-CONFIG.md missing. Cannot determine conventions, quality gate, or output paths." Return error; escalate.
- **IMPL-PLAN.md missing** → ERROR: "IMPL-PLAN.md not found at {{ expected_path }}" Return error; escalate.

### During Execution

- **Quality gate command missing** → ERROR: "Quality gate command not found in config. Cannot validate implementation." Escalate.
- **Unit local gate fails (max retries)** → WARN: "Unit {{ unit_name }} failed after 2 attempts. Marking blocked. Reason: {{ reason }}" Document; continue.
- **Major deviation** → HALT: "Major deviation: {{ description }}. Cannot proceed without user approval." May require design/plan rollback.
- **Source file integration issue** → ERROR: "Integration error: {{ detail }}. Unit {{ unit_name }} cannot be merged." Diagnose; attempt fix; escalate if unresolved.

### Before Completing

- **Output not writable** → see § error-cases case 4
- **Full quality gate fails (max retries)** → ERROR: "Full quality gate failed after 2 attempts: {{ list }}" Return diagnostic info; escalate.
- **Phase output not writable** → ERROR: "Cannot write phase output to {{ path }}: {{ reason }}" Escalate.

## Anti-Patterns

- Do NOT implement without approved IMPL-PLAN.md
- Do NOT skip local quality gate per unit
- Do NOT silently deviate from plan
- Do NOT continue past a major deviation
- Do NOT run full test suite as per-unit gate (too slow; tests may not exist yet)
- Do NOT silently fail

## Handoff

**Output:** Production source code + `.phase-8-output.json`
**Next Phase:** forge-review (code review)
