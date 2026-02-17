---
name: forge-test-planning
description: Create test plan from implementation plan. Use when planning tests, creating test matrix, or working with IMPL-PLAN.md.
---

# Test Planning

Create exhaustive test plan from implementation plan and design test matrix. Uses MSW for HTTP mocking. NO actual test code—only pseudocode.

## When to Use

- User asks to create a test plan or plan tests
- User references `docs/plan/IMPL-PLAN.md`
- Moving from impl planning to test planning

## Context Sources

- `docs/plan/IMPL-PLAN.md` - Implementation details reveal additional complexity
- `docs/design/DESIGN.md` - Original test matrix (baseline)
- `docs/requirement/REQUIREMENTS.md` - Acceptance criteria
- Existing test patterns in codebase

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: TEST PLANNING
```

1. **Review Design Test Matrix:** Use as baseline
2. **Analyze IMPL-PLAN.md:** Identify additional edge cases and error paths from implementation complexity
3. **Update Test Matrix:** Add new test cases discovered from implementation
4. **Plan Unit Tests:**
   - Per function/method from impl plan
   - Cover happy path and all error paths
   - Mock only external dependencies
5. **Plan Flow Tests (Pseudo-E2E):**
   - Call real public methods (blackbox approach)
   - Use MSW for HTTP layer mocking ONLY
   - Test complete user flows
   - Minimize other mocks
6. **Write Test Pseudocode:** Detailed setup, execution, and assertions for each test
7. **Follow Codebase Conventions:** Match existing test patterns

## Test Strategy

| Type | Approach |
|------|----------|
| **Unit Tests** | Isolate single function/method, fast, deterministic, mock only external dependencies |
| **Flow Tests** | Call real public methods, MSW for HTTP, blackbox behavior testing, minimal mocks |

## Deliverables

- `docs/plan/TEST-PLAN.md` - Use template at [TEST-PLAN-template.md](./TEST-PLAN-template.md)

## Quality Checks

- [ ] All implementation units have corresponding tests
- [ ] All functional requirements verified by tests
- [ ] All error paths are tested
- [ ] All edge cases from requirements are covered
- [ ] MSW used for HTTP mocking only (minimal other mocks)
- [ ] Assertions have precise expected values
- [ ] Follows existing test patterns in codebase
- [ ] Flow tests are blackbox (test behavior, not implementation)

## Anti-Patterns

- Do NOT write actual test code
- Do NOT over-mock (only HTTP via MSW, avoid mocking internal modules)
- Do NOT test implementation details (test observable behavior)

## Handoff

**Output:** `docs/plan/TEST-PLAN.md`

**Next Phase:** forge-code-review (test plan review), then implementation
