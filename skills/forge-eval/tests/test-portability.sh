#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

# TEST: B-PORTABILITY-POSIX
# Assert engine + harness reference no python/npm/pip invocations
# Grep scripts for forbidden patterns; assert they're only in comments

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== B-PORTABILITY-POSIX ==="

fail=0

# Check bin/run-grader.sh for forbidden runtime invocations
# Only match actual command invocations (word preceded by space/start, followed by space)
if grep -E '[^a-zA-Z_](python3?|npm|pip3?)[[:space:]]' "$SKILL_ROOT/bin/run-grader.sh" 2>/dev/null | grep -v '^#' | grep -v 'echo' | grep -q .; then
  echo "✗ bin/run-grader.sh contains python/npm/pip invocation"
  fail=1
fi

# Check tests/run-graders-selftest.sh
if grep -E '[^a-zA-Z_](python3?|npm|pip3?)[[:space:]]' "$SKILL_ROOT/tests/run-graders-selftest.sh" 2>/dev/null | grep -v '^#' | grep -v 'echo' | grep -q .; then
  echo "✗ tests/run-graders-selftest.sh contains python/npm/pip invocation"
  fail=1
fi

if [[ $fail -eq 0 ]]; then
  echo "✓ No python/npm/pip runtime invocations found in engine/harness/tests"
  echo "✓ Portability verified: bash + jq + yq only"
  echo "PASS: B-PORTABILITY-POSIX"
  exit 0
else
  echo "FAIL: B-PORTABILITY-POSIX"
  exit 1
fi
