#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

# ===== Layer-B Test Runner =====
# Executes all test-*.sh scripts (excluding run-graders-selftest.sh)
# Prints per-test PASS/FAIL, exits non-zero if any fail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== forge-eval Layer-B Test Runner ==="
echo

passed=0
failed=0
failed_tests=""

# Find all test-*.sh scripts
for test_script in "$SCRIPT_DIR"/test-*.sh; do
  if [[ ! -f "$test_script" ]]; then
    continue
  fi

  test_name=$(basename "$test_script")

  echo -n "Running $test_name ... "
  if bash "$test_script" > /tmp/test-output.log 2>&1; then
    echo "PASS"
    passed=$((passed+1))
  else
    echo "FAIL"
    failed=$((failed+1))
    failed_tests="$failed_tests\n  $test_name"
    cat /tmp/test-output.log | sed 's/^/    /'
  fi
done

echo
echo "=== Layer-B Summary ==="
echo "Passed: $passed"
echo "Failed: $failed"

if [[ $failed -gt 0 ]]; then
  echo
  echo "Failed tests:$failed_tests"
  exit 1
else
  echo "SUCCESS: All Layer-B tests passed"
  exit 0
fi
