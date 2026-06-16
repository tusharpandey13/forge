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
- All implementation and review phases are complete

## Context Sources

- `.forge/FORGE-CONFIG.md` — conventions, paths
- `.forge/state.json` — full feature history
- Implemented source files
- `{feature_dir}/plan/IMPL-PLAN.md`
- `{feature_dir}/design/DESIGN.md`
- `{feature_dir}/requirement/REQUIREMENTS.md`
- Existing documentation (README.md, etc.)

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: DOCUMENTATION
```

### 1. Verify Prerequisites

Read .forge/state.json. Confirm Phase 11 (Test Review) status is "approved".

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

Location: `{feature_dir}/[FEATURE]-CONTEXT.md`

### 6. Self-Validate

Re-read output. Verify:
- All public APIs have docstrings
- CONTEXT.md references are valid paths
- No placeholder text remains
Fix any issues silently.

### 7. Update State

Write `.phase-12-output.json` sidecar in `{feature_dir}/`:
```json
{
  "phase": 12,
  "status": "completed",
  "artifacts": [
    {
      "path": "[absolute path to CONTEXT file]",
      "sha": "[git SHA]",
      "size_bytes": [size]
    },
    {
      "path": "[absolute path to EXAMPLES file]",
      "sha": "[git SHA]",
      "size_bytes": [size]
    },
    {
      "path": "[absolute path to README or updated docs]",
      "sha": "[git SHA]",
      "size_bytes": [size]
    }
  ],
  "decisions": [
    "Documentation complete",
    "Docstrings added to N files"
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
- Orchestrator reads .phase-12-output.json
- Orchestrator updates state.json with artifacts, marks feature as "completed"
- Orchestrator commits to .forge git

## Error Handling

### Before Starting

1. **State.json Missing or Invalid:**
   - If `.forge/state.json` cannot be found or is corrupted
   - **Action:** ERROR: "state.json missing or corrupted. Run /forge to reinitialize."
   - **Recovery:** Do not proceed; return error

2. **Prerequisite Phase Not Complete:**
   - If Phase 11 (Test Review) status is not "approved"
   - **Action:** ERROR: "Phase 11 (Test Review) must be approved first. Current status: {{ phase_11.status }}"
   - **Recovery:** Return error; do not start documentation

3. **Source Code Missing:**
   - If implemented source files do not exist
   - **Action:** ERROR: "Source code not found. Cannot create documentation."
   - **Recovery:** Return error; escalate

4. **Design/Requirements Missing:**
   - If DESIGN.md or REQUIREMENTS.md do not exist
   - **Action:** WARN: "Design/Requirements not found. Proceeding with implementation-based documentation."
   - **Recovery:** Continue without upstream context; flag for manual review

### During Execution

5. **Docstring Conventions Unclear:**
   - If codebase has inconsistent or unclear docstring patterns
   - **Action:** WARN: "Docstring conventions inconsistent. Using primary pattern: {{ pattern }}"
   - **Recovery:** Continue; document chosen convention in CONTEXT.md

6. **API Analysis Incomplete:**
   - If unable to fully analyze public APIs (complex reflection, dynamic methods)
   - **Action:** WARN: "Could not fully analyze all public APIs: {{ difficult_items }}. Documenting identified items."
   - **Recovery:** Continue; flag uncertain items for manual review

### Before Completing

7. **Output Path Not Writable:**
   - If documentation files cannot be written
   - **Action:** ERROR: "Cannot write documentation to {{ path }}: {{ reason }}"
   - **Recovery:** Return error; escalate

8. **Cross-References Invalid:**
   - If CONTEXT.md references non-existent artifact paths
   - **Action:** WARN: "Invalid cross-references found: {{ list }}. Updating to valid paths."
   - **Recovery:** Correct references; flag for manual review

9. **Placeholder Text Remains:**
   - If documentation contains `[TBD]` or unfinished sections
   - **Action:** WARN: "Incomplete documentation sections: {{ list }}. Escalating."
   - **Recovery:** List specific sections; escalate for manual completion

10. **Phase Output File Not Writable:**
    - If `.phase-12-output.json` cannot be written
    - **Action:** ERROR: "Cannot write phase output to {{ path }}: {{ reason }}"
    - **Recovery:** Return error; escalate

## Anti-Patterns

- Do NOT create documentation before implementation is complete and reviewed
- Do NOT add docstrings to internal/private APIs unless they're complex
- Do NOT duplicate information already in DESIGN.md — reference it
- Do NOT silently fail — report all errors with full context

## Handoff

**Output:** Updated documentation files + `.phase-12-output.json`

**Feature complete.**
