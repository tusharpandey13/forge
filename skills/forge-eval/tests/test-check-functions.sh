#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

# TEST: B-CHECK-* (unit tests for each check function via engine rules)

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
ORIGINAL_PATH="$PATH"
trap 'export PATH="$ORIGINAL_PATH"; rm -rf $TMPDIR' EXIT

test_count=0
test_passed=0

run_check_test() {
  local test_name="$1"
  local fixture_tree="$2"
  local grader_file="$3"
  local assert_passed="$4"

  test_count=$((test_count+1))

  local output
  output=$("$SKILL_ROOT/bin/run-grader.sh" --grader "$grader_file" --fixture "$fixture_tree/fixture.json" 2>&1)

  local passed
  passed=$(echo "$output" | jq -r '.passed // false' 2>/dev/null || echo "false")

  if [[ "$passed" == "$assert_passed" ]]; then
    echo "  ✓ $test_name: passed=$passed"
    test_passed=$((test_passed+1))
  else
    echo "  ✗ $test_name: passed=$passed (expected $assert_passed)"
  fi
}

echo "=== B-CHECK-FILE-EXISTS ==="
# Test A: file exists
fixture_a="$TMPDIR/check-file-exists-a"
mkdir -p "$fixture_a"
cat > "$fixture_a/fixture.json" << 'EOF'
{"id":"test-file-exists-a","ref_outputs":{"phase_outputs":{"quality_gate":{"work_count":1,"exit_code":0}}}}
EOF
touch "$fixture_a/DESIGN.md"

cat > "$TMPDIR/grader-file-exists-a.yml" << 'EOF'
id: grader-check-file-exists-present
level: 1
rules:
  - id: file-check
    check: file_exists
    path: DESIGN.md
EOF

run_check_test "file_exists (present)" "$fixture_a" "$TMPDIR/grader-file-exists-a.yml" "true"

# Test B: file absent
fixture_b="$TMPDIR/check-file-exists-b"
mkdir -p "$fixture_b"
cat > "$fixture_b/fixture.json" << 'EOF'
{"id":"test-file-exists-b","ref_outputs":{"phase_outputs":{"quality_gate":{"work_count":1,"exit_code":0}}}}
EOF

cat > "$TMPDIR/grader-file-exists-b.yml" << 'EOF'
id: grader-check-file-exists-absent
level: 1
rules:
  - id: file-check
    check: file_exists
    path: NONEXISTENT.md
EOF

run_check_test "file_exists (absent)" "$fixture_b" "$TMPDIR/grader-file-exists-b.yml" "false"

echo "=== B-CHECK-SYMBOL-DEFINED ==="
# Test C: symbol present
fixture_c="$TMPDIR/check-symbol-present"
mkdir -p "$fixture_c"
cat > "$fixture_c/fixture.json" << 'EOF'
{"id":"test-symbol-c","ref_outputs":{"phase_outputs":{"quality_gate":{"work_count":1,"exit_code":0}}}}
EOF
cat > "$fixture_c/code.sh" << 'EOF'
function my_function() {
  echo "Hello"
}
EOF

cat > "$TMPDIR/grader-symbol-present.yml" << 'EOF'
id: grader-check-symbol-present
level: 2
rules:
  - id: symbol-check
    check: symbol_defined
    symbol: my_function
    source_file: code.sh
EOF

run_check_test "symbol_defined (present)" "$fixture_c" "$TMPDIR/grader-symbol-present.yml" "true"

# Test D: symbol absent
fixture_d="$TMPDIR/check-symbol-absent"
mkdir -p "$fixture_d"
cat > "$fixture_d/fixture.json" << 'EOF'
{"id":"test-symbol-d","ref_outputs":{"phase_outputs":{"quality_gate":{"work_count":1,"exit_code":0}}}}
EOF
cat > "$fixture_d/code.sh" << 'EOF'
function other_function() {
  echo "Hello"
}
EOF

cat > "$TMPDIR/grader-symbol-absent.yml" << 'EOF'
id: grader-check-symbol-absent
level: 2
rules:
  - id: symbol-check
    check: symbol_defined
    symbol: undefined_function
    source_file: code.sh
EOF

run_check_test "symbol_defined (absent)" "$fixture_d" "$TMPDIR/grader-symbol-absent.yml" "false"

echo "=== B-CHECK-NO-SECRETS-PATTERN ==="
# Test E: secret present (should FAIL)
fixture_e="$TMPDIR/check-secrets-present"
mkdir -p "$fixture_e"
cat > "$fixture_e/fixture.json" << 'EOF'
{"id":"test-secrets-e","ref_outputs":{"phase_outputs":{"quality_gate":{"work_count":1,"exit_code":0}}}}
EOF
cat > "$fixture_e/config.env" << 'EOF'
AWS_KEY=AKIA1234567890ABCDEF
DB_PASS=safe
EOF

cat > "$TMPDIR/grader-secrets-present.yml" << 'EOF'
id: grader-check-secrets-present
level: 3
rules:
  - id: secret-check
    check: no_secrets_pattern
    patterns: ["AKIA[0-9A-Z]{16}"]
EOF

run_check_test "no_secrets_pattern (secret)" "$fixture_e" "$TMPDIR/grader-secrets-present.yml" "false"

# Test F: clean
fixture_f="$TMPDIR/check-secrets-clean"
mkdir -p "$fixture_f"
cat > "$fixture_f/fixture.json" << 'EOF'
{"id":"test-secrets-f","ref_outputs":{"phase_outputs":{"quality_gate":{"work_count":1,"exit_code":0}}}}
EOF
cat > "$fixture_f/config.env" << 'EOF'
DATABASE_HOST=localhost
DB_PASS=safe123
EOF

cat > "$TMPDIR/grader-secrets-clean.yml" << 'EOF'
id: grader-check-secrets-clean
level: 3
rules:
  - id: secret-check
    check: no_secrets_pattern
    patterns: ["AKIA[0-9A-Z]{16}", "sk-[A-Za-z0-9]{20}"]
EOF

run_check_test "no_secrets_pattern (clean)" "$fixture_f" "$TMPDIR/grader-secrets-clean.yml" "true"

echo "=== B-CHECK-PROOF-OF-WORK ==="
# Test G: work_count > 0 + exit_code == 0
fixture_g="$TMPDIR/check-pow-pass"
mkdir -p "$fixture_g/phase"
cat > "$fixture_g/fixture.json" << 'EOF'
{"id":"test-pow-g","ref_outputs":{"phase_outputs":{"quality_gate":{"work_count":1,"exit_code":0}}}}
EOF
cat > "$fixture_g/phase/.phase-output.json" << 'EOF'
{"phase":10,"quality_gate":{"work_count":42,"exit_code":0}}
EOF

cat > "$TMPDIR/grader-pow-pass.yml" << 'EOF'
id: grader-check-pow-pass
level: 4
rules:
  - id: pow-check
    check: proof_of_work
    phase_output_path: phase/.phase-output.json
    min_work_count: 1
EOF

run_check_test "proof_of_work (valid)" "$fixture_g" "$TMPDIR/grader-pow-pass.yml" "true"

# Test H: work_count == 0
fixture_h="$TMPDIR/check-pow-fail"
mkdir -p "$fixture_h/phase"
cat > "$fixture_h/fixture.json" << 'EOF'
{"id":"test-pow-h","ref_outputs":{"phase_outputs":{"quality_gate":{"work_count":1,"exit_code":0}}}}
EOF
cat > "$fixture_h/phase/.phase-output.json" << 'EOF'
{"phase":10,"quality_gate":{"work_count":0,"exit_code":0}}
EOF

cat > "$TMPDIR/grader-pow-fail.yml" << 'EOF'
id: grader-check-pow-fail
level: 4
rules:
  - id: pow-check
    check: proof_of_work
    phase_output_path: phase/.phase-output.json
    min_work_count: 1
EOF

run_check_test "proof_of_work (zero)" "$fixture_h" "$TMPDIR/grader-pow-fail.yml" "false"

echo "=== B-CHECK-TAUTOLOGY-HEURISTIC ==="
# Test I: code-derived assertion
fixture_i="$TMPDIR/check-tautology-pass"
mkdir -p "$fixture_i/tests"
cat > "$fixture_i/fixture.json" << 'EOF'
{"id":"test-taut-i","ref_outputs":{"phase_outputs":{"quality_gate":{"work_count":1,"exit_code":0}}}}
EOF
cat > "$fixture_i/tests/app.test.ts" << 'EOF'
describe("app", () => {
  it("should parse", () => {
    const config = parseConfig();
    expect(config.host).toBe("localhost");
  });
});
EOF

cat > "$TMPDIR/grader-tautology-pass.yml" << 'EOF'
id: grader-check-tautology-pass
level: 5
rules:
  - id: taut-check
    check: tautology_heuristic
    test_file_glob: "*/tests/*.test.ts"
EOF

run_check_test "tautology_heuristic (code)" "$fixture_i" "$TMPDIR/grader-tautology-pass.yml" "true"

# Test J: bare literal
fixture_j="$TMPDIR/check-tautology-fail"
mkdir -p "$fixture_j/tests"
cat > "$fixture_j/fixture.json" << 'EOF'
{"id":"test-taut-j","ref_outputs":{"phase_outputs":{"quality_gate":{"work_count":1,"exit_code":0}}}}
EOF
cat > "$fixture_j/tests/app.test.ts" << 'EOF'
describe("app", () => {
  it("should pass", () => {
    expect(true).toBe(true);
  });
});
EOF

cat > "$TMPDIR/grader-tautology-fail.yml" << 'EOF'
id: grader-check-tautology-fail
level: 5
rules:
  - id: taut-check
    check: tautology_heuristic
    test_file_glob: "*/tests/*.test.ts"
EOF

run_check_test "tautology_heuristic (bare)" "$fixture_j" "$TMPDIR/grader-tautology-fail.yml" "false"

echo ""
echo "=== B-CHECK-FUNCTIONS Summary ==="
echo "Passed: $test_passed / $test_count"

if [[ $test_passed -eq $test_count ]]; then
  echo "PASS: B-CHECK-FUNCTIONS"
  exit 0
else
  echo "FAIL: B-CHECK-FUNCTIONS"
  exit 1
fi
