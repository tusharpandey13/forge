#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

# TEST: B-DETERMINISM-1 / B-DETERMINISM-2
# Run same grader+fixture twice, assert identical output (except executed_at)
# Also run Layer-A harness twice, assert identical exit code + counts

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf $TMPDIR' EXIT

echo "=== B-DETERMINISM-1: Engine Determinism ==="

# Create fixture
fixture_tree="$TMPDIR/det-fixture"
mkdir -p "$fixture_tree"
cat > "$fixture_tree/fixture.json" << 'EOF'
{
  "id": "determinism-test-fixture",
  "ref_outputs": {"phase_outputs": {"quality_gate": {"work_count": 5, "exit_code": 0}}}
}
EOF
cat > "$fixture_tree/DESIGN.md" << 'EOF'
# Design Doc
This is a test design.
EOF

grader_file="$TMPDIR/grader-determinism.yml"
cat > "$grader_file" << 'EOF'
id: grader-determinism-test
level: 1
description: Test determinism
rules:
  - id: rule-1
    check: file_exists
    path: DESIGN.md
  - id: rule-2
    check: file_exists
    path: DESIGN.md
EOF

# Run twice and capture outputs
output1=""
output2=""
output1=$("$SKILL_ROOT/bin/run-grader.sh" --grader "$grader_file" --fixture "$fixture_tree/fixture.json" 2>&1) || true
output2=$("$SKILL_ROOT/bin/run-grader.sh" --grader "$grader_file" --fixture "$fixture_tree/fixture.json" 2>&1) || true

# Strip executed_at field for comparison
output1_stripped=""
output2_stripped=""
output1_stripped=$(echo "$output1" | jq 'del(.executed_at)' 2>/dev/null || echo "$output1")
output2_stripped=$(echo "$output2" | jq 'del(.executed_at)' 2>/dev/null || echo "$output2")

if [[ "$output1_stripped" == "$output2_stripped" ]]; then
  echo "✓ Engine outputs identical (minus executed_at)"
  echo "PASS: B-DETERMINISM-1"
else
  echo "✗ Engine outputs differ"
  echo "Run 1: $output1_stripped"
  echo "Run 2: $output2_stripped"
  exit 1
fi

echo ""
echo "=== B-DETERMINISM-2: Harness Determinism ==="

# Run harness twice and capture summary (exit code + line counts)
harness_output1=""
harness_exit1=0
harness_output1=$("$SKILL_ROOT/tests/run-graders-selftest.sh" 2>&1) || harness_exit1=$?

harness_output2=""
harness_exit2=0
harness_output2=$("$SKILL_ROOT/tests/run-graders-selftest.sh" 2>&1) || harness_exit2=$?

if [[ $harness_exit1 -ne $harness_exit2 ]]; then
  echo "✗ Harness exit codes differ: $harness_exit1 vs $harness_exit2"
  exit 1
fi

# Extract summary counts (golden passed, known-wrong passed, etc.)
count1=0
count2=0
count1=$(echo "$harness_output1" | grep -c "PASSED\|FAILED" || echo "0")
count2=$(echo "$harness_output2" | grep -c "PASSED\|FAILED" || echo "0")

if [[ $count1 -ne $count2 ]]; then
  echo "✗ Harness result counts differ: $count1 vs $count2"
  exit 1
fi

echo "✓ Harness exit code: $harness_exit1 (same both runs)"
echo "✓ Harness result counts: $count1 (same both runs)"
echo "PASS: B-DETERMINISM-2"

exit 0
