#!/usr/bin/env bash
set -euo pipefail

# ===== forge-eval grader engine =====
# Loads grader YAML + fixture JSON; executes all rules; emits composite score + work_count
# Both jq and yq are REQUIRED (fail loud on absence)

# ========== PREAMBLE: JQ & YQ HARD REQUIREMENTS ==========
command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is a required dependency for forge-eval."
  echo "Install: brew install jq (macOS) / apt-get install jq (Linux)"
  exit 1
}

command -v yq >/dev/null 2>&1 || {
  echo "ERROR: yq is a required dependency for forge-eval (YAML parser, mikefarah/yq v4+)."
  echo "Install: brew install yq (macOS) / see https://github.com/mikefarah/yq (Linux)"
  exit 1
}

# ========== ARGUMENT PARSING ==========
grader_yaml=""
fixture_json=""
verbose=false
dry_run=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --grader) grader_yaml="$2"; shift 2 ;;
    --fixture) fixture_json="$2"; shift 2 ;;
    --verbose) verbose=true; shift ;;
    --dry-run) dry_run=true; shift ;;
    *) echo "ERROR: Unknown option $1"; exit 1 ;;
  esac
done

if [[ -z "$grader_yaml" ]] || [[ -z "$fixture_json" ]]; then
  echo "ERROR: --grader and --fixture required"
  exit 1
fi

# ========== PARSE GRADER YAML ==========
grader_json=$(yq -o=json "$grader_yaml" 2>&1) || {
  echo "ERROR: Grader YAML parse failed: $grader_json"
  exit 1
}

grader_id=$(echo "$grader_json" | jq -r '.id' 2>/dev/null) || {
  echo "ERROR: Grader missing 'id' field"
  exit 1
}

level=$(echo "$grader_json" | jq -r '.level' 2>/dev/null) || {
  echo "ERROR: Grader missing 'level' field"
  exit 1
}

: "$(echo "$grader_json" | jq -r '.description // empty' 2>/dev/null)"  # validate parseable; value unused

# ========== PARSE FIXTURE JSON ==========
if [[ ! -f "$fixture_json" ]]; then
  echo "ERROR: Fixture file not found: $fixture_json"
  exit 1
fi

fixture=$(cat "$fixture_json" 2>&1) || {
  echo "ERROR: Cannot read fixture JSON: $fixture_json"
  exit 1
}

fixture_id=$(echo "$fixture" | jq -r '.id // empty' 2>/dev/null) || {
  echo "ERROR: Fixture missing 'id' field"
  exit 1
}

if [[ -z "$fixture_id" ]]; then
  echo "ERROR: Fixture id is empty"
  exit 1
fi

ref_outputs=$(echo "$fixture" | jq '.ref_outputs // empty' 2>/dev/null) || {
  echo "ERROR: Fixture missing ref_outputs key"
  exit 1
}

if [[ -z "$ref_outputs" ]]; then
  echo "ERROR: Fixture ref_outputs is empty"
  exit 1
fi

# Extract fixture directory (absolute). All file-based checks resolve their
# paths relative to this directory (the captured fixture tree root).
fixture_dir=$(cd "$(dirname "$fixture_json")" && pwd)

# ========== DRY-RUN MODE ==========
if [[ "$dry_run" == "true" ]]; then
  echo "=== DRY RUN ==="
  echo "Grader: $grader_id (level $level)"
  echo "Fixture: $fixture_id"
  rules_count=$(echo "$grader_json" | jq '.rules | length' 2>/dev/null || echo 0)
  echo "Rules: $rules_count rules defined"
  exit 0
fi

# ========== CHECK FUNCTIONS ==========

check_file_exists() {
  local path="$1"
  local fixture_dir="$2"

  local full_path="$fixture_dir/$path"

  if [[ -f "$full_path" ]] && [[ -r "$full_path" ]]; then
    echo "{\"passed\": true, \"evidence\": \"file found at $path\"}"
  else
    echo "{\"passed\": false, \"evidence\": \"file not found at $path\"}"
  fi
}

check_symbol_defined() {
  local symbol="$1"
  local source_file="$2"
  local fixture_dir="$3"

  local full_path="$fixture_dir/$source_file"

  if [[ ! -f "$full_path" ]]; then
    echo "{\"passed\": false, \"evidence\": \"source file not found: $source_file\"}"
    return 0
  fi

  if grep -qw "$symbol" "$full_path" 2>/dev/null; then
    local line_number
    line_number=$(grep -n -w "$symbol" "$full_path" 2>/dev/null | head -1 | cut -d: -f1)
    echo "{\"passed\": true, \"evidence\": \"symbol '$symbol' defined at line $line_number\"}"
  else
    echo "{\"passed\": false, \"evidence\": \"symbol '$symbol' not found in $source_file\"}"
  fi
}

check_no_secrets_pattern() {
  local patterns_json="$1"
  local fixture_dir="$2"

  # patterns_json is a jq array of regex strings. Scan every file in the tree;
  # if ANY pattern matches ANY file, the check fails loud (secret present).
  # No subshell state is relied upon: grep -rlE runs in a command substitution
  # whose stdout (matching file paths) is captured directly.
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    pattern=$(echo "$pattern" | jq -r '.')

    local hits
    hits=$(grep -rlE "$pattern" "$fixture_dir" 2>/dev/null | head -3 || true)
    if [[ -n "$hits" ]]; then
      local hit_list
      hit_list=$(printf '%s' "$hits" | tr '\n' ' ')
      echo "{\"passed\": false, \"evidence\": \"secret pattern '$pattern' matched in: $hit_list\"}"
      return 0
    fi
  done < <(echo "$patterns_json" | jq -c '.[]' 2>/dev/null)

  echo "{\"passed\": true, \"evidence\": \"no secret patterns detected\"}"
}

check_proof_of_work() {
  local phase_output_path="$1"
  local min_work_count="$2"
  local fixture_dir="$3"

  local full_path="$fixture_dir/$phase_output_path"

  if [[ ! -f "$full_path" ]]; then
    echo "{\"passed\": false, \"work_count\": 0, \"exit_code\": -1, \"evidence\": \"phase output not found at $phase_output_path\"}"
    return 0
  fi

  local phase_output
  phase_output=$(cat "$full_path" 2>/dev/null) || {
    echo "{\"passed\": false, \"work_count\": 0, \"exit_code\": -1, \"evidence\": \"cannot read phase output\"}"
    return 0
  }

  local work_count
  work_count=$(echo "$phase_output" | jq '.quality_gate.work_count // 0' 2>/dev/null) || {
    echo "{\"passed\": false, \"work_count\": 0, \"exit_code\": -1, \"evidence\": \"cannot parse work_count from phase output\"}"
    return 0
  }

  local exit_code
  exit_code=$(echo "$phase_output" | jq '.quality_gate.exit_code // -1' 2>/dev/null) || {
    echo "{\"passed\": false, \"work_count\": $work_count, \"exit_code\": -1, \"evidence\": \"cannot parse exit_code from phase output\"}"
    return 0
  }

  if (( work_count >= min_work_count )) && (( exit_code == 0 )); then
    echo "{\"passed\": true, \"work_count\": $work_count, \"exit_code\": $exit_code, \"evidence\": \"work_count=$work_count, exit_code=$exit_code\"}"
  else
    echo "{\"passed\": false, \"work_count\": $work_count, \"exit_code\": $exit_code, \"evidence\": \"proof-of-work failed (work_count=$work_count < $min_work_count OR exit_code=$exit_code != 0)\"}"
  fi
}

check_plan_impl_tests_consistency() {
  local plan_path="$1"
  local impl_path="$2"
  local tests_path="$3"
  local fixture_dir="$4"

  local full_plan="$fixture_dir/$plan_path"
  local full_impl="$fixture_dir/$impl_path"
  local full_tests="$fixture_dir/$tests_path"

  local plan_units=0
  local impl_files=0
  local test_count=0

  if [[ -f "$full_plan" ]]; then
    plan_units=$(grep -c "^### Unit" "$full_plan" 2>/dev/null || echo 0)
  fi

  if [[ -d "$full_impl" ]]; then
    impl_files=$(find "$full_impl" -name "*.sh" 2>/dev/null | wc -l)
  fi

  if [[ -d "$full_tests" ]]; then
    test_count=$(find "$full_tests" -type f \( -name "*.sh" -o -name "*.test.ts" -o -name "*.test.js" -o -name "test_*.py" \) 2>/dev/null | wc -l)
  fi

  # Consistency check: if plan_units > 0, impl_files should match or be close
  local consistency_ok=0
  if [[ $plan_units -eq 0 ]] || [[ $impl_files -eq 0 ]] || [[ $test_count -gt 0 ]]; then
    # OK if no plan, or no impl, or test_count > 0
    consistency_ok=1
  elif [[ $test_count -gt 0 ]]; then
    consistency_ok=1
  fi

  if [[ $consistency_ok -eq 1 ]]; then
    echo "{\"passed\": true, \"plan_units\": $plan_units, \"impl_files\": $impl_files, \"test_count\": $test_count, \"evidence\": \"consistency OK\"}"
  else
    echo "{\"passed\": false, \"plan_units\": $plan_units, \"impl_files\": $impl_files, \"test_count\": $test_count, \"evidence\": \"plan/impl/tests mismatch\"}"
  fi
}

check_tautology_heuristic() {
  local test_file_glob="$1"
  local fixture_dir="$2"

  local tests_analyzed=0
  local tests_with_code_symbol=0

  # Expand glob and iterate test files
  while IFS= read -r test_file; do
    [[ -z "$test_file" ]] && continue
    tests_analyzed=$((tests_analyzed+1))

    # Detect language and apply regex heuristic
    case "$test_file" in
      *.ts | *.tsx)
        # JavaScript/TypeScript: expect pattern. POSIX classes ([[:space:]])
        # keep this portable across GNU and BSD grep (macOS) — NFR-6.
        if grep -E 'expect[[:space:]]*\([[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*[\(\.\[]' "$test_file" 2>/dev/null | grep -qv 'expect[[:space:]]*\([[:space:]]*(true|false|null|undefined|[0-9])[[:space:]]*\)'; then
          tests_with_code_symbol=$((tests_with_code_symbol+1))
        fi
        ;;
      *.js)
        if grep -E 'expect[[:space:]]*\([[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*[\(\.\[]' "$test_file" 2>/dev/null | grep -qv 'expect[[:space:]]*\([[:space:]]*(true|false|null|undefined|[0-9])[[:space:]]*\)'; then
          tests_with_code_symbol=$((tests_with_code_symbol+1))
        fi
        ;;
      test_*.py | *_test.py)
        # Python: assert pattern
        if grep -E 'assert[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*[\(\[]|self\.assertEqual[[:space:]]*\([[:space:]]*[a-zA-Z_]' "$test_file" 2>/dev/null; then
          tests_with_code_symbol=$((tests_with_code_symbol+1))
        fi
        ;;
    esac
  done < <(find "$fixture_dir" -path "*$test_file_glob" -type f 2>/dev/null | LC_ALL=C sort)

  if [[ $tests_analyzed -eq 0 ]]; then
    echo "{\"passed\": true, \"tests_analyzed\": 0, \"tests_with_code_symbol\": 0, \"evidence\": \"no test files found (not a failure for this fixture)\"}"
  elif [[ $tests_analyzed -gt 0 ]] && (( tests_with_code_symbol * 100 / tests_analyzed >= 90 )); then
    echo "{\"passed\": true, \"tests_analyzed\": $tests_analyzed, \"tests_with_code_symbol\": $tests_with_code_symbol, \"evidence\": \"$tests_with_code_symbol/$tests_analyzed tests have code symbols\"}"
  else
    echo "{\"passed\": false, \"tests_analyzed\": $tests_analyzed, \"tests_with_code_symbol\": $tests_with_code_symbol, \"evidence\": \"bare-literal assertions detected\"}"
  fi
}

check_surface_aware() {
  local review_file="$1"
  local public_symbols_json="$2"
  local fixture_dir="$3"
  local threshold="$4"

  local full_path="$fixture_dir/$review_file"

  # Fail loud: the surface-aware check REQUIRES a review artifact. A missing
  # review file is a real input gap, not a pass (NFR-2).
  if [[ ! -f "$full_path" ]]; then
    echo "{\"passed\": false, \"findings_on_public\": 0, \"findings_on_internal\": 0, \"evidence\": \"review file not found at $review_file (surface-aware check requires the review artifact)\"}"
    return 0
  fi

  # Gather finding lines (each finding must cite a symbol on the public surface).
  local total_findings
  total_findings=$(grep -cE "Finding|Issue" "$full_path" 2>/dev/null || echo 0)

  if [[ "$total_findings" -eq 0 ]]; then
    echo "{\"passed\": false, \"findings_on_public\": 0, \"findings_on_internal\": 0, \"evidence\": \"no findings detected in review artifact\"}"
    return 0
  fi

  # Count finding lines that reference at least one declared public symbol.
  local public_findings=0
  while IFS= read -r line; do
    while IFS= read -r sym; do
      [[ -z "$sym" ]] && continue
      if printf '%s' "$line" | grep -qF "$sym"; then
        public_findings=$((public_findings+1))
        break
      fi
    done < <(echo "$public_symbols_json" | jq -r '.[]' 2>/dev/null)
  done < <(grep -E "Finding|Issue" "$full_path" 2>/dev/null)

  local internal_findings=$((total_findings - public_findings))

  # Pass when the fraction of findings citing the public surface meets threshold.
  local ratio_ok
  ratio_ok=$(awk -v p="$public_findings" -v t="$total_findings" -v th="$threshold" \
    'BEGIN { if (t > 0 && (p / t) >= th) print 1; else print 0 }')

  if [[ "$ratio_ok" == "1" ]]; then
    echo "{\"passed\": true, \"findings_on_public\": $public_findings, \"findings_on_internal\": $internal_findings, \"evidence\": \"$public_findings/$total_findings findings cite public surface (threshold $threshold)\"}"
  else
    echo "{\"passed\": false, \"findings_on_public\": $public_findings, \"findings_on_internal\": $internal_findings, \"evidence\": \"only $public_findings/$total_findings findings cite public surface, below threshold $threshold\"}"
  fi
}

# ========== EXECUTE RULES ==========
passed_count=0
total_count=0
rule_results_json="[]"

rules=$(echo "$grader_json" | jq -c '.rules[]' 2>/dev/null) || {
  echo "ERROR: Grader has no rules defined"
  exit 1
}

while IFS= read -r rule; do
  [[ -z "$rule" ]] && continue

  rule_id=$(echo "$rule" | jq -r '.id')
  check_type=$(echo "$rule" | jq -r '.check')

  total_count=$((total_count+1))

  if [[ "$verbose" == "true" ]]; then
    echo "  Executing rule: $rule_id (check: $check_type)"
  fi

  # Dispatch check based on type
  check_result=""
  case "$check_type" in
    file_exists)
      path=$(echo "$rule" | jq -r '.path')
      check_result=$(check_file_exists "$path" "$fixture_dir")
      ;;
    symbol_defined)
      symbol=$(echo "$rule" | jq -r '.symbol')
      source_file=$(echo "$rule" | jq -r '.source_file')
      check_result=$(check_symbol_defined "$symbol" "$source_file" "$fixture_dir")
      ;;
    no_secrets_pattern)
      patterns=$(echo "$rule" | jq -c '.patterns' 2>/dev/null)
      check_result=$(check_no_secrets_pattern "$patterns" "$fixture_dir")
      ;;
    proof_of_work)
      phase_output_path=$(echo "$rule" | jq -r '.phase_output_path')
      min_work_count=$(echo "$rule" | jq -r '.min_work_count // 1')
      check_result=$(check_proof_of_work "$phase_output_path" "$min_work_count" "$fixture_dir")
      ;;
    plan_impl_tests_consistency)
      plan_path=$(echo "$rule" | jq -r '.plan_path')
      impl_path=$(echo "$rule" | jq -r '.impl_path')
      tests_path=$(echo "$rule" | jq -r '.tests_path')
      check_result=$(check_plan_impl_tests_consistency "$plan_path" "$impl_path" "$tests_path" "$fixture_dir")
      ;;
    tautology_heuristic)
      test_file_glob=$(echo "$rule" | jq -r '.test_file_glob')
      check_result=$(check_tautology_heuristic "$test_file_glob" "$fixture_dir")
      ;;
    surface_aware)
      review_file=$(echo "$rule" | jq -r '.review_file')
      public_symbols=$(echo "$rule" | jq -c '.public_symbols // []')
      surface_threshold=$(echo "$rule" | jq -r '.threshold // 0.8')
      check_result=$(check_surface_aware "$review_file" "$public_symbols" "$fixture_dir" "$surface_threshold")
      ;;
    *)
      echo "ERROR: Unknown check type: $check_type"
      exit 1
      ;;
  esac

  # Parse check result
  rule_passed=$(echo "$check_result" | jq -r '.passed // false' 2>/dev/null || echo "false")

  if [[ "$rule_passed" == "true" ]]; then
    passed_count=$((passed_count+1))
  fi

  # Append to rule_results array. Proxy label is attached to EVERY rule result
  # (carry-forward M-1): no score fragment is ever emitted without the disclaimer.
  rule_result=$(echo "$check_result" | jq --arg rid "$rule_id" --arg chk "$check_type" \
    --arg proxy_label "Scores are process-compliance proxies, not quality truth." \
    '{rule_id: $rid, check: $chk, passed: (.passed // false), evidence: (.evidence // ""), proxy_label: $proxy_label}' 2>/dev/null)

  rule_results_json=$(echo "$rule_results_json" | jq --argjson rr "$rule_result" '. += [$rr]' 2>/dev/null)

done <<< "$rules"

# ========== COMPOSITE SCORE CALCULATION ==========
if [[ $total_count -eq 0 ]]; then
  echo "ERROR: No rules executed"
  exit 1
fi

score=$(( (passed_count * 100) / total_count ))
work_count=$total_count
passed_bool="false"
if [[ $passed_count -eq $total_count ]]; then
  passed_bool="true"
fi

# ========== EMIT OUTPUT JSON ==========
output=$(jq -n \
  --arg grader_id "$grader_id" \
  --arg fixture_id "$fixture_id" \
  --argjson level "$level" \
  --argjson score "$score" \
  --arg passed "$passed_bool" \
  --argjson work_count "$work_count" \
  --argjson rule_results "$rule_results_json" \
  --arg proxy_label "Scores are process-compliance proxies, not quality truth." \
  '{
    grader_id: $grader_id,
    fixture_id: $fixture_id,
    level: $level,
    score: $score,
    passed: ($passed == "true"),
    work_count: $work_count,
    rule_results: $rule_results,
    proxy_label: $proxy_label,
    executed_at: now | todate
  }')

# Emit to stdout
echo "$output"

# Exit code: 0 if all passed and work_count > 0; 1 otherwise
if [[ "$passed_bool" == "true" ]] && [[ $work_count -gt 0 ]]; then
  exit 0
else
  exit 1
fi
