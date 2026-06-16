# Verification Protocol — Quality Gates & Test Validity

## Overview

Forge quality gates and test reviews are subject to three systematic failures that ship false greens:

1. **Silent no-ops:** Quality gate commands exit 0 without doing real work (tsc matches 0 files, jest finds 0 tests, skillsaw analyzer pointed at wrong path). Agent reports "clean/pass" but real errors ship.
2. **Tautological tests:** Tests assert nothing meaningful (bare-constant assertions, testing mocks instead of code, snapshot-only with no behavior check). All pass; false confidence. Real defects undetected.
3. **False-positive findings:** Code review flags internal APIs or test code paths while shipped surface behaves differently. Finding not reproducible on public API. Severity inflated to CRITICAL incorrectly.

This protocol provides three reusable mechanisms to prevent each failure class.

---

## Protocol A: Proof-of-Work Protocol (Anti Silent-No-Op)

### Problem Statement

Quality gate and static analysis commands can exit successfully (exit code 0) WITHOUT performing any real work. Examples:

- `tsc` with no TypeScript files in scope (pattern matches 0 files) → exit 0, no work done
- `jest --passWithNoTests` with no test files discovered → exit 0, 0 tests ran
- `eslint` on wrong directory → exit 0, 0 files linted
- `pytest` test collection fails silently → exit 0, 0 tests collected
- `skillsaw` (or similar analyzer) pointed at wrong path → exit 0, 0 items analyzed

**Rule:** A gate command returning exit code 0 with work_count == 0 is a FAILURE, not a pass. The command performed no actual verification.

### Command Classes

Proof-of-Work Protocol applies to:
- **Type checkers:** `tsc`, `mypy`, `go vet`, `dlv`, similar
- **Linters:** `eslint`, `pylint`, `ruff`, `flake8`, `golint`, similar
- **Test runners:** `jest`, `vitest`, `pytest`, `go test`, `gtest`, similar
- **Security/static analyzers:** `skillsaw`, `semgrep`, `sonarqube`, SAST tools, similar

### Protocol: Mandatory Evidence Collection

Before any gate command is reported as PASS (or FAIL), the executing agent MUST capture and log this evidence:

#### 1. Tool Presence + Version

```bash
# Always run before the gate command:
which <tool>      # Verify tool is installed and in PATH
<tool> --version  # Capture exact version
```

**Example:**
```bash
which tsc
/usr/local/bin/tsc

tsc --version
Version 5.3.2
```

#### 2. Work-Count Evidence

Capture a numeric count of actual work performed by the gate command. The exact metric depends on the tool class:

| Tool Class | Work-Count Metric | Example |
|-----------|------------------|---------|
| Type checker | Files checked | `tsc found 42 files` |
| Linter | Files linted | `eslint checked 15 files` |
| Test runner | Tests executed | `jest ran 87 tests` |
| Analyzer | Items analyzed | `skillsaw found 200 potential issues` |

**Critical:** Extract the work-count from command output. If the tool doesn't report it, instrument the count programmatically (e.g., count discovered files before running the tool).

#### 3. Outcome Evaluation

After capturing evidence:

```
IF work_count == 0:
  RESULT: FAIL (gate did not run on any content)
  ACTION: Do not report as pass, no matter exit code
  REASON: Zero coverage indicates command misconfiguration or path error

ELSE IF work_count > 0:
  Continue with normal exit code interpretation:
  - exit 0 + work_count > 0 → PASS
  - exit != 0 + work_count > 0 → FAIL
```

### Checklist: Agent Proof-of-Work Execution

Every agent, EVERY TIME it runs a quality gate or analysis command, must:

- [ ] Verify tool is installed: `which <tool>`
- [ ] Capture tool version: `<tool> --version`
- [ ] Run the gate command (e.g., `tsc`, `jest`, `eslint`)
- [ ] Extract work_count from output (or instrument programmatically)
- [ ] **HALT if work_count == 0:** Do NOT report pass; escalate to user/task owner
- [ ] Log evidence: tool version, work_count, exit code
- [ ] Report outcome: PASS (work_count > 0, exit 0) or FAIL (exit != 0 or work_count == 0)

### Pseudocode: Post-Gate Validation

```
FUNCTION validate_gate_execution(tool, command, output, exit_code):
    // Step 1: Tool presence
    tool_path = RUN("which " + tool)
    version = RUN(tool + " --version")
    LOG("Tool: " + tool_path + " Version: " + version)

    // Step 2: Extract work-count from output
    work_count = EXTRACT_WORK_COUNT(output, tool_class)
    LOG("Work count: " + work_count)

    // Step 3: Evaluate
    IF work_count == 0:
        RETURN {passed: false, reason: "No work performed (work_count=0)", severity: "GATE_FAIL"}
    
    IF exit_code == 0:
        RETURN {passed: true, work_count: work_count, exit_code: 0}
    ELSE:
        RETURN {passed: false, exit_code: exit_code, work_count: work_count, reason: "Tool reported errors"}
END FUNCTION
```

---

## Protocol B: Tautology Heuristic (Anti-Tautological Tests)

### Problem Statement

Tests can pass while asserting nothing meaningful. Examples:

- Zero assertions: `test("foo", () => { foo(); })` — function called but nothing verified
- Bare-constant assertions: `expect(true).toBe(true)`, `assert True`, `assert 1 == 1` — always pass
- Testing mocks: `expect(mockFn.return_value).toBe(42)` — verifies mock config, not code behavior
- Snapshot-only: `expect(result).toMatchSnapshot()` with no behavioral assertion about snapshot content
- Mock-coupled: test asserts `mockFn` was called, but `mockFn` is configured to return a fixed value — testing the mock, not the code under test

**Rule:** Each test must assert on a value DERIVED from code-under-test execution, not on mocks' configured return values or tautologies.

### Heuristic: Static Detection (No Runtime Mutation)

Apply this heuristic to EVERY test written or reviewed in the codebase. No test passes into code review (phase 9) or phase 11 (test review) without clearing this heuristic.

#### Check 1: Zero Assertions

**Flag:** Test body contains no `expect()`, `assert()`, `assertEqual()`, or framework-specific assertion call.

```javascript
// BAD: No assertions
test("should call foo", () => {
  foo();  // ← function called but nothing checked
});

// GOOD: Has assertion
test("should call foo", () => {
  const result = foo();
  expect(result).toBe(42);  // ← assertion on derived value
});
```

#### Check 2: Bare-Constant Assertions

**Flag:** Assertion body is a constant or tautology:
- `expect(true).toBe(true)` / `expect(1).toBe(1)` / `assert True`
- Comparing literal constants: `expect("foo").toBe("foo")`
- No derived computation involved

```javascript
// BAD: Tautology
test("setup works", () => {
  setup();
  expect(true).toBe(true);  // ← always passes, meaningless
});

// GOOD: Assertion on derived state
test("setup works", () => {
  setup();
  expect(isInitialized()).toBe(true);  // ← isInitialized() result is derived from setup()
});
```

#### Check 3: Testing Mock Configuration

**Flag:** Test asserts ONLY on a mock's configured return value, not on code-under-test's call to the mock.

```javascript
// BAD: Testing mock, not code
test("should fetch user", () => {
  const mockFetch = jest.fn().mockResolvedValue({ id: 1 });
  expect(mockFetch.mock.results[0].value).toBe({ id: 1 });  // ← testing mock's own config
});

// GOOD: Testing code calling the mock
test("should fetch user", () => {
  const mockFetch = jest.fn().mockResolvedValue({ id: 1 });
  const user = getUser(mockFetch);
  expect(user.id).toBe(1);  // ← user object derived from calling getUser() with mock
});
```

#### Check 4: Snapshot-Only Without Behavior

**Flag:** Test uses `toMatchSnapshot()` or snapshot assertion with NO additional behavioral assertion about what the snapshot should contain.

```javascript
// BAD: Snapshot without behavior check
test("renders correctly", () => {
  const result = render();
  expect(result).toMatchSnapshot();  // ← only snapshot, no assertion about structure/content
});

// GOOD: Snapshot + behavior assertions
test("renders correctly", () => {
  const result = render();
  expect(result.children.length).toBe(3);  // ← behavioral assertion
  expect(result).toMatchSnapshot();  // ← snapshot guards against accidental change
});
```

#### Check 5: Derived Value Requirement

**Flag:** Every test must assert on a value whose computation DEPENDS on code-under-test execution.

```javascript
// BAD: Mock assertion without code dependency
test("calls handler", () => {
  const handler = jest.fn();
  expect(handler).toHaveBeenCalled();  // ← "handler" is never called; assertion will fail or always pass
});

// GOOD: Assert on value derived from code calling the handler
test("calls handler", () => {
  const handler = jest.fn();
  const result = processEvent(handler);  // ← code-under-test calls handler
  expect(handler).toHaveBeenCalled();  // ← assertion depends on processEvent's behavior
  expect(result.success).toBe(true);  // ← result derived from processEvent
});
```

### Checklist: Agent Tautology Detection

Every agent, EVERY TIME it writes a test or reviews tests, must apply:

- [ ] **Zero Assertions:** Does the test have at least one assertion (`expect()`, `assert()`, etc.)?
- [ ] **Bare Constants:** Do assertions compare constants, or do they assert on values derived from code-under-test?
- [ ] **Mock Testing:** If mocks are used, does the test assert on code's CALL to the mock, or on the mock's own config?
- [ ] **Snapshot Behavior:** If snapshots are used, is there a behavioral assertion in addition to the snapshot?
- [ ] **Derivation:** Trace each assertion value back to code-under-test. Is the value computed as a result of calling the code, or is it hardcoded?

**Fail Criteria:** Test must be rewritten if ANY check fails.

---

## Protocol C: Surface-Aware Finding Verification (Anti False-Positive)

### Problem Statement

Code reviews can flag issues on internal/test APIs while the public shipped surface behaves differently. Example:

- Finding: "Internal client tuple return is not wrapped" (applies to internal API)
- Reality: Public shipped client unwraps tuple and throws (behavior is correct on public surface)
- Severity: Incorrectly marked CRITICAL when finding doesn't apply to shipped code

**Rule:** Before marking a finding CRITICAL or MAJOR, the reviewer must verify it reproduces on the public/shipped API surface that consumers actually use.

### Protocol: Pre-Gate Finding Verification

For every CRITICAL or MAJOR finding proposed in a code review (phase 9) or test review (phase 11), the reviewer MUST:

#### Step 1: Identify Code Surface

Classify the code location:

```
PUBLIC surface:
  - APIs, functions, classes exported in public SDK/library interface
  - HTTP handlers, REST endpoints, gRPC methods exposed to external consumers
  - Public types and interfaces in type signatures

INTERNAL surface:
  - Utility functions, helpers, private modules (not exported)
  - Test doubles, mocks, fixtures
  - Internal implementation details
```

#### Step 2: Reproduce Against Public Surface

**If finding is in INTERNAL code:**
- Trace how the internal code is called from PUBLIC surface
- Execute the finding's scenario against the PUBLIC surface (e.g., call the public function that uses the internal code)
- Verify the finding's impact is observable on the public surface
- If NOT reproducible on public surface → downgrade severity to MINOR or consider dismissal

**If finding is in PUBLIC code:**
- Reproduce directly (no need to trace further)
- Finding applies as-is

**If finding is in TEST code:**
- Classify as INTERNAL (tests are not shipped)
- Findings on test code should not block product release
- Mark as SUGGESTION unless the test bug indicates a source code bug

#### Step 3: Document Reproduction

Cite the finding verification in the review artifact:

```markdown
### [CRITICAL] Finding Title
- Location: src/client.ts line 42
- Finding: [description]
- Surface: PUBLIC (exported in client.ts)
- Reproduction: [describe how to reproduce against public API]
  - Call: `const result = client.method()`
  - Observe: [what happens]
  - Expected: [what should happen]
  - Verdict: **Reproducible on public surface** → CRITICAL severity justified
```

OR (if not reproducible):

```markdown
### [MAJOR → MINOR] Finding Title
- Location: src/internal/utils.ts line 15
- Finding: [description]
- Surface: INTERNAL (not exported)
- Reproduction attempt:
  - Traced public API call path: `client.process()` → `internal.validate()`
  - Executed: `client.process()` with inputs that trigger `internal.validate()`
  - Result: Public API surface handles scenario correctly; finding doesn't affect behavior
  - Verdict: **Not reproducible on public surface** → Downgrade to MINOR
```

### Checklist: Reviewer Surface-Aware Verification

For every CRITICAL or MAJOR finding in phases 9 or 11 (code/test review):

- [ ] **Classify surface:** Is the finding in PUBLIC, INTERNAL, or TEST code?
- [ ] **Trace call path:** If INTERNAL, which public API calls this code?
- [ ] **Reproduce:** Execute the scenario against the shipped surface
- [ ] **Observe behavior:** Does the public API exhibit the finding's impact?
  - Yes → Keep severity (CRITICAL/MAJOR)
  - No → Downgrade to MINOR (or suggest dismissal)
- [ ] **Document:** Cite reproduction in review artifact

**Fail Criteria:** CRITICAL/MAJOR finding must include reproduction evidence against public surface. Findings on INTERNAL or TEST code must be justified with a trace to public surface impact.

---

## Protocol Integration Points

### Phase 8 (Code Implementation, forge-implement/SKILL.md)

In the **Quality Gate** section:
- Require running Proof-of-Work Protocol after each quality gate command
- FAIL the gate if `work_count == 0`, even if exit code is 0
- Log tool version, work_count, exit code in `.phase-8-output.json`

### Phase 10 (Test Implementation, forge-implement-tests/SKILL.md)

In the **Test Suite Implementation** section:
- Apply Tautology Heuristic to every test as it is written
- Tests failing the heuristic must be rewritten before marking complete
- Apply Proof-of-Work Protocol to the test-run gate: if `work_count == 0` (no tests ran), gate FAILS
- Log heuristic violations and fixes in `.phase-10-output.json`

### Phase 9 & 11 (Code & Test Review, forge-review/SKILL.md)

In the **Execute Review** section:
- Before marking any finding CRITICAL or MAJOR:
  - If code-only finding: Apply Surface-Aware Finding Verification (require public surface reproduction)
  - If test-only finding: Classify as INTERNAL and downgrade to MINOR unless it indicates source code bug
- Cite reproduction evidence or downgrade in review artifact
- Apply Tautology Heuristic when reviewing test code (phase 11)

---

## Related Files & References

- `.forge/state.json` — Quality gate pass/fail status recorded in phases 8, 10, 9, 11
- `.forge/FORGE-CONFIG.md` — Quality gate command defined here
- Phase artifacts:
  - Phase 8: `.phase-8-output.json` (quality_gate section includes work_count evidence)
  - Phase 10: `.phase-10-output.json` (quality_gate section includes test count and tautology findings)
  - Phase 9: `CODE-REVIEW-N.md` (findings include surface classification and reproduction)
  - Phase 11: `TEST-REVIEW-N.md` (findings include heuristic check and surface classification)

---

## Summary: Three Protocols

| Protocol | Problem | Solution | Check Point |
|----------|---------|----------|------------|
| **Proof-of-Work** | Silent no-ops (exit 0, zero work done) | Capture tool version + work_count; fail if work_count==0 | Phase 8, 10 quality gates |
| **Tautology Heuristic** | Meaningless tests (pass but verify nothing) | Static heuristic: zero assertions, bare constants, mock testing, snapshot-only | Phase 10 (test writing), Phase 11 (test review) |
| **Surface-Aware Verification** | False-positive findings (internal API, not reproducible on public surface) | Classify code surface; reproduce on public API; downgrade if not reproducible | Phase 9, 11 (review findings) |

---

**Created:** 2026-06-16  
**Status:** Protocol Definition Complete  
**Scope:** Phases 8, 9, 10, 11 (code impl, code review, test impl, test review)
