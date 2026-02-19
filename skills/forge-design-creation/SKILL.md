---
name: forge-design-creation
description: Create technical design from requirements. Use when creating design docs, solution architecture, or working with REQUIREMENTS.md.
---

# Design Creation

Solution architect creating technical design from requirements. This phase produces the blueprint for implementation.

## When to Use

- User asks to create a design or design doc
- User references `docs/requirement/REQUIREMENTS.md`
- Moving from requirements phase to solutioning

## Context Sources

- `docs/requirement/REQUIREMENTS.md` - Primary input (must review thoroughly)
- `docs/requirement/*.md` - Supporting requirement docs
- `docs/context/*.md` - Original context if needed
- Codebase architecture patterns and existing implementations

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: DESIGN CREATION
```

1. **Review Requirements:** Understand every FR and NFR in REQUIREMENTS.md
2. **Analyze Codebase:** Study existing architecture, patterns, and similar implementations
3. **Design Solution:** Create solution that addresses ALL functional requirements
4. **Define Public Contracts:**
   - Types and interfaces (with full type definitions)
   - Methods and functions (signatures, behavior, errors thrown)
   - Error types (codes, conditions, recovery strategies)
   - Constants and configuration options
5. **Specify Internal Approach:** Describe implementation strategy (pseudocode acceptable, no real code)
6. **Document Wire Formats:** All network calls across all hops (request/response shapes)
7. **Create Test Matrix:**
   - Unit tests per component/function
   - Integration/flow tests (pseudo-e2e, blackbox)
   - Edge cases
8. **Document Design Decisions:** Significant decisions with context, options, and rationale
9. **Ask Clarifying Questions:** If design reveals requirement ambiguities

## Deliverables

- `docs/design/DESIGN.md` - Use template at [DESIGN-template.md](./DESIGN-template.md)
- Sequence diagrams (mermaid) for multi-component interactions
- Data flow diagrams if data transformations are complex

## Quality Checks

- [ ] Every FR has a corresponding solution
- [ ] NFRs addressed explicitly with targets (performance, security, reliability)
- [ ] Test matrix is exhaustive (happy path + error paths + edge cases)
- [ ] Design decisions documented with rationale
- [ ] No actual implementation code (pseudocode is acceptable)
- [ ] Wire formats complete (request and response shapes for all calls)
- [ ] Error types and handling strategy defined
- [ ] Breaking changes identified with migration paths

## Anti-Patterns

- Do NOT write actual implementation code
- Do NOT skip the test matrix
- Do NOT assume implementation details without analyzing codebase

## Handoff

**Output:** `docs/design/DESIGN.md` + supporting docs

**Next Phase:** forge-code-review (design review), then forge-implementation-planning skill
