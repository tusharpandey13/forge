---
name: forge-eval
description: Offline regression-fixture evaluation engine. Deterministic graders (L1–L5) measure process-compliance proxies for forge phase outputs. Scores are NOT quality truth.
license: Proprietary
metadata:
  author: Tushar Pandey <tushar@auth0.com>
  version: 1.0.0
---

# Forge-Eval: Process-Compliance Regression Fixture Engine

Offline deterministic evaluation engine for forge workflow outputs. Loads YAML graders + JSON fixtures; executes L1–L5 checks; emits composite scores explicitly labeled as process-compliance proxies, not quality truth. No network, no LLM, no randomness—purely file I/O and text processing.

## What This Is

An offline grading system for the forge development workflow. It validates that phase outputs conform to forge process checks (file presence, no hallucinated symbols, no secrets, proof-of-work, code patterns). Scores measure *process compliance*, not output quality or correctness. Perfect for regression testing or continuous validation gates.

**Key phrase emitted on every score:** "Scores are process-compliance proxies, not quality truth."

## Dependencies & Installation (HARD REQUIREMENTS)

This tool requires exactly two external dependencies, both must be installed and will fail loudly if absent.

### jq (JSON Query) — REQUIRED

**Purpose:** Parse and transform JSON (fixture manifests, engine output, phase-output fields).

**Minimum version:** 1.6+

**Install:**
- **macOS:** `brew install jq`
- **Linux (Debian/Ubuntu):** `apt-get install jq`
- **Verify:** `jq --version` should show jq-1.6 or later

**Failure behavior:** If jq is missing, the engine exits immediately with:
```
ERROR: jq is a required dependency for forge-eval.
Install: brew install jq (macOS) / apt-get install jq (Linux)
```

### yq (YAML to JSON Converter, Go-based mikefarah/yq) — REQUIRED

**Purpose:** Convert grader YAML files to JSON for rule extraction.

**Minimum version:** 4.0+ (Go implementation only, not the Python version)

**Install:**
- **macOS:** `brew install yq`
- **Linux:** Download from https://github.com/mikefarah/yq/releases
- **Verify:** `yq --version` should show v4.x.x

**Important:** The older Python-based yq (installed via `pip install yq`) is incompatible. Uninstall it if present and use the Go binary instead.

**Failure behavior:** If yq is missing, the engine exits immediately with:
```
ERROR: yq is a required dependency for forge-eval (YAML parser, mikefarah/yq v4+).
Install: brew install yq (macOS) / see https://github.com/mikefarah/yq (Linux)
```

## Environment Assumptions

- **OS:** macOS or Linux (tested on both)
- **Shell:** bash 5.x (bash 5.0+; POSIX sh compatibility not guaranteed)
- **Locale:** Set `LC_ALL=C` for deterministic regex behavior (recommended for reproducibility across machines)
- **Standard utilities:** grep, awk (POSIX versions; BSD and GNU both work)
- **No package-manager calls at runtime:** Dependencies installed once; engine never calls brew, apt, npm, or pip
- **Working directory:** Engine runs relative to its invocation directory (not necessarily the skill root)

## Quick Start

### 1. Run a Single Grader Against a Fixture

```bash
cd /Users/tushar.pandey/src/forge/skills/forge-eval
bash bin/run-grader.sh \
  --grader references/graders/grader-l1-file-exists.yml \
  --fixture fixtures/trees/fixture-golden-l1-basic/fixture.json
```

Expected output (JSON to stdout, exit code 0 if passed):
```json
{
  "grader_id": "grader-l1-file-exists",
  "fixture_id": "fixture-golden-l1-basic",
  "level": 1,
  "score": 100,
  "passed": true,
  "work_count": 3,
  "rule_results": [
    {
      "rule_id": "rule-design-exists",
      "check": "file_exists",
      "passed": true,
      "evidence": "file found at design/DESIGN.md",
      "proxy_label": "Scores are process-compliance proxies, not quality truth."
    }
  ],
  "proxy_label": "Scores are process-compliance proxies, not quality truth.",
  "executed_at": "2026-07-22T09:37:04Z"
}
```

Exit code: 0 (passed), 1 (failed or work_count == 0)

### 2. Run Self-Test Harness (Quality Gate)

```bash
bash tests/run-graders-selftest.sh
```

This validates graders before releasing. It runs 8 golden fixtures (all should PASS) and 5 known-wrong fixtures (all should REJECT).

Expected output (last few lines):
```
Golden fixtures passed: 8
Golden fixtures failed: 0
Known-wrong fixtures correctly rejected: 5
Known-wrong fixtures incorrectly passed: 0
Total work_count: 27
Total rules executed: 27

Scores are process-compliance proxies, not quality truth.

SUCCESS: All golden fixtures passed, all known-wrong fixtures rejected
```

Exit code: 0 (all pass), 1 (any failure)

### 3. Run Layer-B Engine Tests

```bash
bash tests/run-all-layer-b.sh
```

Validates engine robustness: malformed YAML, missing dependencies, missing fields, determinism.

Expected output (last few lines):
```
Running test-check-functions.sh ... PASS
Running test-determinism.sh ... PASS
Running test-duplicate-rules.sh ... PASS
Running test-empty-fixture.sh ... PASS
Running test-field-absent.sh ... PASS
Running test-jq-missing.sh ... PASS
Running test-meta-lenient.sh ... PASS
Running test-portability.sh ... PASS
Running test-proxy-label.sh ... PASS
Running test-ref-outputs-missing.sh ... PASS
Running test-yaml-malformed.sh ... PASS
Running test-yq-missing.sh ... PASS

Passed: 12
Failed: 0
SUCCESS: All Layer-B tests passed
```

Exit code: 0 (all pass), 1 (any failure)

### 4. Verbose Output (Detailed Logging)

```bash
bash bin/run-grader.sh --grader <yaml> --fixture <json> --verbose
```

Logs each rule execution to stderr; JSON still output to stdout.

### 5. Dry-Run (Parse Only, No Execution)

```bash
bash bin/run-grader.sh --grader <yaml> --fixture <json> --dry-run
```

Parses YAML and JSON; validates syntax; does not execute rule checks.

## Proxy-Label: Process-Compliance Proxies, NOT Quality Truth

**CRITICAL DISCLAIMER:**

Scores emitted by forge-eval measure *process-compliance conformance* only. This score validates the *forge development process*, not the *quality or correctness of the output itself*.

**What scores measure:**
- Artifact presence (L1: files exist)
- Hallucination absence (L2: no undefined symbols)
- Security hygiene (L3: no leaked secrets/tokens)
- Proof-of-Work + structural consistency (L4: work_count > 0, exit_code == 0, plan/impl/tests aligned)
- Correctness patterns (L5: tests avoid bare-literal assertions, review findings cite public APIs)

**What scores do NOT measure:**
- Functional correctness
- Output quality
- Technical soundness
- User satisfaction
- Actual problem-solving ability

A high score (90–100) means the output conforms to forge process checks. It is **NOT** a guarantee of excellence or correctness.

**Emitted on every score output** as JSON field `"proxy_label"` and in harness logs.

## Data Model

### Individual Fixture JSON Schema

Each fixture lives in `fixtures/trees/<fixture-id>/fixture.json` and contains:

```json
{
  "id": "fixture-golden-l1-basic",
  "version": 1,
  "inputs": {
    "repo_snapshot": "captured tree (synthetic or git SHA reference)",
    "feature_request": "text description of the feature request"
  },
  "ref_outputs": {
    "phase_outputs": {
      "phase": 2,
      "status": "completed",
      "artifacts": [
        {"path": "design/DESIGN.md", "sha": "abc123", "size_bytes": 5000}
      ],
      "decisions": ["DD-1: decision one", "DD-2: decision two"],
      "quality_gate": {
        "work_count": 42,
        "exit_code": 0,
        "tool_version": "claude-sonnet"
      }
    }
  },
  "metadata": {
    "tags": ["regression", "core"],
    "created_date": "2026-07-21T00:00:00Z",
    "human_reviewer": "Tushar Pandey",
    "checklist_status": "approved",
    "notes": "Validates L1 file-presence checks."
  }
}
```

**The Fixture Tree Contract:** When a grader runs against a fixture, file paths in rules are resolved relative to `dirname(fixture.json)`. For example, if fixture is at `fixtures/trees/fixture-golden-l1-basic/fixture.json`, and a rule checks for `design/DESIGN.md`, the engine looks for `fixtures/trees/fixture-golden-l1-basic/design/DESIGN.md`. This is critical: each fixture is a self-contained directory tree.

### Fixture Manifest (forge-eval-fixtures.json)

Lists all golden fixtures and their associated graders:

```json
{
  "corpus_type": "golden",
  "description": "Golden regression-fixture corpus for forge-eval MVP",
  "fixtures": [
    {
      "id": "fixture-golden-l1-basic",
      "path": "trees/fixture-golden-l1-basic/fixture.json",
      "level": 1,
      "grader": "grader-l1-file-exists"
    },
    {
      "id": "fixture-golden-l2-symbols",
      "path": "trees/fixture-golden-l2-symbols/fixture.json",
      "level": 2,
      "grader": "grader-l2-symbol-defined"
    }
  ]
}
```

### Anti-Corpus Manifest (forge-eval-known-wrong.json)

Lists deliberately broken fixtures (used in self-test to validate graders reject bad inputs):

```json
{
  "corpus_type": "known-wrong",
  "description": "Anti-corpus: fixtures with deliberate violations",
  "fixtures": [
    {
      "id": "fixture-wrong-l1-missing-design",
      "path": "trees/fixture-wrong-l1-missing-design/fixture.json",
      "level": 1,
      "grader": "grader-l1-file-exists",
      "violation": "Missing design/DESIGN.md"
    }
  ]
}
```

### Grader YAML Schema

Each grader defines a set of rules to check:

```yaml
id: grader-l1-file-exists
level: 1
description: Verify required artifact files exist on disk (positive presence)
rules:
  - id: rule-design-exists
    check: file_exists
    path: design/DESIGN.md
    threshold: 1.0
  - id: rule-phase-output-exists
    check: file_exists
    path: .phase-output.json
    threshold: 1.0
```

**Fields:**
- `id`: unique grader identifier (kebab-case)
- `level`: 1–5, indicating severity/depth (L1=basic, L5=advanced patterns)
- `description`: human-readable purpose
- `rules`: array of rule objects, each with:
  - `id`: unique rule identifier
  - `check`: the type of check (file_exists, symbol_defined, no_secrets_pattern, proof_of_work, plan_impl_tests_consistency, tautology_heuristic, surface_aware)
  - `path` (check-specific): path to file (for file_exists, symbol_defined, etc.)
  - `threshold`: typically 1.0 (all rules must pass to contribute to score)

### Engine Output JSON

The engine emits one JSON object per grader+fixture run:

```json
{
  "grader_id": "grader-l1-file-exists",
  "fixture_id": "fixture-golden-l1-basic",
  "level": 1,
  "score": 100,
  "passed": true,
  "work_count": 3,
  "rule_results": [
    {
      "rule_id": "rule-design-exists",
      "check": "file_exists",
      "passed": true,
      "evidence": "file found at design/DESIGN.md",
      "proxy_label": "Scores are process-compliance proxies, not quality truth."
    },
    {
      "rule_id": "rule-phase-output-exists",
      "check": "file_exists",
      "passed": true,
      "evidence": "file found at .phase-output.json",
      "proxy_label": "Scores are process-compliance proxies, not quality truth."
    },
    {
      "rule_id": "rule-impl-plan-exists",
      "check": "file_exists",
      "passed": true,
      "evidence": "file found at plan/IMPL-PLAN.md",
      "proxy_label": "Scores are process-compliance proxies, not quality truth."
    }
  ],
  "proxy_label": "Scores are process-compliance proxies, not quality truth.",
  "executed_at": "2026-07-22T09:37:04Z"
}
```

**Fields:**
- `grader_id`, `fixture_id`: identifiers for traceability
- `level`: the grader's level (1–5)
- `score`: 0–100 (percent of rules passed)
- `passed`: true iff score >= threshold AND work_count > 0
- `work_count`: total number of rules executed (must be > 0 for gate pass)
- `rule_results`: array of per-rule outcomes, each with:
  - `rule_id`, `check`, `passed`: core result
  - `evidence`: human-readable finding (e.g., "file found at..." or "symbol 'foo' not defined in...")
  - `proxy_label`: always present, on every rule result
- `proxy_label`: top-level label (also on every rule result)
- `executed_at`: ISO 8601 timestamp when the engine ran

## Grader Levels L1–L5

The grading ladder progresses from simple structural checks (L1) to sophisticated pattern analysis (L5). All are deterministic; no LLM involved.

### Level 1: Positive Presence (file-existence)

**What it checks:** Required artifacts exist on disk and are readable.

**Grader:** `grader-l1-file-exists.yml`

**Check type:** `file_exists`

**Example rules:**
- Verify `design/DESIGN.md` exists
- Verify `.phase-output.json` exists
- Verify `plan/IMPL-PLAN.md` exists

**When it fails:** If any required file is missing, score < 100, passed=false.

---

### Level 2: Hallucination Absence (symbol-defined)

**What it checks:** Code/design references are not invented; symbols actually defined in source files.

**Grader:** `grader-l2-symbol-defined.yml`

**Check type:** `symbol_defined`

**Example rules:**
- Verify function `run_grader` is defined in `bin/run-grader.sh`
- Verify class `GraderEngine` exists in implementation

**When it fails:** If referenced symbols are undefined or files don't exist, score < 100, passed=false.

---

### Level 3: Security (no-secrets-pattern)

**What it checks:** No leaked credentials, API keys, or private keys in artifacts.

**Grader:** `grader-l3-no-secrets.yml`

**Check type:** `no_secrets_pattern`

**Patterns scanned:**
- AWS secret access keys (AKIA... + secret pattern)
- API keys and tokens (api_key=, authorization:, bearer)
- Private key headers (-----BEGIN PRIVATE KEY-----)
- Passwords in cleartext

**When it fails:** If any pattern matches, score < 100, passed=false.

---

### Level 4a: Structural—Proof-of-Work

**What it checks:** Evidence that real work was done: `work_count > 0` and `exit_code == 0` in the phase output.

**Grader:** `grader-l4-proof-of-work.yml`

**Check type:** `proof_of_work`

**Validates:**
- `quality_gate.work_count >= 1` (at least one unit of work)
- `quality_gate.exit_code == 0` (exit success)

**When it fails:** If work_count is 0 or exit_code is non-zero, score < 100, passed=false.

---

### Level 4b: Structural—Consistency

**What it checks:** Plan, implementation, and test artifacts are aligned (if plan exists, implementations match; if implementations exist, tests present).

**Grader:** `grader-l4-consistency.yml`

**Check type:** `plan_impl_tests_consistency`

**Validates:**
- If `plan/IMPL-PLAN.md` lists N units, implementation files count matches
- If implementation files exist, test file count > 0

**When it fails:** If counts don't align or tests missing when code present, score < 100, passed=false.

---

### Level 5a: Correctness Patterns—Tautology Heuristic

**What it checks:** Test files don't contain bare-literal assertions (tautologies like `expect(true).toBe(true)`). Instead, assertions should reference code-derived values.

**Grader:** `grader-l5-tautology-heuristic.yml`

**Check type:** `tautology_heuristic`

**How it works:**
- Regex + heuristic AST scan of test files
- Detects bare-literal patterns: `true`, `false`, `1`, `0`, quoted strings
- Checks if assertion references a code-derived symbol instead
- False-negative rate ~5% (some real tautologies missed), false-positive rate ~2% (some valid patterns flagged)

**When it fails:** If tests are mostly bare-literal assertions, score < 100, passed=false.

---

### Level 5b: Correctness Patterns—Surface-Aware

**What it checks:** Review findings reference public surface (exported APIs, public symbols), not internals.

**Grader:** `grader-l5-surface-aware.yml`

**Check type:** `surface_aware`

**Validates:**
- Review file (e.g., `plan/CODE-REVIEW.md`) exists
- Symbols mentioned in review appear in public API list

**When it fails:** If review references internal symbols not in public list, score < 100, passed=false.

## How to Add a New Grader

New graders are added without modifying the engine code. Simply:

1. **Create a YAML file** in `references/graders/` with a kebab-case name, e.g., `grader-l4-custom-check.yml`:
   ```yaml
   id: grader-l4-custom-check
   level: 4
   description: Custom structural check for my use case
   rules:
     - id: rule-1
       check: file_exists
       path: my/artifact/file.txt
       threshold: 1.0
   ```

2. **Update the manifest** in `fixtures/forge-eval-fixtures.json` or `fixtures/forge-eval-known-wrong.json` to add a test fixture that should pass/reject this grader.

3. **Run the self-test:**
   ```bash
   bash tests/run-graders-selftest.sh
   ```

The engine automatically discovers and runs all graders in `references/graders/`.

**Supported check types:**
- `file_exists`: path must exist and be readable
- `symbol_defined`: symbol must be defined in source_file
- `no_secrets_pattern`: patterns list must NOT match any rule file
- `proof_of_work`: quality_gate.work_count >= min_threshold, exit_code == 0
- `plan_impl_tests_consistency`: plan/impl/test counts must align
- `tautology_heuristic`: test assertions must reference code symbols
- `surface_aware`: review symbols must be in public API list

---

## How to Add a New Fixture

1. **Create a fixture directory:**
   ```bash
   mkdir -p fixtures/trees/fixture-my-test-case
   ```

2. **Create the fixture JSON** at `fixtures/trees/fixture-my-test-case/fixture.json`:
   ```json
   {
     "id": "fixture-my-test-case",
     "version": 1,
     "inputs": { "repo_snapshot": "...", "feature_request": "..." },
     "ref_outputs": { "phase_outputs": { ... } },
     "metadata": { "tags": ["..."], "created_date": "...", ... }
   }
   ```

3. **Populate the fixture tree** with the files the graders expect (e.g., `design/DESIGN.md`, `plan/IMPL-PLAN.md`).

4. **Register in the manifest** (`fixtures/forge-eval-fixtures.json` for golden, or `fixtures/forge-eval-known-wrong.json` for anti-corpus):
   ```json
   {
     "id": "fixture-my-test-case",
     "path": "trees/fixture-my-test-case/fixture.json",
     "level": 2,
     "grader": "grader-l2-symbol-defined"
   }
   ```

5. **Run self-test** to validate:
   ```bash
   bash tests/run-graders-selftest.sh
   ```

---

## Testing

The tool includes two layers of testing:

### Layer A: Self-Test Harness (Grader Validation)

**What it does:** Validates graders before release. Runs against golden fixtures (should PASS) and anti-corpus (should REJECT).

**Command:**
```bash
bash tests/run-graders-selftest.sh
```

**Exit code:** 0 if all 8 golden PASS, all 5 known-wrong REJECT, and total work_count > 0; else 1.

**Purpose:** Gate to prevent releasing broken graders.

### Layer B: Engine Robustness Tests (12 tests)

**What it does:** Tests engine infrastructure: missing dependencies, malformed input, determinism, portability.

**Command:**
```bash
bash tests/run-all-layer-b.sh
```

**Exit code:** 0 if all 12 tests pass; else 1.

**Tests included:**
- `test-jq-missing.sh`: Engine fails if jq not installed
- `test-yq-missing.sh`: Engine fails if yq not installed
- `test-yaml-malformed.sh`: Engine rejects corrupt YAML
- `test-empty-fixture.sh`: Engine rejects empty fixture
- `test-ref-outputs-missing.sh`: Engine rejects fixture without ref_outputs
- `test-field-absent.sh`: Engine rejects when phase-output field missing
- `test-check-functions.sh`: Individual rule checkers work correctly
- `test-determinism.sh`: Same input produces identical output
- `test-portability.sh`: Engine works with only bash + jq
- `test-proxy-label.sh`: Proxy label appears on every output
- `test-duplicate-rules.sh`: Two graders run independently
- `test-meta-lenient.sh`: Anti-corpus catches weak graders

---

## Known Limitations

### L5 Tautology Heuristic: Regex + Pattern Matching, Not AST

The tautology check uses regex and pattern heuristics to detect bare-literal assertions, not a full abstract syntax tree (AST) parser. This means:
- **False-negative rate (~5%):** Some real tautologies (bare assertions) might slip through
- **False-positive rate (~2%):** Some valid patterns might be incorrectly flagged

For critical testing workflows, combine this with your own linter or test framework checks.

### L4 Surface-Aware & L4 Consistency: Layer-A Validation Only

These graders are validated at Layer-A (self-test harness) only. They do not have separate Layer-B unit tests with synthetic edge cases. This is a known scope limitation.

### Process-Compliance Proxy, Not Quality

Scores measure conformance to process checks. A high score (90–100) does NOT mean:
- The output is correct
- The code is well-written
- The design is sound
- The test coverage is sufficient

It means the output follows forge process conventions.

---

## Out of Scope

The following are explicitly NOT supported:

- **LLM-based grading:** No integration with language models; deterministic rules only
- **Trace/command grading (Leg2):** No analysis of executed commands; static artifact analysis only
- **Multi-run evaluation:** No repeated runs with different model configs; single-pass only
- **Online/continuous eval:** No live monitoring; offline fixture-based only
- **Human annotation queue:** No workflow for human reviewers; graders are automated
- **Flywheel/active learning:** No feedback loop to generate new fixtures
- **Model-tiering experiments:** No A/B testing; graders are model-agnostic
- **Drift detection:** No monitoring for fixture/ground-truth drift over time

---

## File Structure

```
forge-eval/
├── SKILL.md                                      (this file)
├── bin/
│   └── run-grader.sh                             (grader engine: ~450 lines)
├── references/
│   ├── graders/
│   │   ├── grader-l1-file-exists.yml
│   │   ├── grader-l2-symbol-defined.yml
│   │   ├── grader-l3-no-secrets.yml
│   │   ├── grader-l4-proof-of-work.yml
│   │   ├── grader-l4-consistency.yml
│   │   ├── grader-l5-tautology-heuristic.yml
│   │   └── grader-l5-surface-aware.yml
│   └── MAINTENANCE.md                            (fixture versioning, anti-corpus strategy)
├── fixtures/
│   ├── forge-eval-fixtures.json                  (golden corpus manifest: 8 fixtures)
│   ├── forge-eval-known-wrong.json               (anti-corpus manifest: 5 fixtures)
│   └── trees/
│       ├── fixture-golden-l1-basic/
│       ├── fixture-golden-l2-symbols/
│       ├── fixture-golden-l3-clean/
│       ├── fixture-golden-l4-proof/
│       ├── fixture-golden-l4-consistency/
│       ├── fixture-golden-l5-tautology/
│       ├── fixture-golden-l5-surface/
│       ├── fixture-golden-l1-complete/
│       ├── fixture-wrong-l1-missing-design/
│       ├── fixture-wrong-l2-no-symbol/
│       ├── fixture-wrong-l3-has-secret/
│       ├── fixture-wrong-l4-zero-work/
│       └── fixture-wrong-l5-tautology/
└── tests/
    ├── run-graders-selftest.sh                   (Layer-A: golden PASS / known-wrong REJECT)
    ├── run-all-layer-b.sh                        (Layer-B: runner for 12 unit tests)
    ├── test-check-functions.sh
    ├── test-determinism.sh
    ├── test-duplicate-rules.sh
    ├── test-empty-fixture.sh
    ├── test-field-absent.sh
    ├── test-jq-missing.sh
    ├── test-meta-lenient.sh
    ├── test-portability.sh
    ├── test-proxy-label.sh
    ├── test-ref-outputs-missing.sh
    ├── test-yaml-malformed.sh
    └── test-yq-missing.sh
```

---

## References & Further Reading

- **Design & Architecture:** `/Users/tushar.pandey/.forge/features/forge-eval-mvp/design/DESIGN.md`
- **Requirements & Acceptance Criteria:** `/Users/tushar.pandey/.forge/features/forge-eval-mvp/requirement/REQUIREMENTS.md`
- **Implementation Plan:** `/Users/tushar.pandey/.forge/features/forge-eval-mvp/plan/IMPL-PLAN.md`
- **Test Plan:** `/Users/tushar.pandey/.forge/features/forge-eval-mvp/plan/TEST-PLAN.md`
- **Code Review Findings:** `/Users/tushar.pandey/.forge/features/forge-eval-mvp/plan/CODE-REVIEW-1.md`
- **Test Review Findings:** `/Users/tushar.pandey/.forge/features/forge-eval-mvp/plan/TEST-REVIEW-1.md`
- **Maintenance Guide:** `references/MAINTENANCE.md` (this directory)
