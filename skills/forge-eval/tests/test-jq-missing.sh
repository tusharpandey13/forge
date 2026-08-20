#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

# TEST: B-JQ-MISSING
# Remove jq from PATH (via tmpbin shadowing), run engine, assert exit 1 + "jq is a required dependency"
# Strategy: Create tmpbin with NO jq, NO yq; prepend to PATH so engine finds no tools

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
# Store original PATH before we modify it
ORIGINAL_PATH="$PATH"
trap 'export PATH="$ORIGINAL_PATH"; rm -rf $TMPDIR' EXIT

# Verify jq exists on system (so we can test its absence)
command -v jq >/dev/null 2>&1 || {
  echo "FAIL: B-JQ-MISSING — jq not found on system"
  exit 1
}

# Create a minimal test fixture
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

# The engine will check `command -v jq` early. To test this, we create a custom PATH with basic tools but no jq.
# We use /usr/bin but rename jq temporarily (or shadow it).
tmpbin="$TMPDIR/bin-custom"
mkdir -p "$tmpbin"

# Symlink critical tools from /usr/bin and /bin, except jq
for tool in grep cat sed awk find dirname basename sort head cut tr which yq; do
  if [[ -x "/usr/bin/$tool" ]]; then
    ln -s "/usr/bin/$tool" "$tmpbin/$tool" 2>/dev/null || true
  fi
done

# Also include /bin/bash
if [[ -x "/bin/bash" ]]; then
  ln -s "/bin/bash" "$tmpbin/bash" 2>/dev/null || true
fi

# DO NOT symlink jq; it's intentionally absent
export PATH="$tmpbin"

# Verify jq is NOT available
if command -v jq >/dev/null 2>&1; then
  echo "FAIL: B-JQ-MISSING — jq still in PATH: $(command -v jq)"
  exit 1
fi

# Run engine and capture output + exit code
output=""
rc=0
output=$("$SKILL_ROOT/bin/run-grader.sh" --grader "$grader_file" --fixture "$fixture_file" 2>&1) || rc=$?

# Assert exit code is non-zero
if [[ $rc -eq 0 ]]; then
  echo "FAIL: B-JQ-MISSING — engine exited 0 (expected non-zero)"
  exit 1
fi

# Assert error message mentions jq dependency
if ! grep -q "jq is a required dependency" <<< "$output"; then
  echo "FAIL: B-JQ-MISSING — error message missing 'jq is a required dependency'"
  echo "Got: $output"
  exit 1
fi

echo "PASS: B-JQ-MISSING"
exit 0
