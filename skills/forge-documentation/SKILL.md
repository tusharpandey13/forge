---
name: forge-documentation
description: Create documentation after implementation and reviews are complete. Use when documenting features, adding docstrings, updating README, or creating context files.
license: Proprietary
metadata:
  author: Auth0 SDKs Team <sdks@auth0.com>
---

# Documentation

Create documentation artifacts after implementation and reviews are complete: docstrings, examples, and context files.

## When to Use

- User asks to document a feature
- Phase 12 of the forge workflow (after test review approved)
- All implementation and review phases complete

## Context Sources

- `.forge/FORGE-CONFIG.md` — conventions, paths
- `.forge/state.json` — full feature history
- Implemented source files
- `{feature_dir}/plan/IMPL-PLAN.md`
- `{feature_dir}/design/DESIGN.md`
- `{feature_dir}/requirement/REQUIREMENTS.md`
- Existing documentation (README.md, etc.)

See references/shared-phase-spec.md § feature-dir-note

## Process

See references/shared-phase-spec.md § mandatory-first-output — emit `FORGE :: DOCUMENTATION`

### 1. Verify Prerequisites

Via `forge slice` — confirm Phase 11 (Test Review) status is "approved".

### 2. Inline Documentation

Add docstrings to all public APIs following project conventions:
- All public functions, methods, classes, types/interfaces
- Include parameters, return types, thrown errors, usage examples

Add inline comments for: complex algorithms, non-obvious business logic, workarounds (with context), performance-critical sections.

### 3. EXAMPLES.md

Create or update examples documentation:

```markdown
# [Feature Name]

## Overview
[What the feature does in plain language]

## Basic Usage
[Simplest use case with code example]

## Configuration Options
[Available options with examples]

## Advanced Usage
[Complex scenarios]

## Error Handling
[How to handle errors]
```

### 4. README.md Updates

Update if there are new public APIs, configuration options, dependencies, or breaking changes.

### 5. [FEATURE]-CONTEXT.md

Create implementation context for future developers and agents:

```markdown
# [Feature] Implementation Context

## Feature Summary
[Brief description]

## Key Files
- [path]: [purpose]

## Architecture Decisions
[Key DDs and rationale — reference design-artifact files]

## Known Limitations
[Current constraints and why]

## Extension Points
[How to extend this feature]

## Testing Notes
[How to test, special considerations]

## Debugging Tips
[Common issues and troubleshooting]

## References
- Requirements: [path]
- Design: [path]
- Impl Plan: [path]
- Test Plan: [path]
```

Location: `{feature_dir}/[FEATURE]-CONTEXT.md`

### 6. Self-Validate

See references/shared-phase-spec.md § self-validate. Also: all public APIs have docstrings, CONTEXT.md references are valid paths.

### 7. Update State

Write `.phase-12-output.json` sidecar (schema: see references/shared-phase-spec.md § sidecar-schema).
Phase-specific decisions[] examples: "Documentation complete", "Docstrings added to N files"

See references/shared-phase-spec.md § orchestrator-note

## Error Handling

### Before Starting

See references/shared-phase-spec.md § error-cases (cases 1–4).

- Case 2 for this phase: Phase 11 (Test Review) must be "approved"
- **Source code missing** → ERROR: "Source code not found. Cannot create documentation." Return error; escalate.
- **Design/Requirements missing** → WARN: "Design/Requirements not found. Proceeding with implementation-based documentation." Continue; flag for manual review.

### During Execution

- **Docstring conventions unclear** → WARN: "Docstring conventions inconsistent. Using primary: {{ pattern }}." Document in CONTEXT.md.
- **API analysis incomplete** → WARN: "Could not fully analyze all public APIs: {{ items }}. Documenting identified items." Flag uncertain items.

### Before Completing

- **Output not writable** → see § error-cases case 4
- **Cross-references invalid** → WARN: "Invalid cross-references: {{ list }}. Updating to valid paths."
- **Placeholder text remains** → WARN: "Incomplete sections: {{ list }}. Escalating."
- **Phase output not writable** → ERROR: "Cannot write phase output to {{ path }}: {{ reason }}" Escalate.

## Anti-Patterns

- Do NOT create documentation before implementation is complete and reviewed
- Do NOT add docstrings to internal/private APIs unless complex
- Do NOT duplicate information already in DESIGN.md — reference it
- Do NOT silently fail

## Handoff

**Output:** Updated documentation files + `.phase-12-output.json`
**Feature complete.**
