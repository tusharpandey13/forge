---
name: forge-test-planning
description: Create test plan from implementation plan. Use when planning tests, creating test matrix, or working with IMPL-PLAN.md.
---

# Test Planning

Create exhaustive test plan from implementation plan and design test matrix. Derives testing strategy from codebase conventions. NO actual test code—only pseudocode.

## When to Use

- User asks to create a test plan or plan tests
- User references `docs/plan/IMPL-PLAN.md`
- Moving from impl planning to test planning

## Context Sources

- `docs/plan/IMPL-PLAN.md` - Implementation details reveal additional complexity
- `docs/design/DESIGN.md` - Original test matrix (baseline)
- `docs/requirement/REQUIREMENTS.md` - Acceptance criteria
- **Existing test files in codebase** - Primary source for conventions, patterns, and mocking strategy

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: TEST PLANNING
```

1. **Analyze Codebase Testing Conventions (FIRST):**
   - Find existing test files — identify framework (jest, vitest, mocha, pytest, go test, etc.)
   - Study file naming patterns, directory structure, describe/it patterns
   - Identify mocking strategy: what libraries are used, what gets mocked, how mocks are set up and torn down
   - Identify fixture/factory patterns, setup/teardown conventions
   - Document all conventions in the Test Conventions table
2. **Review Design Test Matrix:** Use as baseline
3. **Analyze IMPL-PLAN.md:** Identify additional edge cases and error paths from implementation complexity
4. **Update Test Matrix:** Add new test cases discovered from implementation
5. **Plan Unit Tests:**
   - Per function/method from impl plan
   - Cover happy path and all error paths
   - Follow the mocking conventions discovered in step 1
6. **Plan Integration/Flow Tests:**
   - Call real public methods (blackbox approach)
   - Follow codebase conventions for mocking external dependencies
   - Test complete user flows
   - Minimize mocking — only mock at boundaries the codebase already mocks
7. **Write Test Pseudocode:** Detailed setup, execution, and assertions for each test — using patterns from step 1
8. **Verify Convention Alignment:** Ensure every planned test follows discovered conventions

## Deliverables

- `docs/plan/TEST-PLAN.md` - Use template at [TEST-PLAN-template.md](./TEST-PLAN-template.md)

## Quality Checks

- [ ] Codebase testing conventions analyzed and documented
- [ ] All implementation units have corresponding tests
- [ ] All functional requirements verified by tests
- [ ] All error paths are tested
- [ ] All edge cases from requirements are covered
- [ ] Mocking strategy matches codebase conventions (not invented from scratch)
- [ ] Assertions have precise expected values
- [ ] Follows existing test patterns in codebase (framework, naming, structure)
- [ ] Flow tests are blackbox (test behavior, not implementation)

## Anti-Patterns

- Do NOT write actual test code
- Do NOT prescribe a mocking library — use whatever the codebase already uses
- Do NOT invent testing patterns — discover and follow existing ones
- Do NOT over-mock (avoid mocking internal modules)
- Do NOT test implementation details (test observable behavior)

## Handoff

**Output:** `docs/plan/TEST-PLAN.md`

**Next Phase:** forge-code-review (test plan review), then implementation
