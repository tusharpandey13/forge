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
- `.forge/state.json` — current state, verify phase 9 approved
- `{feature_dir}/plan/TEST-PLAN.md` — primary input (absolute path from orchestrator, test pseudocode)
- `{feature_dir}/plan/IMPL-PLAN.md` — unit structure reference
- Implemented source code — the code being tested
- Existing test files — for convention reference

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: IMPLEMENT TESTS
```

### 1. Verify Prerequisites

Read .forge/state.json. Confirm:
- Phase 9 (Code Review) status is "approved"
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

Write `.phase-10-output.json` sidecar in `{feature_dir}/`:
```json
{
  "phase": 10,
  "status": "completed",
  "artifacts": [
    {
      "path": "[absolute path to test file 1]",
      "sha": "[git SHA]",
      "size_bytes": [size]
    },
    {
      "path": "[absolute path to test file 2]",
      "sha": "[git SHA]",
      "size_bytes": [size]
    }
  ],
  "decisions": [
    "Suites: N unit, M flow",
    "Test results: passed/total passing"
  ],
  "execution_details": {
    "model": "qc-readonly",
    "reasoning_lines": [count],
    "context_usage_percent": [%],
    "elapsed_seconds": [duration]
  },
  "quality_gate": {
    "passed": true,
    "test_results": "[passed]/[total]",
    "coverage_percent": [X],
    "source_bugs_found": ["list if any"]
  }
}
```

**Orchestrator updates state.json** (skill does NOT write to state.json directly)
- Orchestrator reads .phase-10-output.json
- Orchestrator updates state.json with artifacts and quality gate result
- Orchestrator commits to .forge git

## Convention Adherence

The single most important rule: **follow existing test conventions exactly.**

- Use the same framework the codebase uses
- Use the same mocking library and patterns
- Use the same file naming and directory structure
- Use the same describe/it/test grouping style
- Use the same assertion library and style

If TEST-PLAN.md prescribes something that conflicts with codebase conventions, follow the codebase. Document the deviation.

## Error Handling

### Before Starting

1. **State.json Missing or Invalid:**
   - If `.forge/state.json` cannot be found or is corrupted
   - **Action:** ERROR: "state.json missing or corrupted. Run /forge to reinitialize."
   - **Recovery:** Do not proceed; return error

2. **Prerequisite Phase Not Complete:**
   - If Phase 9 (Code Review) status is not "approved"
   - **Action:** ERROR: "Phase 9 (Code Review) must be approved first. Current status: {{ phase_9.status }}"
   - **Recovery:** Return error; do not start testing

3. **TEST-PLAN.md Missing:**
   - If test plan file does not exist
   - **Action:** ERROR: "TEST-PLAN.md not found at {{ expected_path }}"
   - **Recovery:** Return error; escalate

4. **Source Code Missing:**
   - If implemented source files from phase 8 do not exist
   - **Action:** ERROR: "Source code from phase 8 not found. Cannot implement tests."
   - **Recovery:** Return error; escalate

5. **Config Not Found:**
   - If `.forge/FORGE-CONFIG.md` missing
   - **Action:** ERROR: "FORGE-CONFIG.md missing. Cannot determine test conventions or quality gate command."
   - **Recovery:** Return error; escalate

### During Execution

6. **Test Framework Mismatch:**
   - If configured test framework doesn't match actual codebase framework
   - **Action:** WARN: "Test framework mismatch (config: {{ config_framework }}, codebase: {{ actual_framework }}). Using codebase framework."
   - **Recovery:** Continue with actual framework; document deviation

7. **Test Suite Fails After Fix Attempts:**
   - If a test suite fails after 2 attempts to fix
   - **Action:** WARN: "Test suite {{ suite_name }} still failing after 2 attempts. Reason: {{ reason }}"
   - **Recovery:** Document; continue to next suite; log finding

8. **Source Bug Found During Testing:**
   - If tests reveal bugs in the implemented code
   - **Action:** LOG: "Source bug found: {{ description }}. Test: {{ test_name }}"
   - **Recovery:** Document bug; continue testing; note for code review escalation

9. **Mocking Library Issue:**
   - If mocking setup fails (library not installed, API changed)
   - **Action:** ERROR: "Cannot setup mocking: {{ detail }}. Cannot proceed with test suite."
   - **Recovery:** Escalate; may need fixture or source code fix

### Before Completing

10. **Output Path Not Writable:**
    - If test files cannot be written to designated paths
    - **Action:** ERROR: "Cannot write test file to {{ path }}: {{ reason }}"
    - **Recovery:** Return error; escalate

11. **Full Quality Gate Fails (Max Retries):**
    - If full quality gate (test run + coverage) fails after 2 fix attempts
    - **Action:** ERROR: "Quality gate failed after 2 attempts. Tests: {{ test_summary }}, Coverage: {{ coverage }}%"
    - **Recovery:** Return error with diagnostic info; escalate

12. **Coverage Below Minimum:**
    - If test coverage falls below configured minimum
    - **Action:** ERROR: "Test coverage {{ current }}% below minimum {{ minimum }}%. Must add more tests."
    - **Recovery:** Return error; escalate for additional test planning

13. **Phase Output File Not Writable:**
    - If `.phase-10-output.json` cannot be written
    - **Action:** ERROR: "Cannot write phase output to {{ path }}: {{ reason }}"
    - **Recovery:** Return error; escalate

## Anti-Patterns

- Do NOT invent test patterns — follow what exists
- Do NOT use a different mocking library than the codebase
- Do NOT test implementation details — test observable behavior
- Do NOT skip running each suite after writing it
- Do NOT ignore source bugs found during testing — log them
- Do NOT silently fail — report all errors with full context

## Handoff

**Output:** Test source code + `.phase-10-output.json`

**Next Phase:** forge-review (test review)
