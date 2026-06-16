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
- `.forge/state.json` — current state, verify phase 7 approved
- `{feature_dir}/plan/IMPL-PLAN.md` — primary input (absolute path from orchestrator, pseudocode units)
- `{feature_dir}/design/DESIGN.md` — contracts and wire formats for reference
- Codebase source files — for integration points

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: IMPLEMENT
```

### 1. Verify Prerequisites

Read .forge/state.json. Confirm:
- Phase 7 (Test Plan Review) status is "approved"
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

Write `.phase-8-output.json` sidecar in `{feature_dir}/`:
```json
{
  "phase": 8,
  "status": "completed",
  "artifacts": [
    {
      "path": "[absolute path to implemented source file 1]",
      "sha": "[git SHA]",
      "size_bytes": [size]
    },
    {
      "path": "[absolute path to implemented source file 2]",
      "sha": "[git SHA]",
      "size_bytes": [size]
    }
  ],
  "decisions": [
    "Execution: N tiers, parallel/sequential",
    "Units completed: N/total"
  ],
  "execution_details": {
    "model": "qc-readonly",
    "reasoning_lines": [count],
    "context_usage_percent": [%],
    "elapsed_seconds": [duration]
  },
  "quality_gate": {
    "passed": true,
    "deviations": [
      "Unit 3: used async iterator instead of callback (minor, better fit for existing pattern)"
    ]
  }
}
```

**Orchestrator updates state.json** (skill does NOT write to state.json directly)
- Orchestrator reads .phase-8-output.json
- Orchestrator updates state.json with artifacts and quality gate result
- Orchestrator commits to .forge git

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

## Error Handling

### Before Starting

1. **State.json Missing or Invalid:**
   - If `.forge/state.json` cannot be found or is corrupted
   - **Action:** ERROR: "state.json missing or corrupted. Run /forge to reinitialize."
   - **Recovery:** Do not proceed; return error

2. **Prerequisite Phase Not Complete:**
   - If Phase 7 (Test Plan Review) status is not "approved"
   - **Action:** ERROR: "Phase 7 (Test Plan Review) must be approved first. Current status: {{ phase_7.status }}"
   - **Recovery:** Return error; do not start implementation

3. **IMPL-PLAN.md Missing:**
   - If implementation plan file does not exist
   - **Action:** ERROR: "IMPL-PLAN.md not found at {{ expected_path }}"
   - **Recovery:** Return error; escalate

4. **Config Not Found:**
   - If `.forge/FORGE-CONFIG.md` missing
   - **Action:** ERROR: "FORGE-CONFIG.md missing. Cannot determine conventions, quality gate command, or output paths."
   - **Recovery:** Return error; escalate

### During Execution

5. **Quality Gate Command Missing:**
   - If quality gate command not defined in FORGE-CONFIG.md
   - **Action:** ERROR: "Quality gate command not found in config. Cannot validate implementation."
   - **Recovery:** Return error; escalate

6. **Unit Local Quality Gate Fails (Max Retries):**
   - If a unit fails local quality gate after 2 fix attempts
   - **Action:** WARN: "Unit {{ unit_name }} failed local quality gate after 2 attempts. Marking as blocked. Reason: {{ reason }}"
   - **Recovery:** Document; continue to next unit; log in FORGE-LOGS.md

7. **Major Deviation from Plan:**
   - If implementation significantly deviates from IMPL-PLAN.md (different algorithm, restructured logic)
   - **Action:** HALT: "Major deviation detected: {{ description }}. Cannot proceed without explicit user approval."
   - **Recovery:** Report to user with diagnostic details; may require design/plan rollback

8. **Source File Integration Issue:**
   - If implemented code cannot integrate with existing codebase (missing imports, API mismatch)
   - **Action:** ERROR: "Integration error: {{ detail }}. Unit {{ unit_name }} cannot be merged."
   - **Recovery:** Diagnose; attempt fix; if not resolved, escalate

### Before Completing

9. **Output Path Not Writable:**
   - If source files cannot be written to designated paths
   - **Action:** ERROR: "Cannot write source file to {{ path }}: {{ reason }}"
   - **Recovery:** Return error; do not complete

10. **Full Quality Gate Fails (Max Retries):**
    - If integration check (full quality gate) fails after 2 fix attempts
    - **Action:** ERROR: "Full quality gate failed after 2 attempts. Build/lint errors: {{ list }}"
    - **Recovery:** Return error with diagnostic info; escalate for user investigation

11. **Phase Output File Not Writable:**
    - If `.phase-8-output.json` cannot be written
    - **Action:** ERROR: "Cannot write phase output to {{ path }}: {{ reason }}"
    - **Recovery:** Return error; escalate

## Anti-Patterns

- Do NOT implement without an approved IMPL-PLAN.md
- Do NOT skip the local quality gate per unit
- Do NOT silently deviate from the plan — always document
- Do NOT continue past a major deviation — halt and escalate
- Do NOT run the full test suite as part of per-unit gates (too slow, tests may not exist yet)
- Do NOT silently fail — report all errors with full context

## Handoff

**Output:** Production source code + `.phase-8-output.json`

**Next Phase:** forge-review (code review)
