---
name: forge-implement-tests
description: Implement tests from TEST-PLAN.md. Use when writing tests from plan, implementing test code, or in phase 10 of forge workflow.
---

# Test Implementation

Translates test plan pseudocode into real test code. Follows codebase test conventions from FORGE-CONFIG.md.

## When to Use

- User asks to implement tests from TEST-PLAN.md
- Phase 10 of the forge workflow
- User says "implement tests" after code review is approved

## Context Sources

- `.forge/FORGE-CONFIG.md` — test conventions, quality gate, paths
- `.forge/FORGE-LOGS.md` — current state, verify phase 9 approved
- `{plan-dir}/TEST-PLAN.md` — primary input (test pseudocode)
- `{plan-dir}/IMPL-PLAN.md` — unit structure reference
- Implemented source code — the code being tested
- Existing test files — for convention reference

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: IMPLEMENT TESTS
```

### 1. Verify Prerequisites

Read FORGE-LOGS.md. Confirm:
- Phase 9 (Code Review) status is `approved`
- TEST-PLAN.md exists and is approved
- Source code from phase 8 exists

If not met → stop and nudge user to complete prior phases.

### 2. Parse Test Suites

Read TEST-PLAN.md. Extract:
- All test suites with their targets
- Test pseudocode for each case
- Mocking strategy from the conventions table
- Fixture/factory requirements

### 3. Build Execution Plan

Test suites are typically independent (each tests a different unit/flow). Auto-decide:
- Independent suites → can parallelize
- Suites sharing fixtures/state → sequential
- Log the decision

```
FORGE :: TEST EXECUTION PLAN
  Unit test suites (parallel): Suite A, Suite B, Suite C
  Flow test suites (sequential): Flow 1, Flow 2
  Quality gate: [command from config]
```

### 4. Implement Each Test Suite

For each suite:

1. Read the test pseudocode from TEST-PLAN.md
2. Read FORGE-CONFIG.md for test conventions:
   - Framework (vitest, jest, pytest, go test, etc.)
   - File naming pattern
   - Directory structure (co-located, __tests__, test/)
   - Mocking approach and library
   - Setup/teardown patterns
   - Assertion style
3. Create test file following conventions
4. Translate pseudocode to real test code:
   - Setup → real setup using convention patterns
   - Execution → real function/method calls
   - Assertions → real assertions using convention library
   - Teardown → real cleanup using convention patterns
5. Run the test file:
   - Pass → suite done
   - Fail → diagnose: test bug vs. source bug
     - Test bug → fix test, re-run (max 2 attempts)
     - Source bug → log finding, continue (code review should have caught this)
6. Update FORGE-LOGS.md with suite completion

### 5. Full Quality Gate

After all suites complete:

1. Run full quality gate:
   ```
   [quality gate command from config]
   ```
2. Verify coverage meets minimum (typically 80%, or as specified in config)
3. If gate fails:
   - Diagnose: which tests fail? which lint rules break?
   - Fix targeted issues
   - Re-run (max 2 attempts)
4. If gate passes → phase complete

### 6. Update State

Update FORGE-LOGS.md:
```markdown
### Phase 10: Test Implementation — completed
- Started: [timestamp]
- Completed: [timestamp]
- Suites implemented: [N] unit, [N] flow
- Execution strategy: [parallel/sequential]
- Test results: [passed]/[total] passing
- Coverage: [X]%
- Quality gate: passed
- Source bugs found: [list if any]
- Commit: [SHA]
```

Commit:
```bash
git -C .forge add -A && git -C .forge commit -m "forge: phase 10 — test implementation complete"
```

## Convention Adherence

The single most important rule: **follow existing test conventions exactly.**

- Use the same framework the codebase uses
- Use the same mocking library and patterns
- Use the same file naming and directory structure
- Use the same describe/it/test grouping style
- Use the same assertion library and style

If TEST-PLAN.md prescribes something that conflicts with codebase conventions, follow the codebase. Document the deviation.

## Anti-Patterns

- Do NOT invent test patterns — follow what exists
- Do NOT use a different mocking library than the codebase
- Do NOT test implementation details — test observable behavior
- Do NOT skip running each suite after writing it
- Do NOT ignore source bugs found during testing — log them

## Handoff

**Output:** Test source code + FORGE-LOGS.md updated

**Next Phase:** forge-review (test review)
