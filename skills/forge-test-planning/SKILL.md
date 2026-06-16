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
- `.forge/state.json` — current state, verify phase 5 approved
- `{feature_dir}/plan/IMPL-PLAN.md` — implementation details (absolute path from orchestrator)
  - **Example:** `/Users/alice/project/.forge/features/auth-middleware/plan/IMPL-PLAN.md`
- `{feature_dir}/design/DESIGN.md` — original test matrix (baseline)
- `{feature_dir}/requirement/REQUIREMENTS.md` — acceptance criteria
- Existing test files in codebase — primary source for conventions

**NOTE:** All artifact paths are absolute paths resolved by the orchestrator at dispatch time.

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: TEST PLANNING
```

### 1. Verify Prerequisites

Read .forge/state.json. Confirm Phase 5 (Impl Plan Review) status is "approved".
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

Write output artifact: `{feature_dir}/plan/TEST-PLAN.md`
- **Variable form:** `{feature_dir}/plan/TEST-PLAN.md`
- **Concrete example:** `/Users/alice/project/.forge/features/auth-middleware/plan/TEST-PLAN.md`

Write `.phase-6-output.json` sidecar (full absolute path provided by orchestrator):
```json
{
  "phase": 6,
  "status": "completed",
  "artifacts": [
    {
      "path": "{feature_dir}/plan/TEST-PLAN.md",
      "sha": "[git SHA]",
      "size_bytes": [size]
    }
  ],
  "decisions": [
    "Test suites: N unit, M flow",
    "Total test cases: K"
  ],
  "execution_details": {
    "model": "qc-readonly",
    "reasoning_lines": [count],
    "context_usage_percent": [%],
    "elapsed_seconds": [duration]
  }
}
```

**Orchestrator updates state.json** (skill does NOT write to state.json directly)
- Orchestrator reads .phase-6-output.json
- Orchestrator updates state.json with artifacts
- Orchestrator commits to .forge git

## Deliverables

- `{feature_dir}/plan/TEST-PLAN.md` — use [TEST-PLAN-template.md](./TEST-PLAN-template.md)

## Quality Checks

- Codebase testing conventions analyzed and documented
- All implementation units have corresponding tests
- All functional requirements verified by tests
- All error paths tested
- All edge cases covered
- Mocking strategy matches codebase conventions
- Assertions have precise expected values
- Flow tests are blackbox (behavior, not implementation)

## Error Handling

### Before Starting

1. **State.json Missing or Invalid:**
   - If `.forge/state.json` cannot be found or is corrupted
   - **Action:** ERROR: "state.json missing or corrupted. Run /forge to reinitialize."
   - **Recovery:** Do not proceed; return error

2. **Prerequisite Phase Not Complete:**
   - If Phase 5 (Impl Plan Review) status is not "approved"
   - **Action:** ERROR: "Phase 5 (Impl Plan Review) must be approved first. Current status: {{ phase_5.status }}"
   - **Recovery:** Return error; do not start test planning

3. **IMPL-PLAN.md Missing:**
   - If implementation plan file does not exist
   - **Action:** ERROR: "IMPL-PLAN.md not found at {{ expected_path }}"
   - **Recovery:** Return error; escalate

4. **DESIGN.md Missing:**
   - If design file (needed for test matrix baseline) does not exist
   - **Action:** ERROR: "DESIGN.md not found at {{ expected_path }}. Cannot establish test matrix baseline."
   - **Recovery:** Return error; escalate

5. **Config Not Found:**
   - If `.forge/FORGE-CONFIG.md` missing
   - **Action:** WARN: "FORGE-CONFIG.md not found. Will infer test conventions from codebase."
   - **Recovery:** Continue with codebase analysis

### During Execution

6. **Test Framework Ambiguous:**
   - If multiple test frameworks detected in codebase
   - **Action:** WARN: "Multiple test frameworks detected: {{ list }}. Using primary: {{ primary }}"
   - **Recovery:** Continue with primary framework; note in TEST-PLAN.md

7. **Mocking Strategy Unclear:**
   - If codebase uses multiple mocking approaches inconsistently
   - **Action:** WARN: "Mocking strategy inconsistent across tests. Documenting primary approach: {{ primary }}."
   - **Recovery:** Continue; flag uncertainty in test plan

### Before Completing

8. **Output Path Not Writable:**
   - If `.forge/features/<slug>/plan/` cannot be created or written to
   - **Action:** ERROR: "Cannot write to {{ output_path }}: {{ reason }}"
   - **Recovery:** Return error; do not complete

9. **Placeholder or Ambiguous Tests:**
   - If TEST-PLAN.md contains `[TBD]`, unspecified test cases, or pseudocode gaps
   - **Action:** WARN: "Incomplete test specifications: {{ list }}. Escalating for clarification."
   - **Recovery:** List specific sections; ask for guidance

## Anti-Patterns

- Do NOT write actual test code
- Do NOT prescribe a mocking library — use whatever the codebase uses
- Do NOT invent testing patterns — follow existing ones
- Do NOT over-mock (avoid mocking internal modules)
- Do NOT test implementation details
- Do NOT silently fail — report all errors with full context

## Handoff

**Output:** `{feature_dir}/plan/TEST-PLAN.md` + `.phase-6-output.json`

**Next Phase:** forge-review (test plan review)
