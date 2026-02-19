---
name: forge-code-review
description: Systematic review of design docs, plans, or code. Use when reviewing, doing code review, or asking for feedback on artifacts.
---

# Code Review

Systematic review of design docs, implementation plans, test plans, or code changes.

## When to Use

- User asks to review something
- User mentions "code review" or "review"
- User asks for feedback on any artifact

**MANDATORY FIRST OUTPUT:**
```
FORGE :: CODE REVIEW
```

## Review Types

| Type | Target | Context Needed |
|------|--------|----------------|
| **Design Review** | `docs/design/DESIGN.md` | `docs/requirement/REQUIREMENTS.md` |
| **Impl Plan Review** | `docs/plan/IMPL-PLAN.md` | DESIGN.md + REQUIREMENTS.md |
| **Test Plan Review** | `docs/plan/TEST-PLAN.md` | IMPL-PLAN.md + DESIGN.md |
| **Code Review** | Changed source/test files | Relevant plans |

## Review Checklists

See [review-checklist.md](./review-checklist.md) for detailed checklists per review type.

### Design Review
- All FRs from REQUIREMENTS.md addressed
- NFRs explicitly handled with measurable targets
- No ambiguity in contracts or descriptions
- Test matrix exhaustive (happy + error + edge)
- Design decisions documented with rationale
- Wire formats complete for all network calls
- Breaking changes identified with migration paths

### Implementation Plan Review
- All design contracts covered
- Pseudocode clear and reviewable line-by-line
- No DRY violations across units
- Single responsibility per unit
- Follows codebase conventions
- Error handling explicit for all paths
- Implementation order respects dependencies

### Test Plan Review
- All implementation units have tests
- All FRs verified by tests
- All error paths tested
- All edge cases covered
- HTTP mocking (e.g., MSW, nock) for network calls only, minimal other mocks
- Precise assertion expectations
- Blackbox flow tests (behavior, not implementation)

### Code Review
- Matches plan pseudocode
- Quality gate passes
- Coverage >= 80%
- No regressions in existing tests
- Clean, readable, maintainable
- Secure, no vulnerabilities
- Performant, no obvious bottlenecks

## Output Format

```markdown
## PROBLEMS

### [CRITICAL] Issue Title
**Location:** file/section reference
**Impact:** What breaks if not fixed
**Fix:** Specific action to resolve

### [MAJOR] Issue Title
**Location:** file/section reference
**Impact:** What is affected
**Fix:** Specific action to resolve

### [MINOR] Issue Title
**Location:** file/section reference
**Fix:** Specific action to resolve

---

## RECOMMENDATIONS

### [SUGGESTION] Recommendation
**Location:** file/section reference
**Benefit:** Why this improves the artifact

---

## QUESTIONS

### [QUESTION] What needs clarification
**Context:** Why this matters
```

## Severity Definitions

| Severity | Definition | Action Required |
|----------|------------|-----------------|
| **CRITICAL** | Blocks progress, causes failures, security issue | Must fix before proceeding |
| **MAJOR** | Significant quality or correctness issue | Should fix before approval |
| **MINOR** | Style, convention, minor improvement | Fix if time permits |
| **SUGGESTION** | Optional enhancement | Consider for future |

## Cascade Changes

If review reveals issues that affect earlier phases:
- Impl Plan changes → May require Design updates
- Test Plan changes → May require Impl Plan updates
- Code changes → Verify alignment with plans
