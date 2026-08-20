#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

# TEST: B-FIELD-ABSENT
# Grader proof_of_work rule pointing at phase-output file without work_count field
# Assert passed:false and exit 1, not silent pass

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf $TMPDIR' EXIT

# Create fixture with phase output that LACKS work_count
fixture_file="$TMPDIR/fixture.json"
cat > "$fixture_file" << 'EOF'
{
  "id": "test-fixture",
  "ref_outputs": {
    "phase_outputs": {
      "quality_gate": {
        "exit_code": 0
      }
    }
  }
}
EOF

# Create a phase-output file (referenced by grader) that's missing work_count
mkdir -p "$TMPDIR/phase"
phase_output="$TMPDIR/phase/.phase-output.json"
cat > "$phase_output" << 'EOF'
{
  "phase": 10,
  "status": "completed",
  "quality_gate": {
    "exit_code": 0
  }
}
EOF

grader_file="$TMPDIR/grader.yml"
cat > "$grader_file" << 'EOF'
id: test-grader
level: 4
description: Test grader with proof_of_work
rules:
  - id: pow-rule
    check: proof_of_work
    phase_output_path: phase/.phase-output.json
    min_work_count: 1
EOF

# Run engine and capture output + exit code
output=""
rc=0
output=$("$SKILL_ROOT/bin/run-grader.sh" --grader "$grader_file" --fixture "$fixture_file" 2>&1) || rc=$?

# Assert exit code is non-zero (must REJECT, not pass)
if [[ $rc -eq 0 ]]; then
  echo "FAIL: B-FIELD-ABSENT — engine exited 0 (expected non-zero, should reject)"
  exit 1
fi

# Parse JSON to check passed field is false
passed=$(echo "$output" | jq -r '.passed // "missing"' 2>/dev/null || echo "missing")
if [[ "$passed" == "true" ]]; then
  echo "FAIL: B-FIELD-ABSENT — grader passed=true (expected false, silent-pass violation)"
  exit 1
fi

echo "PASS: B-FIELD-ABSENT"
exit 0
