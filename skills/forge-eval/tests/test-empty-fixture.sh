#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

# TEST: B-EMPTY-FIXTURE (edge E-1)
# Fixture with empty object {}, assert exit 1

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf $TMPDIR' EXIT

# Create empty fixture
fixture_file="$TMPDIR/fixture.json"
cat > "$fixture_file" << 'EOF'
{}
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
  echo "FAIL: B-EMPTY-FIXTURE — engine exited 0 (expected non-zero)"
  exit 1
fi

# Assert the SPECIFIC fail-loud message for an empty fixture. The engine
# validates id before ref_outputs, so {} fails on the empty-id check. Match
# the exact string (a loose substring like "id" would match almost any error
# and make this test near-tautological).
expected="ERROR: Fixture id is empty"
if ! grep -qF "$expected" <<< "$output"; then
  echo "FAIL: B-EMPTY-FIXTURE — expected exact message: $expected"
  echo "Got: $output"
  exit 1
fi

echo "PASS: B-EMPTY-FIXTURE"
exit 0
