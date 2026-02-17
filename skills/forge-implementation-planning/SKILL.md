---
name: forge-implementation-planning
description: Convert design to implementation plan with pseudocode. Use when creating impl plans or working with DESIGN.md.
---

# Implementation Planning

Convert design into detailed implementation plan with pseudocode. NO actual code—only instructions detailed enough for direct review.

## When to Use

- User asks to create an implementation plan or impl plan
- User references `docs/design/DESIGN.md`
- Moving from design phase to implementation planning

## Context Sources

- `docs/design/DESIGN.md` - Primary input (all contracts must be covered)
- `docs/requirement/REQUIREMENTS.md` - Constraints and edge cases
- Codebase conventions - Analyze existing patterns FIRST

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: IMPLEMENTATION PLANNING
```

1. **Review Design Contracts:** Understand all types, methods, errors, and wire formats
2. **Analyze Codebase Conventions:**
   - File naming patterns
   - Class/function naming patterns
   - Error handling patterns
   - Logging patterns
   - Existing utilities that can be reused
3. **Break into Implementation Units:** Define files, classes, and functions
4. **Write Detailed Pseudocode:** Each unit should have line-by-line reviewable pseudocode
5. **Apply Best Practices:**
   - DRY (Don't Repeat Yourself)
   - Single Responsibility Principle
   - Separation of Concerns
   - Clean Code principles
   - Project-specific conventions
6. **Define Implementation Order:** Respect dependencies between units
7. **Identify Reusables:** Utilities that exist vs new code needed

## Deliverables

- `docs/plan/IMPL-PLAN.md` - Use template at [IMPL-PLAN-template.md](./IMPL-PLAN-template.md)

## Quality Checks

- [ ] All design contracts are covered
- [ ] Pseudocode is detailed enough for line-by-line review
- [ ] Follows project patterns (verified by codebase analysis)
- [ ] Error handling is explicit for every failure path
- [ ] Configuration and constants are defined
- [ ] File locations are specified for each unit
- [ ] No actual implementation code
- [ ] Dependencies between units are clear

## Anti-Patterns

- Do NOT write actual implementation code
- Do NOT skip codebase convention analysis
- Do NOT leave pseudocode ambiguous

## Handoff

**Output:** `docs/plan/IMPL-PLAN.md`

**Next Phase:** forge-code-review (impl plan review), then forge-test-planning skill
