#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

# TEST: B-REF-OUTPUTS-MISSING
# Fixture JSON missing ref_outputs key, assert exit 1 + "ref_outputs"

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf $TMPDIR' EXIT

# Create fixture WITHOUT ref_outputs
fixture_file="$TMPDIR/fixture.json"
cat > "$fixture_file" << 'EOF'
{
  "id": "test-fixture",
  "inputs": {
    "repo_snapshot": "test"
  }
}
EOF

grader_file="$TMPDIR/grader.yml"
cat > "$grader_file" << 'EOF'
id: test-grader
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
  echo "FAIL: B-REF-OUTPUTS-MISSING — engine exited 0 (expected non-zero)"
  exit 1
fi

# Assert error message mentions ref_outputs
if ! grep -q "ref_outputs" <<< "$output"; then
  echo "FAIL: B-REF-OUTPUTS-MISSING — error message missing 'ref_outputs'"
  echo "Got: $output"
  exit 1
fi

echo "PASS: B-REF-OUTPUTS-MISSING"
exit 0
