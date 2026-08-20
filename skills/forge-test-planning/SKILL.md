---
name: forge-test-planning
description: Create test plan from implementation plan. Use when planning tests, creating test matrix, or working with IMPL-PLAN.md.
license: Proprietary
metadata:
  author: Auth0 SDKs Team <sdks@auth0.com>
---

# Test Planning

Create exhaustive test plan from implementation plan and design test matrix. Derives testing strategy from codebase conventions. NO actual test code — only pseudocode.

## When to Use

- User asks to create a test plan
- User references IMPL-PLAN.md
- Moving from impl planning to test planning

## Context Sources

- `.forge/FORGE-CONFIG.md` — test conventions, paths
- `.forge/state.json` — current state (verify phase 5 approved)
- `{feature_dir}/plan/IMPL-PLAN.md` — implementation details
- `{feature_dir}/design/DESIGN.md` — original test matrix (baseline)
- `{feature_dir}/requirement/REQUIREMENTS.md` — acceptance criteria
- Existing test files in codebase — primary source for conventions

See references/shared-phase-spec.md § feature-dir-note

## Process

See references/shared-phase-spec.md § mandatory-first-output — emit `FORGE :: TEST PLANNING`

### 1. Verify Prerequisites

Via `forge slice` — confirm Phase 5 (Impl Plan Review) status is "approved". Read FORGE-CONFIG.md for test conventions and paths.

### 2. Analyze Codebase Testing Conventions

Verify FORGE-CONFIG.md test conventions against actual codebase:
- Framework, file naming, directory structure
- Mocking strategy: libraries, what gets mocked, setup patterns
- Fixture/factory patterns, setup/teardown conventions, assertion style

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
- Language-agnostic pseudocode for test code

### 7. Plan Flow Tests

- Blackbox: call real public methods
- Mock only at boundaries the codebase already mocks
- Test complete user flows; minimize mocking

### 8. Write Test Pseudocode

Detailed setup, execution, assertions per test — using codebase convention patterns.

### 9. Self-Validate

See references/shared-phase-spec.md § self-validate. Also: all impl units have corresponding tests, all FRs mapped in coverage table.

### 10. Update State

Write `.phase-6-output.json` sidecar (schema: see references/shared-phase-spec.md § sidecar-schema).
Phase-specific decisions[] examples: "Test suites: N unit, M flow", "Total test cases: K"

See references/shared-phase-spec.md § orchestrator-note

## Deliverables

- `{feature_dir}/plan/TEST-PLAN.md` — use [test-plan-template.md](./references/test-plan-template.md)

## Quality Checks

- Codebase testing conventions analyzed and documented
- All implementation units have corresponding tests
- All FRs verified by tests
- All error paths tested; all edge cases covered
- Mocking strategy matches codebase conventions
- Assertions have precise expected values
- Flow tests are blackbox (behavior, not implementation)

## Error Handling

### Before Starting

See references/shared-phase-spec.md § error-cases (cases 1–4).

- Case 2 for this phase: Phase 5 (Impl Plan Review) must be "approved"
- Case 3 (Config not found) → WARN: "FORGE-CONFIG.md not found. Will infer test conventions from codebase." Continue.
- **IMPL-PLAN.md missing** → ERROR: "IMPL-PLAN.md not found at {{ expected_path }}" Return error; escalate.
- **DESIGN.md missing** → ERROR: "DESIGN.md not found at {{ expected_path }}. Cannot establish test matrix baseline." Return error; escalate.

### During Execution

- **Test framework ambiguous** → WARN: "Multiple test frameworks detected: {{ list }}. Using primary: {{ primary }}." Note in TEST-PLAN.md.
- **Mocking strategy unclear** → WARN: "Mocking strategy inconsistent. Documenting primary approach: {{ primary }}." Flag in test plan.

### Before Completing

- **Output not writable** → see § error-cases case 4
- **Placeholder or ambiguous tests** → WARN: "Incomplete test specs: {{ list }}. Escalating for clarification."

## Anti-Patterns

- Do NOT write actual test code
- Do NOT prescribe a mocking library — use whatever the codebase uses
- Do NOT invent testing patterns — follow existing ones
- Do NOT over-mock (avoid mocking internal modules)
- Do NOT test implementation details
- Do NOT silently fail

## Handoff

**Output:** `{feature_dir}/plan/TEST-PLAN.md` + `.phase-6-output.json`
**Next Phase:** forge-review (test plan review)
