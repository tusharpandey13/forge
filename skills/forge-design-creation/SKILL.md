---
name: forge-design-creation
description: Create technical design from requirements. Use when creating design docs, solution architecture, or working with REQUIREMENTS.md.
---

# Design Creation

Solution architect creating technical design from requirements. Produces the blueprint for implementation, with interactive design decision research.

## When to Use

- User asks to create a design or design doc
- User references REQUIREMENTS.md
- Moving from requirements phase to solutioning

## Context Sources

- `.forge/FORGE-CONFIG.md` — conventions, paths
- `.forge/FORGE-LOGS.md` — current state
- `{requirements-dir}/REQUIREMENTS.md` — primary input
- `{requirements-dir}/*.md` — supporting requirement docs
- `{context-dir}/*.md` — original context if needed
- Codebase architecture patterns and existing implementations

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: DESIGN CREATION
```

### 1. Verify Prerequisites

Read FORGE-LOGS.md. Confirm Phase 1 (Requirements) is completed.
Read FORGE-CONFIG.md for conventions and paths.

### 2. Review Requirements

Understand every FR and NFR in REQUIREMENTS.md.

### 3. Analyze Codebase

Study existing architecture, patterns, and similar implementations.

### 4. Identify Design Decisions

As you design the solution, identify decisions where:
- Multiple viable approaches exist
- The choice significantly affects architecture
- Confidence in the best approach is low

### 5. Research Design Decisions

For each design decision with multiple viable options:

1. Spawn a research subagent per option (parallel when possible)
2. Each subagent investigates:
   - How the approach works
   - Implementation strategy
   - Optimization potential
   - Tradeoffs and risks
   - Real-world precedent
3. Each subagent writes findings to: `{design-dir}/design-artifact-{decision-name}.md`
4. Synthesize findings into a comparison

### 6. Present Design Decisions to User

Present all independent DDs simultaneously:

```
FORGE :: DESIGN DECISIONS

DD-1: Authentication Strategy
  Option A: Middleware approach
    - Matches existing codebase pattern
    - Low implementation complexity
    - Details: forge/design/design-artifact-auth-middleware.md
  Option B: Decorator pattern
    - More flexible for per-route config
    - Medium implementation complexity
    - Details: forge/design/design-artifact-auth-decorator.md
  Recommendation: Option A

DD-2: Cache Layer
  Option A: Redis with TTL
    - Details: forge/design/design-artifact-cache-redis.md
  Option B: In-memory LRU
    - Details: forge/design/design-artifact-cache-inmemory.md
  Recommendation: Option A

Choose for each, or say "go with recommendations."
```

For dependent DDs (DD-3 depends on DD-1 choice): present after the dependency is resolved.

### 7. Create Design

With user's DD choices, create the full design:

1. Define public contracts:
   - Types and interfaces (pseudocode, language-agnostic)
   - Methods and functions (signatures, behavior, errors)
   - Error types (codes, conditions, recovery)
   - Constants and configuration options
2. Specify internal approach (pseudocode, no real code)
3. Document wire formats for all network calls
4. Create test matrix (unit + flow + edge cases)
5. Document design decisions with rationale and user's choice
6. Create sequence diagrams (mermaid) for multi-component interactions

Output: `{design-dir}/DESIGN.md` using [DESIGN-template.md](./DESIGN-template.md)

### 8. Self-Validate

Re-read the artifact. Verify:
- No `[placeholder]` or `TBD` text remains
- All FRs have corresponding solutions
- Cross-reference IDs (FR-X, DD-X) resolve to defined items
Fix any issues silently.

### 9. Update State

Update FORGE-LOGS.md:
```markdown
### Phase 2: Design Creation — completed
- Started: [timestamp]
- Completed: [timestamp]
- Artifact: [path]/DESIGN.md
- Design research:
  - [paths to design-artifact-*.md files]
- Decisions:
  - DD-1: [choice] ([rationale])
  - DD-2: [choice] ([rationale])
- Commit: [SHA]
```

Commit:
```bash
git -C .forge add -A && git -C .forge commit -m "forge: phase 2 — design complete"
```

## Quality Checks

- Every FR has a corresponding solution
- NFRs addressed with measurable targets
- Test matrix is exhaustive (happy + error + edge)
- Design decisions documented with rationale
- No actual implementation code (pseudocode only)
- Wire formats complete for all network calls
- Error types and handling strategy defined
- Breaking changes identified with migration paths

## Anti-Patterns

- Do NOT write actual implementation code
- Do NOT skip the test matrix
- Do NOT assume implementation details without analyzing codebase
- Do NOT make design decisions silently — present options to user when multiple viable approaches exist

## Handoff

**Output:** `{design-dir}/DESIGN.md` + `design-artifact-*.md` files

**Next Phase:** forge-review (design review)
