#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

# TEST: PROXY-L-ENGINE + PROXY-L-HARNESS (NFR-4, carry-forward M-1)
# Every score emission must carry the proxy-label disclaimer:
#   - engine JSON: top-level proxy_label field
#   - engine JSON: proxy_label on EVERY rule_results[] element (M-1)
#   - harness summary: proxy-label text on a summary line
# A run with zero rules would trivially satisfy "every rule has a label";
# guard against that by requiring at least one rule_result.

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$SKILL_ROOT/bin/run-grader.sh"
HARNESS="$SKILL_ROOT/tests/run-graders-selftest.sh"
GRADER="$SKILL_ROOT/references/graders/grader-l1-file-exists.yml"
FIXTURE="$SKILL_ROOT/fixtures/trees/fixture-golden-l1-basic/fixture.json"

LABEL="Scores are process-compliance proxies, not quality truth."

fail() { echo "FAIL: $1"; exit 1; }

# ---- PROXY-L-ENGINE ----
out=$("$ENGINE" --grader "$GRADER" --fixture "$FIXTURE" 2>&1) || fail "PROXY-L-ENGINE — engine errored: $out"

# Top-level proxy_label present and exact.
top=$(echo "$out" | jq -r '.proxy_label // ""' 2>/dev/null || echo "")
[[ "$top" == "$LABEL" ]] || fail "PROXY-L-ENGINE — top-level proxy_label missing/wrong (got: '$top')"

# At least one rule result exists (so the per-rule assertion is meaningful).
rule_total=$(echo "$out" | jq '.rule_results | length' 2>/dev/null || echo 0)
[[ "$rule_total" -gt 0 ]] || fail "PROXY-L-ENGINE — no rule_results to check"

# Every rule_result carries the exact label.
labeled=$(echo "$out" | jq --arg L "$LABEL" '[.rule_results[] | select(.proxy_label == $L)] | length' 2>/dev/null || echo 0)
[[ "$labeled" -eq "$rule_total" ]] || fail "PROXY-L-ENGINE — only $labeled/$rule_total rule_results carry proxy_label"

echo "  ok PROXY-L-ENGINE: top-level + $labeled/$rule_total rule_results labeled"

# ---- PROXY-L-HARNESS ----
hout=$("$HARNESS" 2>&1) || fail "PROXY-L-HARNESS — harness exited non-zero (expected 0)"
grep -qF "$LABEL" <<< "$hout" || fail "PROXY-L-HARNESS — proxy-label text absent from harness output"

echo "  ok PROXY-L-HARNESS: label present in harness summary"
echo "PASS: PROXY-L (engine + harness)"
exit 0
