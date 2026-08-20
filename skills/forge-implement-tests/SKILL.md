---
name: forge-implement-tests
description: Implement tests from TEST-PLAN.md. Use when writing tests from plan, implementing test code, or in phase 10 of forge workflow.
license: Proprietary
metadata:
  author: Auth0 SDKs Team <sdks@auth0.com>
---

# Test Implementation

Translates test plan pseudocode into real test code. Follows codebase test conventions from FORGE-CONFIG.md.

## When to Use

- User asks to implement tests from TEST-PLAN.md
- Phase 10 of the forge workflow
- User says "implement tests" after code review is approved

## Context Sources

- `.forge/FORGE-CONFIG.md` — test conventions, quality gate, paths
- `.forge/state.json` — current state (verify phase 9 approved)
- `{feature_dir}/plan/TEST-PLAN.md` — primary input (test pseudocode)
- `{feature_dir}/plan/IMPL-PLAN.md` — unit structure reference
- Implemented source code — the code being tested
- Existing test files — for convention reference

See references/shared-phase-spec.md § feature-dir-note

## Process

See references/shared-phase-spec.md § mandatory-first-output — emit `FORGE :: IMPLEMENT TESTS`

### 1. Verify Prerequisites

Via `forge slice` — confirm Phase 9 (Code Review) status is "approved", TEST-PLAN.md exists, source code from phase 8 exists. If not met → stop, nudge user to complete prior phases.

### 2. Parse Test Suites

Read TEST-PLAN.md. Extract: all test suites with targets, test pseudocode per case, mocking strategy, fixture/factory requirements.

### 3. Build Execution Plan

Test suites typically independent. Auto-decide:
- Independent suites → parallelize
- Suites sharing fixtures/state → sequential

```
FORGE :: TEST EXECUTION PLAN
  Unit test suites (parallel): Suite A, Suite B, Suite C
  Flow test suites (sequential): Flow 1, Flow 2
  Quality gate: [command from config]
```

### 4. Implement Each Test Suite

Per suite:

1. Read test pseudocode from TEST-PLAN.md
2. Read FORGE-CONFIG.md for test conventions: framework, file naming, directory structure, mocking library, setup/teardown, assertion style
3. Create test file following conventions
4. Translate pseudocode to real test code. **Apply Tautology Heuristic** (see ../forge/references/verification-protocol.md#protocol-b):
   - [ ] Test has at least one assertion
   - [ ] Assertions are NOT bare constants (expect(true).toBe(true))
   - [ ] Assertions do NOT test only mock configuration
   - [ ] Snapshot assertions also have behavioral assertions
   - [ ] All assertion values derived from code-under-test execution
   - Tests failing heuristic → rewrite before proceeding
5. Run the test file:
   - Pass → suite done
   - Fail → diagnose: test bug vs. source bug
     - Test bug → fix, re-run (max 2 attempts)
     - Source bug → log finding, continue
6. Record suite completion in `.phase-10-output.json`

### 5. Full Quality Gate

After all suites complete:

1. Run full quality gate. **Apply Proof-of-Work Protocol** (see ../forge/references/verification-protocol.md#protocol-a):
   - Capture tool version: `which <tool> && <tool> --version`
   - Extract work_count (tests executed, suite runs, coverage points)
   - work_count == 0 → gate FAILS even if exit code is 0
   - Log evidence in `.phase-10-output.json`
2. Verify coverage meets minimum (typically 80%, or as specified in config)
3. Gate fails → diagnose, fix targeted, re-run (max 2 attempts)
4. Gate passes → phase complete

### 6. Update State

Write `.phase-10-output.json` sidecar (schema: see references/shared-phase-spec.md § sidecar-schema).
Phase-specific: include quality_gate with test_results, coverage_percent, tautology_violations_fixed[], source_bugs_found[].

See references/shared-phase-spec.md § orchestrator-note

## Convention Adherence

Single most important rule: **follow existing test conventions exactly.**

- Same framework, mocking library, file naming, directory structure, describe/it/test style, assertion library
- TEST-PLAN.md conflicts with codebase conventions → follow codebase; document deviation

## Error Handling

### Before Starting

See references/shared-phase-spec.md § error-cases (cases 1–4).

- Case 2 for this phase: Phase 9 (Code Review) must be "approved"
- Case 3 (Config not found) → ERROR: "FORGE-CONFIG.md missing. Cannot determine test conventions or quality gate." Return error; escalate.
- **TEST-PLAN.md missing** → ERROR: "TEST-PLAN.md not found at {{ expected_path }}" Return error; escalate.
- **Source code missing** → ERROR: "Source code from phase 8 not found. Cannot implement tests." Return error; escalate.

### During Execution

- **Test framework mismatch** → WARN: "Framework mismatch (config: {{ config_framework }}, codebase: {{ actual }}). Using codebase." Document deviation.
- **Test suite fails after fix attempts** → WARN: "Suite {{ name }} still failing after 2 attempts. Reason: {{ reason }}" Document; continue.
- **Source bug found** → LOG: "Source bug: {{ description }}. Test: {{ test_name }}" Document; continue; note for code review escalation.
- **Mocking library issue** → ERROR: "Cannot setup mocking: {{ detail }}." Escalate; may need fixture or source fix.

### Before Completing

- **Output not writable** → see § error-cases case 4
- **Full quality gate fails (max retries)** → ERROR: "Quality gate failed after 2 attempts. Tests: {{ summary }}, Coverage: {{ coverage }}%"
- **Coverage below minimum** → ERROR: "Coverage {{ current }}% below minimum {{ minimum }}%. Must add more tests." Escalate.
- **Phase output not writable** → ERROR: "Cannot write phase output to {{ path }}: {{ reason }}" Escalate.

## Anti-Patterns

- Do NOT invent test patterns — follow what exists
- Do NOT use a different mocking library than the codebase
- Do NOT test implementation details — test observable behavior
- Do NOT skip running each suite after writing it
- Do NOT ignore source bugs found during testing — log them
- Do NOT silently fail

## Handoff

**Output:** Test source code + `.phase-10-output.json`
**Next Phase:** forge-review (test review)
