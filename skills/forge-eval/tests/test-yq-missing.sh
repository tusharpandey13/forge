#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

# TEST: B-YQ-MISSING
# Remove yq from PATH while keeping jq, run engine, assert exit 1 + "yq is a required dependency"
# Strategy: Create tmpbin with symlink to jq only, prepend to PATH to shadow yq

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
ORIGINAL_PATH="$PATH"
trap 'export PATH="$ORIGINAL_PATH"; rm -rf $TMPDIR' EXIT

# Verify jq and yq exist on system
real_jq=$(command -v jq) || {
  echo "FAIL: B-YQ-MISSING — jq not found on system"
  exit 1
}
command -v yq >/dev/null 2>&1 || {
  echo "FAIL: B-YQ-MISSING — yq not found on system"
  exit 1
}

# Create custom tmpbin with jq + other tools, but NOT yq
tmpbin="$TMPDIR/bin-custom"
mkdir -p "$tmpbin"
ln -s "$real_jq" "$tmpbin/jq"

# Symlink critical tools from /usr/bin and /bin, but NOT yq
for tool in grep cat sed awk find dirname basename sort head cut tr which; do
  if [[ -x "/usr/bin/$tool" ]]; then
    ln -s "/usr/bin/$tool" "$tmpbin/$tool" 2>/dev/null || true
  fi
done
if [[ -x "/bin/bash" ]]; then
  ln -s "/bin/bash" "$tmpbin/bash" 2>/dev/null || true
fi

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

# Set PATH: tmpbin first (has jq + tools, but NOT yq)
export PATH="$tmpbin"

# Verify jq IS available
if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: B-YQ-MISSING — jq not available after PATH setup"
  exit 1
fi

# Verify yq is NOT available
if command -v yq >/dev/null 2>&1; then
  echo "FAIL: B-YQ-MISSING — yq still available after PATH manipulation"
  exit 1
fi

# Run engine and capture output + exit code
output=""
rc=0
output=$("$SKILL_ROOT/bin/run-grader.sh" --grader "$grader_file" --fixture "$fixture_file" 2>&1) || rc=$?

# Assert exit code is non-zero
if [[ $rc -eq 0 ]]; then
  echo "FAIL: B-YQ-MISSING — engine exited 0 (expected non-zero)"
  exit 1
fi

# Assert error message mentions yq dependency (not jq)
if ! grep -q "yq is a required dependency" <<< "$output"; then
  echo "FAIL: B-YQ-MISSING — error message missing 'yq is a required dependency'"
  echo "Got: $output"
  exit 1
fi

echo "PASS: B-YQ-MISSING"
exit 0
