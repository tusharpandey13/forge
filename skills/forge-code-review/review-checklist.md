# Review Checklists

## Design Review Checklist

### Completeness
- [ ] All functional requirements from REQUIREMENTS.md are addressed
- [ ] All non-functional requirements have explicit solutions
- [ ] Test matrix covers happy path, error paths, and edge cases
- [ ] Wire formats documented for all network calls

### Clarity
- [ ] No ambiguous descriptions
- [ ] Public contracts fully specified (types, methods, errors)
- [ ] Design decisions documented with rationale
- [ ] Sequence diagrams for multi-component flows

### Correctness
- [ ] Solution actually solves the requirements
- [ ] Error handling strategy is complete
- [ ] Breaking changes identified with migration paths
- [ ] External references are valid and relevant

---

## Implementation Plan Review Checklist

### Alignment
- [ ] All design contracts are covered
- [ ] Follows codebase conventions (verified by analysis)
- [ ] Uses identified reusable utilities
- [ ] Implementation order respects dependencies

### Quality
- [ ] Pseudocode is detailed enough for line-by-line review
- [ ] No DRY violations (repeated logic across units)
- [ ] Single responsibility per unit
- [ ] Error handling explicit for every failure path

### Completeness
- [ ] All units have defined file locations
- [ ] Configuration and constants specified
- [ ] Edge cases from requirements handled
- [ ] Integration points documented

---

## Test Plan Review Checklist

### Coverage
- [ ] All implementation units have corresponding tests
- [ ] All functional requirements verified by tests
- [ ] All error paths tested
- [ ] All edge cases from requirements covered

### Quality
- [ ] Tests are behavior-focused (blackbox), not implementation-focused
- [ ] Assertions are precise (exact expected values)
- [ ] HTTP mocking library used for network calls, minimal other mocks
- [ ] Follows codebase test patterns

### Completeness
- [ ] Coverage mapping shows all requirements tested
- [ ] Fixtures and factories documented
- [ ] Mock strategy justified

---

## Code Review Checklist

### Correctness
- [ ] Implementation matches IMPL-PLAN pseudocode
- [ ] Implementation matches TEST-PLAN test cases
- [ ] Quality gate passes (tests, build, lint — per project toolchain)
- [ ] No regressions in existing tests

### Quality
- [ ] Code coverage meets minimum (typically 80%)
- [ ] Clean, readable, maintainable code
- [ ] Appropriate comments for complex logic
- [ ] Consistent error handling

### Security & Performance
- [ ] No security vulnerabilities introduced
- [ ] No obvious performance bottlenecks
- [ ] Sensitive data handled appropriately

---

## Severity Definitions

| Severity | Definition | Action |
|----------|------------|--------|
| **CRITICAL** | Blocks progress, causes failures, security vulnerability | Must fix before proceeding |
| **MAJOR** | Significant quality or correctness issue | Should fix before approval |
| **MINOR** | Style, convention, minor improvement | Fix if time permits |
| **SUGGESTION** | Optional enhancement, nice-to-have | Consider for future |

---

## Review Output Format

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

### [SUGGESTION] Recommendation Title
**Location:** file/section reference
**Benefit:** Why this improves the artifact

---

## QUESTIONS

### [QUESTION] What needs clarification
**Context:** Why this matters for the review
```
