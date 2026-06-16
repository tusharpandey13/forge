---
name: forge-implementation-planning
description: Convert design to implementation plan with pseudocode. Use when creating impl plans or working with DESIGN.md.
---

# Implementation Planning

Convert design into detailed implementation plan with pseudocode. NO actual code — only instructions detailed enough for direct review.

## When to Use

- User asks to create an implementation plan
- User references DESIGN.md
- Moving from design phase to implementation planning

## Context Sources

- `.forge/FORGE-CONFIG.md` — conventions, paths
- `.forge/state.json` — current state, verify phase 3 approved
- `{feature_dir}/design/DESIGN.md` — primary input (absolute path from orchestrator, all contracts must be covered)
- `{feature_dir}/requirement/REQUIREMENTS.md` — constraints and edge cases
- Codebase conventions — analyze existing patterns

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: IMPLEMENTATION PLANNING
```

### 1. Verify Prerequisites

Read .forge/state.json. Confirm Phase 3 (Design Review) status is "approved".
Read FORGE-CONFIG.md for conventions and paths.

### 2. Review Design Contracts

Understand all types, methods, errors, and wire formats from DESIGN.md.

### 3. Analyze Codebase Conventions

Read FORGE-CONFIG.md conventions. Verify against codebase:
- File naming patterns
- Class/function naming patterns
- Error handling patterns
- Logging patterns
- Existing utilities that can be reused

### 4. Break into Implementation Units

Define files, classes, and functions. Each unit should have:
- Clear purpose (single responsibility)
- Defined file location (following config conventions)
- Dependencies on other units

### 5. Write Detailed Pseudocode

Each unit gets line-by-line reviewable pseudocode. Use language-agnostic pseudocode that follows the project's structural patterns.

### 6. Define Implementation Order + Parallelism

Build a dependency graph and identify tiers:
- Tier 1: units with no dependencies (can parallelize)
- Tier 2: units depending on Tier 1 (can parallelize within tier)
- etc.

Mark each unit clearly:
```
Unit 1: [Name] — Tier 1 (independent)
Unit 2: [Name] — Tier 1 (independent)
Unit 3: [Name] — Tier 2 (depends on Unit 1)
```

### 7. Identify Reusables

Document utilities that exist vs. new code needed.

### 8. Self-Validate

Re-read the artifact. Verify:
- No `[placeholder]` or `TBD` text remains
- All design contracts covered
- Cross-reference IDs match upstream
Fix any issues silently.

### 9. Update State

Write output artifact: `{feature_dir}/plan/IMPL-PLAN.md`

Write `.phase-4-output.json` sidecar in `{feature_dir}/`:
```json
{
  "phase": 4,
  "status": "completed",
  "artifacts": [
    {
      "path": "{feature_dir}/plan/IMPL-PLAN.md",
      "sha": "[git SHA]",
      "size_bytes": [size]
    }
  ],
  "decisions": [
    "Tier 1: N independent units",
    "Tier 2: N dependent units"
  ],
  "execution_details": {
    "model": "qc-readonly",
    "reasoning_lines": [count],
    "context_usage_percent": [%],
    "elapsed_seconds": [duration]
  }
}
```

**Orchestrator updates state.json** (skill does NOT write to state.json directly)
- Orchestrator reads .phase-4-output.json
- Orchestrator updates state.json with artifacts
- Orchestrator commits to .forge git

## Deliverables

- `{feature_dir}/plan/IMPL-PLAN.md` — use [IMPL-PLAN-template.md](./IMPL-PLAN-template.md)

## Quality Checks

- All design contracts covered
- Pseudocode detailed enough for line-by-line review
- Follows project patterns (verified against config and codebase)
- Error handling explicit for every failure path
- Configuration and constants defined
- File locations specified for each unit
- No actual implementation code
- Dependencies and tiers clearly defined

## Error Handling

### Before Starting

1. **State.json Missing or Invalid:**
   - If `.forge/state.json` cannot be found or is corrupted
   - **Action:** ERROR: "state.json missing or corrupted. Run /forge to reinitialize."
   - **Recovery:** Do not proceed; return error

2. **Prerequisite Phase Not Complete:**
   - If Phase 3 (Design Review) status is not "approved"
   - **Action:** ERROR: "Phase 3 (Design Review) must be approved first. Current status: {{ phase_3.status }}"
   - **Recovery:** Return error; do not start planning

3. **DESIGN.md Missing:**
   - If design file does not exist
   - **Action:** ERROR: "DESIGN.md not found at {{ expected_path }}"
   - **Recovery:** Return error; escalate

4. **Config Not Found:**
   - If `.forge/FORGE-CONFIG.md` missing
   - **Action:** WARN: "FORGE-CONFIG.md not found. Will infer conventions from codebase."
   - **Recovery:** Continue with codebase analysis

### During Execution

5. **Design Contracts Ambiguous:**
   - If DESIGN.md has unclear contracts or unresolved design decisions
   - **Action:** WARN: "Some design contracts are unclear: {{ list }}. Proceeding with assumptions documented."
   - **Recovery:** Document assumptions; flag for design review if needed

6. **Codebase Conventions Inconsistent:**
   - If file/function naming patterns inconsistent across codebase
   - **Action:** WARN: "Codebase conventions inconsistent ({{ examples }}). Using primary pattern: {{ pattern }}"
   - **Recovery:** Continue; document chosen convention in IMPL-PLAN.md

### Before Completing

7. **Output Path Not Writable:**
   - If `.forge/features/<slug>/plan/` cannot be created or written to
   - **Action:** ERROR: "Cannot write to {{ output_path }}: {{ reason }}"
   - **Recovery:** Return error; do not complete

8. **Pseudocode Incomplete or Ambiguous:**
   - If IMPL-PLAN.md contains `[TBD]`, unspecified error paths, or unclear logic
   - **Action:** WARN: "Incomplete pseudocode: {{ list }}. Escalating for clarification."
   - **Recovery:** List specific units; ask for guidance

9. **Circular Dependencies Detected:**
   - If units have circular dependencies preventing tier ordering
   - **Action:** ERROR: "Circular dependencies detected in units: {{ cycle }}. Cannot establish execution order."
   - **Recovery:** Return error; escalate for design review

## Anti-Patterns

- Do NOT write actual implementation code
- Do NOT skip codebase convention analysis
- Do NOT leave pseudocode ambiguous
- Do NOT create units with multiple responsibilities
- Do NOT silently fail — report all errors with full context

## Handoff

**Output:** `{feature_dir}/plan/IMPL-PLAN.md` + `.phase-4-output.json`

**Next Phase:** forge-review (impl plan review)
