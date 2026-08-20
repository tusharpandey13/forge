#!/usr/bin/env bash
set -euo pipefail

# ===== forge-eval Self-Test Harness =====
# Validates golden fixtures PASS and known-wrong fixtures REJECT
# Exit 0 iff: all golden pass, all known-wrong reject, work_count > 0, every rule executed

# ========== PREAMBLE: JQ & YQ HARD REQUIREMENTS ==========
command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is a required dependency for forge-eval selftest."
  echo "Install: brew install jq (macOS) / apt-get install jq (Linux)"
  exit 1
}

command -v yq >/dev/null 2>&1 || {
  echo "ERROR: yq is a required dependency for forge-eval selftest (YAML parser, mikefarah/yq v4+)."
  echo "Install: brew install yq (macOS) / see https://github.com/mikefarah/yq (Linux)"
  exit 1
}

# ========== SETUP & PATHS ==========
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENGINE="$PROJECT_ROOT/bin/run-grader.sh"
GRADERS_DIR="$PROJECT_ROOT/references/graders"
FIXTURES_DIR="$PROJECT_ROOT/fixtures"
GOLDEN_MANIFEST="$FIXTURES_DIR/forge-eval-fixtures.json"
KNOWN_WRONG_MANIFEST="$FIXTURES_DIR/forge-eval-known-wrong.json"

# Check engine exists
[[ -f "$ENGINE" ]] || {
  echo "ERROR: Engine not found at $ENGINE"
  exit 1
}
chmod +x "$ENGINE"

[[ -f "$GOLDEN_MANIFEST" ]] || {
  echo "ERROR: Golden manifest not found at $GOLDEN_MANIFEST"
  exit 1
}

[[ -f "$KNOWN_WRONG_MANIFEST" ]] || {
  echo "ERROR: Known-wrong manifest not found at $KNOWN_WRONG_MANIFEST"
  exit 1
}

# ========== TEST COUNTERS ==========
golden_passed=0
golden_failed=0
known_wrong_passed=0
known_wrong_failed=0
total_work_count=0
rules_executed=0

# ========== FUNCTIONS ==========

# Run the engine for one fixture. Echoes engine stdout on fd1.
# Sets globals: RGT_OUTPUT (engine output), RGT_EXIT (engine exit code).
# Returns 1 only on harness-level setup errors (missing grader/fixture file).
run_grader_test() {
  local grader_name="$1"
  local fixture_path="$2"

  local grader_yaml="$GRADERS_DIR/$grader_name.yml"
  local full_fixture_path="$FIXTURES_DIR/$fixture_path"

  if [[ ! -f "$grader_yaml" ]]; then
    RGT_OUTPUT="ERROR: Grader YAML not found: $grader_yaml"
    RGT_EXIT=2
    return 1
  fi
  if [[ ! -f "$full_fixture_path" ]]; then
    RGT_OUTPUT="ERROR: Fixture JSON not found: $full_fixture_path"
    RGT_EXIT=2
    return 1
  fi

  RGT_EXIT=0
  RGT_OUTPUT=$("$ENGINE" --grader "$grader_yaml" --fixture "$full_fixture_path" 2>&1) || RGT_EXIT=$?
  return 0
}

validate_golden() {
  local fixture_id="$1"
  local fixture_path="$2"
  local grader_name="$3"

  echo "  Testing golden fixture: $fixture_id (grader: $grader_name)"

  if ! run_grader_test "$grader_name" "$fixture_path"; then
    echo "    FAILED: $RGT_OUTPUT"
    golden_failed=$((golden_failed+1))
    return 1
  fi

  # Golden must be accepted: engine exit 0 AND passed==true AND work_count>0.
  local passed work_count rule_count
  passed=$(echo "$RGT_OUTPUT" | jq -r '.passed // false' 2>/dev/null || echo "false")
  work_count=$(echo "$RGT_OUTPUT" | jq -r '.work_count // 0' 2>/dev/null || echo "0")
  rule_count=$(echo "$RGT_OUTPUT" | jq '.rule_results | length' 2>/dev/null || echo "0")

  if [[ $RGT_EXIT -ne 0 ]]; then
    echo "    FAILED: engine exit=$RGT_EXIT (expected 0)"
    echo "      output: $RGT_OUTPUT"
    golden_failed=$((golden_failed+1))
    return 1
  fi
  if [[ "$passed" != "true" ]]; then
    echo "    FAILED: passed=$passed (expected true)"
    golden_failed=$((golden_failed+1))
    return 1
  fi
  if [[ "$work_count" -eq 0 ]]; then
    echo "    FAILED: work_count=0 (must be > 0)"
    golden_failed=$((golden_failed+1))
    return 1
  fi

  total_work_count=$((total_work_count+work_count))
  rules_executed=$((rules_executed+rule_count))
  golden_passed=$((golden_passed+1))
  echo "    PASSED (work_count=$work_count, rules=$rule_count)"
  return 0
}

validate_known_wrong() {
  local fixture_id="$1"
  local fixture_path="$2"
  local grader_name="$3"

  echo "  Testing known-wrong fixture: $fixture_id (grader: $grader_name)"

  if ! run_grader_test "$grader_name" "$fixture_path"; then
    echo "    FAILED: $RGT_OUTPUT"
    known_wrong_failed=$((known_wrong_failed+1))
    return 1
  fi

  # Known-wrong must be REJECTED: engine exit != 0 AND passed != true.
  local passed work_count rule_count
  passed=$(echo "$RGT_OUTPUT" | jq -r '.passed // false' 2>/dev/null || echo "false")
  work_count=$(echo "$RGT_OUTPUT" | jq -r '.work_count // 0' 2>/dev/null || echo "0")
  rule_count=$(echo "$RGT_OUTPUT" | jq '.rule_results | length' 2>/dev/null || echo "0")

  if [[ $RGT_EXIT -eq 0 || "$passed" == "true" ]]; then
    echo "    FAILED: engine accepted the fixture (exit=$RGT_EXIT, passed=$passed) — expected rejection"
    known_wrong_failed=$((known_wrong_failed+1))
    return 1
  fi

  # work_count>0 still required: the grader must have actually executed rules to reject.
  if [[ "$work_count" -eq 0 ]]; then
    echo "    FAILED: work_count=0 — grader ran no rules (silent non-execution, not a real rejection)"
    known_wrong_failed=$((known_wrong_failed+1))
    return 1
  fi

  total_work_count=$((total_work_count+work_count))
  rules_executed=$((rules_executed+rule_count))
  known_wrong_passed=$((known_wrong_passed+1))
  echo "    PASSED (engine correctly rejected; work_count=$work_count, rules=$rule_count)"
  return 0
}

# ========== MAIN TEST LOOP ==========
echo "=== forge-eval Self-Test Harness ==="
echo

echo "Running golden fixtures..."
while IFS= read -r line; do
  fixture_id=$(echo "$line" | jq -r '.id' 2>/dev/null) || continue
  fixture_path=$(echo "$line" | jq -r '.path' 2>/dev/null) || continue
  grader=$(echo "$line" | jq -r '.grader' 2>/dev/null) || continue

  [[ -z "$fixture_id" || -z "$fixture_path" || -z "$grader" ]] && continue

  validate_golden "$fixture_id" "$fixture_path" "$grader" || true
done < <(jq -c '.fixtures[]' "$GOLDEN_MANIFEST")

echo
echo "Running known-wrong fixtures..."
while IFS= read -r line; do
  fixture_id=$(echo "$line" | jq -r '.id' 2>/dev/null) || continue
  fixture_path=$(echo "$line" | jq -r '.path' 2>/dev/null) || continue
  grader=$(echo "$line" | jq -r '.grader' 2>/dev/null) || continue

  [[ -z "$fixture_id" || -z "$fixture_path" || -z "$grader" ]] && continue

  validate_known_wrong "$fixture_id" "$fixture_path" "$grader" || true
done < <(jq -c '.fixtures[]' "$KNOWN_WRONG_MANIFEST")

# ========== SUMMARY ==========
echo
echo "=== Test Summary ==="
echo "Golden fixtures passed: $golden_passed"
echo "Golden fixtures failed: $golden_failed"
echo "Known-wrong fixtures correctly rejected: $known_wrong_passed"
echo "Known-wrong fixtures incorrectly passed: $known_wrong_failed"
echo "Total work_count: $total_work_count"
echo "Total rules executed: $rules_executed"
echo
echo "Scores are process-compliance proxies, not quality truth."
echo

# ========== EXIT LOGIC ==========
if [[ $golden_failed -gt 0 ]]; then
  echo "FAILURE: $golden_failed golden fixture(s) failed"
  exit 1
fi

if [[ $known_wrong_failed -gt 0 ]]; then
  echo "FAILURE: $known_wrong_failed known-wrong fixture(s) incorrectly passed"
  exit 1
fi

if [[ $golden_passed -eq 0 ]]; then
  echo "FAILURE: No golden fixtures executed"
  exit 1
fi

if [[ $total_work_count -eq 0 ]]; then
  echo "FAILURE: Total work_count is 0"
  exit 1
fi

if [[ $rules_executed -eq 0 ]]; then
  echo "FAILURE: No rules were executed"
  exit 1
fi

echo "SUCCESS: All golden fixtures passed, all known-wrong fixtures rejected"
exit 0
