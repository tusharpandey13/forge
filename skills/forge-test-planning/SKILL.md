---
name: forge-test-planning
description: Create test plan from implementation plan. Use when planning tests, creating test matrix, or working with IMPL-PLAN.md.
---

# Test Planning

Create exhaustive test plan from implementation plan and design test matrix. Derives testing strategy from codebase conventions. NO actual test code — only pseudocode.

## When to Use

- User asks to create a test plan
- User references IMPL-PLAN.md
- Moving from impl planning to test planning

## Context Sources

- `.forge/FORGE-CONFIG.md` — test conventions, paths
- `.forge/FORGE-LOGS.md` — current state, verify phase 5 approved
- `{plan-dir}/IMPL-PLAN.md` — implementation details
- `{design-dir}/DESIGN.md` — original test matrix (baseline)
- `{requirements-dir}/REQUIREMENTS.md` — acceptance criteria
- Existing test files in codebase — primary source for conventions

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: TEST PLANNING
```

### 1. Verify Prerequisites

Read FORGE-LOGS.md. Confirm Phase 5 (Impl Plan Review) status is `approved`.
Read FORGE-CONFIG.md for test conventions and paths.

### 2. Analyze Codebase Testing Conventions

Verify FORGE-CONFIG.md test conventions against actual codebase:
- Framework, file naming, directory structure
- Mocking strategy: what libraries, what gets mocked, setup patterns
- Fixture/factory patterns, setup/teardown conventions
- Assertion style

Update FORGE-CONFIG.md if new conventions discovered.

### 3. Review Design Test Matrix

Use DESIGN.md test matrix as baseline.

### 4. Analyze IMPL-PLAN.md

Identify additional edge cases and error paths from implementation complexity.

### 5. Update Test Matrix

Add new test cases discovered from implementation analysis.

### 6. Plan Unit Tests

Per function/method from impl plan:
- Happy path and all error paths
- Follow mocking conventions from config
- Use language-agnostic pseudocode for test code

### 7. Plan Flow Tests

- Blackbox approach: call real public methods
- Mock only at boundaries the codebase already mocks
- Test complete user flows
- Minimize mocking

### 8. Write Test Pseudocode

Detailed setup, execution, and assertions for each test — using patterns from codebase conventions.

### 9. Self-Validate

Re-read the artifact. Verify:
- No `[placeholder]` or `TBD` text remains
- All impl units have corresponding tests
- All FRs mapped to tests in coverage table
Fix any issues silently.

### 10. Update State

Update FORGE-LOGS.md:
```markdown
### Phase 6: Test Planning — completed
- Started: [timestamp]
- Completed: [timestamp]
- Artifact: [path]/TEST-PLAN.md
- Test suites: [count] unit, [count] flow
- Total test cases: [count]
- Coverage mapping: [count] FRs covered
- Commit: [SHA]
```

Commit:
```bash
git -C .forge add -A && git -C .forge commit -m "forge: phase 6 — test plan complete"
```

## Deliverables

- `{plan-dir}/TEST-PLAN.md` — use [TEST-PLAN-template.md](./TEST-PLAN-template.md)

## Quality Checks

- Codebase testing conventions analyzed and documented
- All implementation units have corresponding tests
- All functional requirements verified by tests
- All error paths tested
- All edge cases covered
- Mocking strategy matches codebase conventions
- Assertions have precise expected values
- Flow tests are blackbox (behavior, not implementation)

## Anti-Patterns

- Do NOT write actual test code
- Do NOT prescribe a mocking library — use whatever the codebase uses
- Do NOT invent testing patterns — follow existing ones
- Do NOT over-mock (avoid mocking internal modules)
- Do NOT test implementation details

## Handoff

**Output:** `{plan-dir}/TEST-PLAN.md`

**Next Phase:** forge-review (test plan review)
