#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

# TEST: B-DUPLICATE-RULES (edge E-6)
# Two graders check the SAME condition (both file_exists on DESIGN.md). They
# must evaluate INDEPENDENTLY — no deduplication, no shared state. Both reflect
# the real file state: both PASS when the file exists, both FAIL when it does not.

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$SKILL_ROOT/bin/run-grader.sh"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

fail() { echo "FAIL: B-DUPLICATE-RULES — $1"; exit 1; }

# Two distinct graders, same check on the same path.
cat > "$TMPDIR/grader-a.yml" << 'EOF'
id: dup-grader-a
level: 1
rules:
  - id: check-design
    check: file_exists
    path: DESIGN.md
EOF
cat > "$TMPDIR/grader-b.yml" << 'EOF'
id: dup-grader-b
level: 1
rules:
  - id: check-design-again
    check: file_exists
    path: DESIGN.md
EOF

# --- Case 1: file PRESENT → both graders PASS ---
tree_p="$TMPDIR/present"
mkdir -p "$tree_p"
echo '{"id":"dup-present","ref_outputs":{"phase_outputs":{"quality_gate":{"work_count":1,"exit_code":0}}}}' > "$tree_p/fixture.json"
touch "$tree_p/DESIGN.md"

pa=0; pb=0
oa=$("$ENGINE" --grader "$TMPDIR/grader-a.yml" --fixture "$tree_p/fixture.json" 2>&1) || pa=$?
ob=$("$ENGINE" --grader "$TMPDIR/grader-b.yml" --fixture "$tree_p/fixture.json" 2>&1) || pb=$?
[[ $pa -eq 0 ]] || fail "grader-a should PASS when DESIGN.md present (rc=$pa)"
[[ $pb -eq 0 ]] || fail "grader-b should PASS when DESIGN.md present (rc=$pb)"
[[ "$(echo "$oa" | jq -r '.passed')" == "true" ]] || fail "grader-a passed!=true (present)"
[[ "$(echo "$ob" | jq -r '.passed')" == "true" ]] || fail "grader-b passed!=true (present)"

# --- Case 2: file ABSENT → both graders FAIL, independently ---
tree_a="$TMPDIR/absent"
mkdir -p "$tree_a"
echo '{"id":"dup-absent","ref_outputs":{"phase_outputs":{"quality_gate":{"work_count":1,"exit_code":0}}}}' > "$tree_a/fixture.json"
# no DESIGN.md

fa=0; fb=0
oa2=$("$ENGINE" --grader "$TMPDIR/grader-a.yml" --fixture "$tree_a/fixture.json" 2>&1) || fa=$?
ob2=$("$ENGINE" --grader "$TMPDIR/grader-b.yml" --fixture "$tree_a/fixture.json" 2>&1) || fb=$?
[[ $fa -ne 0 ]] || fail "grader-a should FAIL when DESIGN.md absent"
[[ $fb -ne 0 ]] || fail "grader-b should FAIL when DESIGN.md absent"
[[ "$(echo "$oa2" | jq -r '.passed')" == "false" ]] || fail "grader-a passed!=false (absent)"
[[ "$(echo "$ob2" | jq -r '.passed')" == "false" ]] || fail "grader-b passed!=false (absent)"

echo "PASS: B-DUPLICATE-RULES (both graders evaluate independently, reflect file state)"
exit 0
