#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

# TEST: B-YAML-MALFORMED
# Grader YAML with syntax error, assert exit 1 + parse-fail message

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf $TMPDIR' EXIT

# Create a valid fixture
fixture_file="$TMPDIR/fixture.json"
cat > "$fixture_file" << 'EOF'
{
  "id": "test-fixture",
  "ref_outputs": {
    "phase_outputs": {
      "quality_gate": {
        "work_count": 1,
        "exit_code": 0
      }
    }
  }
}
EOF

# Create malformed YAML (missing colon on key)
grader_file="$TMPDIR/grader.yml"
cat > "$grader_file" << 'EOF'
id test-grader
level: 1
description: Test grader
rules:
  - id: test-rule
    check: file_exists
    path: test.txt
EOF

# Run engine and capture output + exit code
output=""
rc=0
output=$("$SKILL_ROOT/bin/run-grader.sh" --grader "$grader_file" --fixture "$fixture_file" 2>&1) || rc=$?

# Assert exit code is non-zero
if [[ $rc -eq 0 ]]; then
  echo "FAIL: B-YAML-MALFORMED — engine exited 0 (expected non-zero)"
  exit 1
fi

# Assert error message mentions YAML parse failure
if ! grep -q "YAML parse failed" <<< "$output"; then
  echo "FAIL: B-YAML-MALFORMED — error message missing 'YAML parse failed'"
  echo "Got: $output"
  exit 1
fi

echo "PASS: B-YAML-MALFORMED"
exit 0
