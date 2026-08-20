---
name: forge-implementation-planning
description: Convert design to implementation plan with pseudocode. Use when creating impl plans or working with DESIGN.md.
license: Proprietary
metadata:
  author: Auth0 SDKs Team <sdks@auth0.com>
---

# Implementation Planning

Convert design into detailed implementation plan with pseudocode. NO actual code — only instructions detailed enough for direct review.

## When to Use

- User asks to create an implementation plan
- User references DESIGN.md
- Moving from design to implementation planning

## Context Sources

- `.forge/FORGE-CONFIG.md` — conventions, paths
- `.forge/state.json` — current state (verify phase 3 approved)
- `{feature_dir}/design/DESIGN.md` — primary input (all contracts must be covered)
- `{feature_dir}/requirement/REQUIREMENTS.md` — constraints and edge cases
- Codebase conventions — analyze existing patterns

See references/shared-phase-spec.md § feature-dir-note

## Process

See references/shared-phase-spec.md § mandatory-first-output — emit `FORGE :: IMPLEMENTATION PLANNING`

### 1. Verify Prerequisites

Via `forge slice` — confirm Phase 3 (Design Review) status is "approved". Read FORGE-CONFIG.md for conventions and paths.

### 2. Review Design Contracts

Understand all types, methods, errors, wire formats from DESIGN.md.

### 3. Analyze Codebase Conventions

Read FORGE-CONFIG.md conventions. Verify against codebase:
- File naming patterns; class/function naming; error handling; logging; existing reusable utilities

### 4. Break into Implementation Units

Define files, classes, functions. Each unit:
- Clear purpose (single responsibility)
- Defined file location (following config conventions)
- Dependencies on other units

### 5. Write Detailed Pseudocode

Each unit gets line-by-line reviewable pseudocode. Language-agnostic, follows project structural patterns.

### 6. Define Implementation Order + Parallelism

Build dependency graph, identify tiers:
- Tier 1: no dependencies (parallelizable)
- Tier 2: depends on Tier 1 (parallelizable within tier)
- etc.

Mark each unit:
```
Unit 1: [Name] — Tier 1 (independent)
Unit 2: [Name] — Tier 1 (independent)
Unit 3: [Name] — Tier 2 (depends on Unit 1)
```

### 7. Identify Reusables

Document utilities that exist vs. new code needed.

### 8. Self-Validate

See references/shared-phase-spec.md § self-validate. Also: all design contracts covered, cross-reference IDs match upstream.

### 9. Update State

Write `.phase-4-output.json` sidecar (schema: see references/shared-phase-spec.md § sidecar-schema).
Phase-specific decisions[] examples: "Tier 1: N independent units", "Tier 2: N dependent units"

See references/shared-phase-spec.md § orchestrator-note

## Deliverables

- `{feature_dir}/plan/IMPL-PLAN.md` — use [impl-plan-template.md](./references/impl-plan-template.md)

## Quality Checks

- All design contracts covered
- Pseudocode detailed enough for line-by-line review
- Follows project patterns (verified against config and codebase)
- Error handling explicit for every failure path
- Configuration and constants defined
- File locations specified per unit
- No actual implementation code
- Dependencies and tiers clearly defined

## Error Handling

### Before Starting

See references/shared-phase-spec.md § error-cases (cases 1–4).

- Case 2 for this phase: Phase 3 (Design Review) must be "approved"
- Case 3 (Config not found) → WARN: "FORGE-CONFIG.md not found. Will infer conventions from codebase." Continue.

### During Execution

- **Design contracts ambiguous** → WARN: "Some design contracts unclear: {{ list }}. Proceeding with documented assumptions."
- **Codebase conventions inconsistent** → WARN: "Conventions inconsistent ({{ examples }}). Using primary: {{ pattern }}." Document in IMPL-PLAN.md.

### Before Completing

- **Output not writable** → see § error-cases case 4
- **Pseudocode incomplete or ambiguous** → WARN: "Incomplete pseudocode: {{ list }}. Escalating for clarification."
- **Circular dependencies detected** → ERROR: "Circular dependencies in units: {{ cycle }}. Cannot establish execution order." Escalate for design review.

## Anti-Patterns

- Do NOT write actual implementation code
- Do NOT skip codebase convention analysis
- Do NOT leave pseudocode ambiguous
- Do NOT create units with multiple responsibilities
- Do NOT silently fail

## Handoff

**Output:** `{feature_dir}/plan/IMPL-PLAN.md` + `.phase-4-output.json`
**Next Phase:** forge-review (impl plan review)
