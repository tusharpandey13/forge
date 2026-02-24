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
- `.forge/FORGE-LOGS.md` — current state, verify phase 3 approved
- `{design-dir}/DESIGN.md` — primary input (all contracts must be covered)
- `{requirements-dir}/REQUIREMENTS.md` — constraints and edge cases
- Codebase conventions — analyze existing patterns

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: IMPLEMENTATION PLANNING
```

### 1. Verify Prerequisites

Read FORGE-LOGS.md. Confirm Phase 3 (Design Review) status is `approved`.
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

Update FORGE-LOGS.md:
```markdown
### Phase 4: Implementation Planning — completed
- Started: [timestamp]
- Completed: [timestamp]
- Artifact: [path]/IMPL-PLAN.md
- Units: [count] across [tier count] tiers
- Parallelizable: [count] independent units
- Commit: [SHA]
```

Commit:
```bash
git -C .forge add -A && git -C .forge commit -m "forge: phase 4 — implementation plan complete"
```

## Deliverables

- `{plan-dir}/IMPL-PLAN.md` — use [IMPL-PLAN-template.md](./IMPL-PLAN-template.md)

## Quality Checks

- All design contracts covered
- Pseudocode detailed enough for line-by-line review
- Follows project patterns (verified against config and codebase)
- Error handling explicit for every failure path
- Configuration and constants defined
- File locations specified for each unit
- No actual implementation code
- Dependencies and tiers clearly defined

## Anti-Patterns

- Do NOT write actual implementation code
- Do NOT skip codebase convention analysis
- Do NOT leave pseudocode ambiguous
- Do NOT create units with multiple responsibilities

## Handoff

**Output:** `{plan-dir}/IMPL-PLAN.md`

**Next Phase:** forge-review (impl plan review)
