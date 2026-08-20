#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

# TEST: META-LENIENT (edge E-5, FR-2/FR-4, TEST-PLAN section 8 self-test soundness)
#
# "Test your tests": prove the anti-corpus is genuinely discriminating by showing
# that a DELIBERATELY LENIENT grader (one that fails to check the violation the
# fixture contains) WRONGLY passes the known-wrong fixture, while the REAL grader
# correctly rejects it. Because the self-test harness asserts known-wrong fixtures
# must be REJECTED, a lenient grader's wrongful PASS would trip that assertion and
# the harness would exit non-zero — i.e. the anti-corpus catches weak graders.
#
# We use the real anti-corpus fixture fixture-wrong-l3-has-secret, whose config.env
# contains a planted AWS key (AKIAIOSFODNN7EXAMPLE) + aws_secret_access_key.

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$SKILL_ROOT/bin/run-grader.sh"
REAL_GRADER="$SKILL_ROOT/references/graders/grader-l3-no-secrets.yml"
WRONG_FIXTURE="$SKILL_ROOT/fixtures/trees/fixture-wrong-l3-has-secret/fixture.json"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

fail() { echo "FAIL: META-LENIENT — $1"; exit 1; }

[[ -f "$WRONG_FIXTURE" ]] || fail "anti-corpus fixture missing: $WRONG_FIXTURE"

# Deliberately lenient L3 grader: only checks a pattern NOT present in the fixture
# (sk_live_...), so it fails to detect the AKIA secret the fixture actually contains.
cat > "$TMPDIR/grader-l3-lenient.yml" << 'EOF'
id: grader-l3-lenient-variant
level: 3
description: Deliberately weak — checks only a pattern the fixture does not contain
rules:
  - id: rule-only-stripe
    check: no_secrets_pattern
    patterns:
      - "sk_live_[A-Za-z0-9]{24}"
EOF

# 1) REAL grader must REJECT the known-wrong fixture (baseline: fixture is discriminating).
real_rc=0
real_out=$("$ENGINE" --grader "$REAL_GRADER" --fixture "$WRONG_FIXTURE" 2>&1) || real_rc=$?
real_passed=$(echo "$real_out" | jq -r '.passed' 2>/dev/null || echo "error")
[[ "$real_passed" == "false" && $real_rc -ne 0 ]] \
  || fail "real grader should REJECT the secret fixture (passed=$real_passed rc=$real_rc)"

# 2) LENIENT grader WRONGLY PASSES the same fixture (it never checks AKIA).
len_rc=0
len_out=$("$ENGINE" --grader "$TMPDIR/grader-l3-lenient.yml" --fixture "$WRONG_FIXTURE" 2>&1) || len_rc=$?
len_passed=$(echo "$len_out" | jq -r '.passed' 2>/dev/null || echo "error")
[[ "$len_passed" == "true" && $len_rc -eq 0 ]] \
  || fail "lenient grader was expected to WRONGLY pass (passed=$len_passed rc=$len_rc)"

# 3) Emulate the harness known-wrong assertion for the lenient grader: the harness
#    demands REJECTION. The lenient grader's PASS violates that → harness would flag it.
#    (Mirror of validate_known_wrong: accept-when-should-reject == weak grader caught.)
if [[ $len_rc -eq 0 || "$len_passed" == "true" ]]; then
  caught="yes"   # harness would mark known_wrong_failed++ and exit 1
else
  caught="no"
fi
[[ "$caught" == "yes" ]] \
  || fail "harness assertion failed to flag the lenient grader"

echo "  ok real grader REJECTS secret fixture; lenient grader WRONGLY passes; harness catches it"
echo "PASS: META-LENIENT (anti-corpus is discriminating; weak graders are caught)"
exit 0
