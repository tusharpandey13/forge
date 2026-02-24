---
name: forge-documentation
description: Create documentation after implementation and reviews are complete. Use when documenting features, adding docstrings, updating README, or creating context files.
---

# Documentation

Create documentation artifacts after implementation and reviews are complete: docstrings, examples, and context files.

## When to Use

- User asks to document a feature
- Phase 12 of the forge workflow (after test review approved)
- All implementation and review phases are complete

## Context Sources

- `.forge/FORGE-CONFIG.md` — conventions, paths
- `.forge/FORGE-LOGS.md` — full feature history
- Implemented source files
- `{plan-dir}/IMPL-PLAN.md`
- `{design-dir}/DESIGN.md`
- `{requirements-dir}/REQUIREMENTS.md`
- Existing documentation (README.md, etc.)

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: DOCUMENTATION
```

### 1. Verify Prerequisites

Read FORGE-LOGS.md. Confirm Phase 11 (Test Review) status is `approved`.

### 2. Inline Documentation

Add docstrings to all public APIs following project conventions:
- All public functions and methods
- All public classes
- All public types and interfaces
- Include parameters, return types, thrown errors, and usage examples

Add inline comments for:
- Complex algorithms
- Non-obvious business logic
- Workarounds (with context on why)
- Performance-critical sections

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

Location: `{artifact-dir}/[FEATURE]-CONTEXT.md`

### 6. Self-Validate

Re-read output. Verify:
- All public APIs have docstrings
- CONTEXT.md references are valid paths
- No placeholder text remains
Fix any issues silently.

### 7. Update State

Update FORGE-LOGS.md:
```markdown
### Phase 12: Documentation — completed
- Started: [timestamp]
- Completed: [timestamp]
- Artifacts:
  - [FEATURE]-CONTEXT.md
  - EXAMPLES.md (created/updated)
  - README.md (updated: [sections])
  - Docstrings added to [count] files
- Commit: [SHA]
- Feature status: COMPLETE
```

Update FORGE-LOGS.md `## Current` section:
```
Phase 12: Documentation — completed (Feature Complete)
```

Commit:
```bash
git -C .forge add -A && git -C .forge commit -m "forge: phase 12 — documentation complete, feature done"
```

## Anti-Patterns

- Do NOT create documentation before implementation is complete and reviewed
- Do NOT add docstrings to internal/private APIs unless they're complex
- Do NOT duplicate information already in DESIGN.md — reference it

## Handoff

**Output:** Updated documentation files + FORGE-LOGS.md

**Feature complete.**
