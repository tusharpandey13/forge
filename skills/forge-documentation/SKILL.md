---
name: forge-documentation
description: Create documentation after implementation. Use when documenting features, adding docstrings, updating README, or creating context files.
---

# Documentation

Create documentation artifacts after implementation is complete: docstrings, examples, and context files.

## When to Use

- User asks to document a feature
- User asks to add docs or update documentation
- Implementation phase is complete

## Context Sources

- Implemented source files
- `docs/plan/IMPL-PLAN.md`
- `docs/design/DESIGN.md`
- `docs/requirement/REQUIREMENTS.md`
- Existing documentation (README.md, EXAMPLES.md)

**MANDATORY FIRST OUTPUT:**
```
FORGE :: DOCUMENTATION
```

## Documentation Types

### 1. Inline Documentation

**Docstrings (JSDoc/TSDoc):**
- All public functions and methods
- All public classes
- All public types and interfaces
- Include parameters, return types, thrown errors, and examples

**Inline Comments:**
- Complex algorithms that need explanation
- Non-obvious business logic
- Workarounds with context (why it exists)
- Performance-critical sections

### 2. EXAMPLES.md

Add intuitive prose describing the feature:

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

## Best Practices
[Recommendations]
```

### 3. README.md Updates

Update when there are:
- New public APIs
- New configuration options
- New dependencies
- Breaking changes

Sections to check:
- Installation
- Quick Start
- API Reference
- Configuration
- Changelog pointer

### 4. [FEATURE]-CONTEXT.md

Implementation context for future agents and developers.

**Location:** `docs/[FEATURE]-CONTEXT.md`

```markdown
# [Feature] Implementation Context

## Feature Summary
[Brief description of what was implemented]

## Key Files
| File | Purpose |
|------|---------|
| [path] | [what it does] |

## Architecture Decisions
[Why things are the way they are]

## Known Limitations
[Current constraints and why they exist]

## Extension Points
[How to extend this feature in the future]

## Related Features
[Connections to other parts of the system]

## Testing Notes
[How to test, special considerations]

## Debugging Tips
[How to troubleshoot common issues]

## Historical Context
[Why certain decisions were made, alternatives considered]

## References
| Doc | Location |
|-----|----------|
| Requirements | docs/requirement/REQUIREMENTS.md |
| Design | docs/design/DESIGN.md |
| Impl Plan | docs/plan/IMPL-PLAN.md |
```

## Quality Checks

- [ ] All public APIs have docstrings
- [ ] Complex logic has inline comments
- [ ] EXAMPLES.md has runnable examples
- [ ] README.md is accurate and up-to-date
- [ ] [FEATURE]-CONTEXT.md is complete for future reference
- [ ] No outdated documentation remains

## Handoff

**Output:** Updated documentation files

**Feature complete.**
