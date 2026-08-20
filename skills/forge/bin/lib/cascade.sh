#!/usr/bin/env bash
# cascade.sh — forge cascade-fix verb
#
# Called by bin/forge with env vars set:
#   FORGE_STATE        absolute path to state.json
#   FORGE_DIR          .forge/ directory
#   FORGE_PROJECT_ROOT project root
#   FORGE_JSON_MODE    0|1
#
# DESIGN:
#   cascade-fix <slug>:
#     1. Calls forge invalidate-downstream for the affected phase
#        (the first invalidated or pending phase after the last approved/completed one).
#     2. Prints the ordered list of phases needing re-run.
#     Policy: orchestrator is responsible for re-dispatching them; this verb is
#     deterministic and exits 0 with the affected-phase list.
#
# Usage:
#   forge cascade-fix <slug>          # human-readable
#   forge cascade-fix <slug> --json   # JSON output

set -euo pipefail

JSON_MODE="${FORGE_JSON_MODE:-0}"
STATE_FILE="${FORGE_STATE}"
FORGE_DIR="${FORGE_DIR}"

out_error() {
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":false,"error":"%s"}\n' "$1" >&2
  else
    printf 'forge/cascade-fix: error: %s\n' "$1" >&2
  fi
  exit 1
}

# ── slug validation ────────────────────────────────────────────────────────────
validate_slug() {
  local slug="$1"
  if [[ ! "$slug" =~ ^[A-Za-z0-9_-]+$ ]]; then
    out_error "invalid slug '${slug}': must match ^[A-Za-z0-9_-]+\$"
  fi
}

# ── verb: cascade-fix ─────────────────────────────────────────────────────────
cmd_cascade_fix() {
  [[ $# -ge 1 ]] || out_error "usage: forge cascade-fix <slug> [--json]"
  local slug="$1"
  shift

  validate_slug "$slug"
  [[ -f "$STATE_FILE" ]] || out_error "state.json not found at ${STATE_FILE}"

  # Step 1: find first invalidated/pending phase (anchor phase for invalidation)
  # Step 2: call invalidate-downstream from that anchor
  # Step 3: return ordered list of phases needing re-run

  local cascade_result
  cascade_result="$(python3 - "$STATE_FILE" "$slug" <<'PYEOF'
import json, sys, os

state_file, slug = sys.argv[1], sys.argv[2]

with open(state_file) as f:
    state = json.load(f)

feature = None
for feat in state.get("features", []):
    if (feat.get("slug") or feat.get("id")) == slug:
        feature = feat
        break
if feature is None:
    print(json.dumps({"ok": False, "error": f"feature '{slug}' not found"}))
    sys.exit(1)

phases = feature.get("phases", {})
track = feature.get("track", "standard")
max_stage = 4 if track == "lite" else 12

# Find phases needing re-run: any invalidated or pending phases
# The "affected phase" for invalidation anchor = last completed/approved phase
# (invalidate everything after it, then report what needs re-run)
last_good = 0
for n in range(1, max_stage + 1):
    p = phases.get(str(n), {})
    st = p.get("status", "pending")
    if st in ("approved", "completed"):
        last_good = n

# Collect phases needing re-run (invalidated or pending, in order)
needs_rerun = []
for n in range(last_good + 1, max_stage + 1):
    p = phases.get(str(n), {})
    st = p.get("status", "pending")
    if st not in ("approved", "completed"):
        needs_rerun.append({
            "phase": n,
            "name": p.get("name", f"Phase {n}"),
            "status": st
        })

print(json.dumps({
    "ok": True,
    "anchor_phase": last_good,
    "needs_rerun": needs_rerun,
    "slug": slug
}))
PYEOF
  )"

  local ok_val
  ok_val="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('ok' if d.get('ok') else 'fail')" "$cascade_result")"
  if [[ "$ok_val" != "ok" ]]; then
    local err_msg
    err_msg="$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('error','unknown error'))" "$cascade_result")"
    out_error "$err_msg"
  fi

  local anchor_phase
  anchor_phase="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['anchor_phase'])" "$cascade_result")"

  # Call invalidate-downstream from anchor phase (idempotent — marks pending/completed → invalidated)
  "${FORGE_BIN_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/forge" invalidate-downstream "$slug" "$anchor_phase" >/dev/null 2>&1 || true

  if [[ "$JSON_MODE" -eq 1 ]]; then
    python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print(json.dumps({
    'ok': True,
    'slug': d['slug'],
    'anchor_phase': d['anchor_phase'],
    'needs_rerun': d['needs_rerun'],
    'policy': 'orchestrator re-dispatches phases in listed order'
}))
" "$cascade_result"
  else
    python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print(f\"cascade-fix: {d['slug']} — anchor phase {d['anchor_phase']}\")
needs = d['needs_rerun']
if not needs:
    print('  No phases need re-run.')
else:
    print(f\"  Phases needing re-run ({len(needs)}):\")
    for p in needs:
        print(f\"    Phase {p['phase']:2d}  {p['name']:<35} [{p['status']}]\")
    print()
    print('  Policy: orchestrator re-dispatches phases in listed order.')
" "$cascade_result"
  fi
}

# ── dispatch ──────────────────────────────────────────────────────────────────
verb="${1:-}"
shift || true

case "$verb" in
  cascade-fix) cmd_cascade_fix "$@" ;;
  *)           out_error "cascade.sh: unknown verb '${verb}'" ;;
esac
