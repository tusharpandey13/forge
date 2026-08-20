# Maintenance Guide: Fixtures & Versioning

## Overview

This guide covers how to maintain the forge-eval fixture corpus, version fixtures across releases, and author anti-corpus entries (deliberately broken fixtures used in self-tests).

## Fixture Versioning & Release Process

### Corpus Locking

The golden fixture corpus is versioned per release via git tags. This ensures reproducibility: any user can check out a release tag and reproduce the exact grading behavior.

**Versioning scheme:**
- Corpus version: `forge-eval-v<major>.<minor>.<patch>`
- Example: `forge-eval-v1.0.0`, `forge-eval-v1.1.0`
- Tag the commit after corpus is finalized: `git tag forge-eval-v1.0.0`

**Workflow:**
1. Create/update fixtures in `fixtures/trees/`
2. Update manifests: `fixtures/forge-eval-fixtures.json` and `fixtures/forge-eval-known-wrong.json`
3. Run self-test: `bash tests/run-graders-selftest.sh` (must PASS)
4. Commit changes: `git commit -m "chore: finalize forge-eval fixtures for v1.0.0"`
5. Tag release: `git tag forge-eval-v1.0.0`
6. Push: `git push origin main && git push origin forge-eval-v1.0.0`

**Important:** Never mutate fixtures in-place after tagging. If a fixture has a bug, create a new fixture and bump the version.

### Manifest Fields

Both `forge-eval-fixtures.json` and `forge-eval-known-wrong.json` are JSON objects with a `fixtures` array. Each entry has:

```json
{
  "id": "fixture-kebab-case-id",
  "path": "trees/fixture-kebab-case-id/fixture.json",
  "level": 1,
  "grader": "grader-l1-file-exists",
  "tags": ["regression", "core"]
}
```

- `id`: unique, stable identifier (used in test output)
- `path`: relative path to fixture JSON (always under `trees/`)
- `level`: 1–5 (grader level this fixture tests)
- `grader`: grader YAML ID that should be run against this fixture
- `tags`: optional array for categorization (regression, edge-case, core, etc.)

## Creating & Testing Fixtures

### Golden Fixture (Should Pass)

A golden fixture represents a valid, correctly-executed phase output. When run against its grader, it should produce `passed: true` and `score: 100`.

**Steps to create:**

1. **Decide what scenario to capture:**
   - A core design phase (L1, L2, L3)
   - Implementation with proof-of-work (L4)
   - Tests with good patterns (L5)
   - An edge case or regression scenario

2. **Create the directory:**
   ```bash
   mkdir -p fixtures/trees/fixture-golden-my-scenario
   ```

3. **Populate files that graders expect:**
   ```
   fixture-golden-my-scenario/
   ├── fixture.json              (schema: id, version, inputs, ref_outputs, metadata)
   ├── design/DESIGN.md          (for L1 file-exists grader)
   ├── plan/IMPL-PLAN.md         (for L1 file-exists grader)
   ├── .phase-output.json        (for L4 proof-of-work grader)
   └── [other files per grader rules]
   ```

4. **Write fixture.json:**
   ```json
   {
     "id": "fixture-golden-my-scenario",
     "version": 1,
     "inputs": {
       "repo_snapshot": "git commit abc123def456 (2026-07-01)",
       "feature_request": "Implement XYZ feature with design, tests, proof-of-work."
     },
     "ref_outputs": {
       "phase_outputs": {
         "phase": 2,
         "status": "completed",
         "artifacts": [
           {"path": "design/DESIGN.md", "sha": "abc123", "size_bytes": 5000}
         ],
         "decisions": ["DD-1: Use bash for portability"],
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
       "notes": "Tests L1 file-presence checks across design phase."
     }
   }
   ```

5. **Register in manifest:**
   ```json
   {
     "id": "fixture-golden-my-scenario",
     "path": "trees/fixture-golden-my-scenario/fixture.json",
     "level": 2,
     "grader": "grader-l2-symbol-defined",
     "tags": ["regression", "core"]
   }
   ```

6. **Test it:**
   ```bash
   cd /Users/tushar.pandey/src/forge/skills/forge-eval
   bash bin/run-grader.sh \
     --grader references/graders/grader-l2-symbol-defined.yml \
     --fixture fixtures/trees/fixture-golden-my-scenario/fixture.json
   ```
   Expect: `"passed": true`, `"score": 100`, `"work_count": <N>`

7. **Add to self-test:**
   ```bash
   bash tests/run-graders-selftest.sh
   ```
   Expect: new fixture appears in "Running golden fixtures..." and passes.

### Anti-Corpus Fixture (Should Fail)

An anti-corpus fixture is deliberately broken to test that graders correctly reject bad inputs. When run against its grader, it should produce `passed: false` and score < 100.

**Key principle:** Each anti-corpus entry represents ONE genuine violation that a grader should catch. Don't pile multiple violations into one fixture (this makes debugging harder).

**Steps to create:**

1. **Choose a level and violation scenario:**
   - L1: missing required file (e.g., no design/DESIGN.md)
   - L2: undefined symbol (reference to non-existent function)
   - L3: leaked secret (AWS key pattern in artifact)
   - L4: zero work_count or non-zero exit_code
   - L5: bare-literal tautology (assertion on constant value)

2. **Create the directory:**
   ```bash
   mkdir -p fixtures/trees/fixture-wrong-l3-has-secret
   ```

3. **Populate with violation(s):**
   ```
   fixture-wrong-l3-has-secret/
   ├── fixture.json              (normal schema)
   ├── design/DESIGN.md          (clean, no secrets here)
   ├── artifacts/
   │   └── artifact-with-secret.md   (contains AWS secret pattern)
   └── .phase-output.json
   ```

4. **Write fixture.json with violation reference:**
   ```json
   {
     "id": "fixture-wrong-l3-has-secret",
     "version": 1,
     "inputs": { ... },
     "ref_outputs": {
       "phase_outputs": {
         "phase": 2,
         "status": "completed",
         "artifacts": [
           {"path": "artifacts/artifact-with-secret.md", ...}
         ],
         ...
       }
     },
     "metadata": {
       "tags": ["anti-corpus", "l3-violation"],
       "created_date": "2026-07-21T00:00:00Z",
       "human_reviewer": "Tushar Pandey",
       "checklist_status": "approved",
       "notes": "Contains AWS secret key pattern; should fail L3 no-secrets grader."
     }
   }
   ```

5. **Register in anti-corpus manifest:**
   ```json
   {
     "id": "fixture-wrong-l3-has-secret",
     "path": "trees/fixture-wrong-l3-has-secret/fixture.json",
     "level": 3,
     "grader": "grader-l3-no-secrets",
     "violation": "Artifact contains AWS secret key pattern",
     "tags": ["anti-corpus", "l3-violation"]
   }
   ```

6. **Test it:**
   ```bash
   bash bin/run-grader.sh \
     --grader references/graders/grader-l3-no-secrets.yml \
     --fixture fixtures/trees/fixture-wrong-l3-has-secret/fixture.json
   ```
   Expect: `"passed": false`, `"score": < 100`, evidence showing secret pattern found.

7. **Verify self-test catches it:**
   ```bash
   bash tests/run-graders-selftest.sh
   ```
   Expect: "Known-wrong fixture correctly rejected: fixture-wrong-l3-has-secret"

### Coverage Checklist

Ensure at least one anti-corpus entry exists per level:

- [ ] L1: Missing file (e.g., no DESIGN.md)
- [ ] L2: Undefined symbol (reference to non-existent function/class)
- [ ] L3: Leaked secret (AWS key, API token, etc.)
- [ ] L4: Zero work_count or non-zero exit_code
- [ ] L5: Bare-literal assertion or review citing internal symbols

Current status (as of 2026-07-21):
- L1: fixture-wrong-l1-missing-design ✓
- L2: fixture-wrong-l2-no-symbol ✓
- L3: fixture-wrong-l3-has-secret ✓
- L4: fixture-wrong-l4-zero-work ✓
- L5: fixture-wrong-l5-tautology ✓

## Regenerating / Refreshing Fixtures

If phase-output formats change or graders are updated, you may need to refresh fixture JSON without losing the fixture tree files.

**Process:**

1. Update the `ref_outputs.phase_outputs` JSON in `fixture.json` to match new schema
2. Verify all grader YAML files still reference correct fields
3. Run self-test:
   ```bash
   bash tests/run-graders-selftest.sh
   ```
4. If any golden fixtures now fail, investigate grader changes or fixture schema mismatches
5. Commit changes and tag new release version

## Grader Updates & Backward Compatibility

When a grader rule changes (e.g., new secret pattern in L3), consider:

1. **Non-breaking change** (e.g., add more secure checks, stricter rules):
   - Bump patch version: `v1.0.0` → `v1.0.1`
   - Existing golden fixtures may now fail (intentional—stricter is better)
   - Add new anti-corpus entry for the new violation
   - Re-run self-test and update known counts if needed

2. **Breaking change** (e.g., change rule schema):
   - Bump minor version: `v1.0.0` → `v1.1.0`
   - Update all affected fixture manifests
   - Create migration guide for users

3. **Never:**
   - Remove checks without deprecation period
   - Silently weaken graders (e.g., allow new secret pattern to pass)
   - Change rule IDs without re-testing

## Self-Test Validation

Before releasing, always run both test layers:

```bash
bash tests/run-graders-selftest.sh
# Expect: 8 golden PASS, 5 known-wrong REJECT, work_count=27

bash tests/run-all-layer-b.sh
# Expect: 12 tests PASS
```

Both must exit code 0. If either fails, investigate and fix before tagging a release.

## Troubleshooting

### Fixture passes but should fail (false negative in anti-corpus)

**Symptom:** Anti-corpus fixture runs against grader, `passed: true`, but should fail.

**Cause:** Grader rule not strict enough to catch the violation.

**Fix:**
1. Review grader rule thresholds and patterns
2. Update grader YAML to be more strict, OR
3. Rewrite anti-corpus fixture to have a more obvious violation
4. Re-run self-test

### Fixture fails but should pass (false positive in golden)

**Symptom:** Golden fixture runs against grader, `passed: false`, but should pass.

**Cause:** Grader became stricter or fixture is incomplete.

**Fix:**
1. Check grader YAML recent changes
2. Verify fixture tree has all required files (check grader rules)
3. Update fixture.json ref_outputs if schema changed
4. Re-run self-test

### New grader added, no fixtures test it yet

**Symptom:** New `grader-l2-custom.yml` created, but no fixture in manifest.

**Fix:**
1. Create at least one golden fixture for the new grader
2. Create at least one anti-corpus fixture for the new grader
3. Add both to their respective manifests
4. Run self-test to validate

## References

- SKILL.md: User-facing documentation for forge-eval
- REQUIREMENTS.md: Feature specification (FR-1 golden corpus, FR-5 versioning)
- DESIGN.md: Architecture & fixture schema (DD-3)
- TEST-PLAN.md: Test strategy (Layer A: self-test, Layer B: engine robustness)
