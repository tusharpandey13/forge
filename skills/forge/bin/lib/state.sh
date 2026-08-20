#!/usr/bin/env bash
# state.sh — forge state verbs: init, status, slice, merge, save, mark-complete,
#             invalidate-downstream, repair
#
# Called by bin/forge after env vars are set:
#   FORGE_STATE        absolute path to state.json
#   FORGE_DIR          .forge/ directory
#   FORGE_PROJECT_ROOT project root
#   FORGE_JSON_MODE    0|1
#
# WRITE ORDER (BLK-3): bulk NN.json written BEFORE index update.
# ATOMICITY: save = write temp + mv (POSIX atomic rename).
# NEVER emits full state.json to stdout (slice is active-feature-only projection).

set -euo pipefail

JSON_MODE="${FORGE_JSON_MODE:-0}"
STATE_FILE="${FORGE_STATE}"
FORGE_DIR="${FORGE_DIR}"

# ── inline python3 helper ────────────────────────────────────────────────────
# All JSON operations go through python3 to avoid jq dependency and ensure
# correctness on arbitrary state shapes.

py() { python3 -c "$1" "${@:2}"; }

# ── slug validation ───────────────────────────────────────────────────────────
validate_slug() {
  local slug="$1"
  if [[ ! "$slug" =~ ^[A-Za-z0-9_-]+$ ]]; then
    out_error "invalid slug '${slug}': must match ^[A-Za-z0-9_-]+\$"
  fi
}

# ── output helpers ───────────────────────────────────────────────────────────
out_error() {
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":false,"error":"%s"}\n' "$1" >&2
  else
    printf 'forge/state: error: %s\n' "$1" >&2
  fi
  exit 1
}

out_ok() {
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":true,"msg":"%s"}\n' "$1"
  else
    printf '%s\n' "$1"
  fi
}

# ── verb: init ───────────────────────────────────────────────────────────────
cmd_init() {
  mkdir -p "${FORGE_DIR}/features"
  mkdir -p "${FORGE_DIR}/context"

  if [[ ! -f "$STATE_FILE" ]]; then
    local now
    now="$(python3 -c 'import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
    python3 - "$STATE_FILE" "$FORGE_PROJECT_ROOT" "$now" <<'PYEOF'
import json, sys
state_file, root, now = sys.argv[1], sys.argv[2], sys.argv[3]
state = {
  "version": "2.0",
  "repository": {"root": root, "created": now, "git_initialized": False},
  "features": [],
  "latest_commit": None
}
tmp = state_file + ".tmp." + __import__("os").urandom(4).hex()
with open(tmp, "w") as f:
    json.dump(state, f, indent=2)
__import__("os").replace(tmp, state_file)
PYEOF
    out_ok "forge: workspace initialized at ${FORGE_DIR}"
  else
    out_ok "forge: workspace already initialized"
  fi

  # git init if needed
  if [[ ! -d "${FORGE_DIR}/.git" ]]; then
    git init "${FORGE_DIR}" -q
    git -C "${FORGE_DIR}" config commit.gpgsign false
    git -C "${FORGE_DIR}" config core.hooksPath /dev/null
    git -C "${FORGE_DIR}" config tag.gpgsign false
    git -C "${FORGE_DIR}" config user.name "forge"
    git -C "${FORGE_DIR}" config user.email "forge@local"
  fi

  # Auto-install ghost-guard in the project repo (fail-open: warn but don't fail init).
  # This ensures forge-ghost/* refs are never accidentally pushed.
  local ghost_sh="${FORGE_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/ghost.sh"
  if [[ -x "$ghost_sh" ]]; then
    FORGE_JSON_MODE=0 \
    FORGE_PROJECT_ROOT="${FORGE_PROJECT_ROOT}" \
    FORGE_STATE="${FORGE_STATE}" \
    FORGE_DIR="${FORGE_DIR}" \
    bash "$ghost_sh" ghost-guard install 2>/dev/null \
      && true \
      || printf 'forge/init: warn: ghost-guard install skipped (no project git or hook write failed)\n' >&2
  fi
}

# ── verb: status ─────────────────────────────────────────────────────────────
# Builds display from thin index slice (never reads full state verbatim).
cmd_status() {
  [[ -f "$STATE_FILE" ]] || out_error "state.json not found at ${STATE_FILE}. Run: forge init"

  python3 - "$STATE_FILE" "$JSON_MODE" <<'PYEOF'
import json, sys

state_file = sys.argv[1]
json_mode = sys.argv[2] == "1"

with open(state_file) as f:
    state = json.load(f)

# find active feature
active = None
for feat in state.get("features", []):
    if feat.get("is_active") or feat.get("status") == "active":
        active = feat
        break

if active is None:
    if json_mode:
        print(json.dumps({"ok": True, "status": "no_active_feature"}))
    else:
        print("FORGE :: NO ACTIVE FEATURE")
        print("  Workspace initialized but no active feature.")
        print("  Next: Create a new feature")
    sys.exit(0)

slug = active.get("slug") or active.get("id", "unknown")
name = active.get("name", slug)
track = active.get("track", "standard")
phases = active.get("phases", {})

max_stage = 4 if track == "lite" else 12
stage_label = "Stage" if track == "lite" else "Phase"

# find current phase (first non-approved/non-completed, or last)
current_phase_num = None
for n in range(1, max_stage + 1):
    p = phases.get(str(n), {})
    st = p.get("status", "pending")
    if st not in ("approved", "completed"):
        current_phase_num = n
        break
if current_phase_num is None:
    current_phase_num = max_stage

cur = phases.get(str(current_phase_num), {})

if json_mode:
    print(json.dumps({
        "ok": True,
        "feature": slug,
        "name": name,
        "track": track,
        "current_phase": current_phase_num,
        "current_status": cur.get("status", "pending"),
        "max_stage": max_stage
    }))
else:
    status_icons = {
        "approved": "✓", "completed": "✓", "in_progress": "⏳",
        "pending": "⊘", "failed": "✗", "invalidated": "↻"
    }
    print(f"FORGE :: {name}  [track: {track}]")
    print(f"  {stage_label}: {current_phase_num} of {max_stage} — {cur.get('name','?')} ({cur.get('status','pending')})")
    print(f"  Created: {active.get('created','?')}")
    print()
    print(f"  {stage_label} Timeline:")
    for n in range(1, max_stage + 1):
        p = phases.get(str(n), {})
        icon = status_icons.get(p.get("status", "pending"), "⊘")
        prefix = f"  {'L' if track == 'lite' else stage_label + ' '}{n:2d}"
        pname = p.get("name", f"Phase {n}")
        pstatus = p.get("status", "pending")
        # Show ref pointer if phase has one (thin index)
        ref_hint = ""
        if "ref" in p:
            ref_hint = f"  → {p['ref'].get('locator','?')}"
            if p['ref'].get('summary'):
                ref_hint += f" [{p['ref']['summary'][:60]}]"
        print(f"{prefix}  {pname:<30} [{icon}  {pstatus}]{ref_hint}")
    print()
    latest = state.get("latest_commit")
    if latest:
        print(f"  Latest commit: {latest.get('sha','')} — {latest.get('message','')}")
PYEOF
}

# ── verb: slice ──────────────────────────────────────────────────────────────
# ACTIVE FEATURE ONLY. Prints {slug, name, track, phases: {N: {ref, summary}}}
# MUST NOT emit full state.json. Target < 1k tokens.
cmd_slice() {
  [[ -f "$STATE_FILE" ]] || out_error "state.json not found at ${STATE_FILE}"

  python3 - "$STATE_FILE" "$JSON_MODE" <<'PYEOF'
import json, sys

state_file = sys.argv[1]
json_mode = sys.argv[2] == "1"

with open(state_file) as f:
    state = json.load(f)

active = None
for feat in state.get("features", []):
    if feat.get("is_active") or feat.get("status") == "active":
        active = feat
        break

if active is None:
    if json_mode:
        print(json.dumps({"ok": True, "active": None}))
    else:
        print("forge/slice: no active feature")
    sys.exit(0)

slug = active.get("slug") or active.get("id", "unknown")
name = active.get("name", slug)
track = active.get("track", "standard")
max_stage = 4 if track == "lite" else 12
phases_raw = active.get("phases", {})

# Thin projection: per-phase emit only {status, ref, summary}
# If phase has a ref envelope (v2), emit ref + summary.
# If legacy v1 phase (has artifacts inline), emit pointer summary only — NOT the bulk.
thin_phases = {}
for n in range(1, max_stage + 1):
    p = phases_raw.get(str(n), {})
    entry = {
        "name": p.get("name", f"Phase {n}"),
        "status": p.get("status", "pending")
    }
    if "ref" in p:
        # v2 thin index entry
        entry["ref"] = p["ref"]
        if p["ref"].get("summary"):
            entry["summary"] = p["ref"]["summary"]
    elif p.get("status") not in ("pending", None):
        # v1 legacy: summarize without inlining bulk
        artifact_count = len(p.get("artifacts", []))
        decision_count = len(p.get("decisions", []))
        entry["summary"] = f"[v1] {artifact_count} artifact(s), {decision_count} decision(s) — deref for detail"
    thin_phases[str(n)] = entry

result = {
    "slug": slug,
    "name": name,
    "track": track,
    "status": active.get("status"),
    "root_dir": active.get("root_dir", ""),
    "phases": thin_phases
}

if json_mode:
    print(json.dumps({"ok": True, "slice": result}))
else:
    print(json.dumps(result, indent=2))
PYEOF
}

# ── verb: save ───────────────────────────────────────────────────────────────
# Atomic write: reads JSON from stdin (or first arg file), writes to STATE_FILE.
# Usage: echo '{...}' | forge save
#        forge save /path/to/new-state.json
cmd_save() {
  local src_json
  if [[ $# -ge 1 && -f "$1" ]]; then
    src_json="$1"
    python3 - "$src_json" "$STATE_FILE" <<'PYEOF'
import json, sys, os
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    state = json.load(f)  # validate JSON
tmp = dst + ".tmp." + os.urandom(4).hex()
with open(tmp, "w") as f:
    json.dump(state, f, indent=2)
os.replace(tmp, dst)
PYEOF
  else
    # read from stdin
    python3 - "$STATE_FILE" <<'PYEOF'
import json, sys, os
dst = sys.argv[1]
raw = sys.stdin.read()
state = json.loads(raw)  # validate
tmp = dst + ".tmp." + os.urandom(4).hex()
with open(tmp, "w") as f:
    json.dump(state, f, indent=2)
os.replace(tmp, dst)
PYEOF
  fi
  out_ok "saved"
}

# ── verb: merge ──────────────────────────────────────────────────────────────
# Merge phase output JSON into state index (thin pointer only).
# Usage: forge merge <feat-slug> <phase-num> <phase-output.json>
# The phase output json is expected to have: phase, status, artifacts, decisions,
# execution_details, carry_forward (optional), review_findings (optional).
# This verb writes BULK to NN.json first (BLK-3), then updates index.
cmd_merge() {
  [[ $# -ge 3 ]] || out_error "usage: forge merge <slug> <phase> <output-json>"
  local slug="$1" phase_num="$2" output_file="$3"
  validate_slug "$slug"
  [[ -f "$output_file" ]] || out_error "output file not found: $output_file"
  [[ -f "$STATE_FILE" ]] || out_error "state.json not found"

  python3 - "$STATE_FILE" "$slug" "$phase_num" "$output_file" <<'PYEOF'
import json, sys, os, datetime

state_file, slug, phase_num, output_file = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

with open(state_file) as f:
    state = json.load(f)
with open(output_file) as f:
    phase_output = json.load(f)

# find feature
feature = None
for feat in state.get("features", []):
    if (feat.get("slug") or feat.get("id")) == slug:
        feature = feat
        break
if feature is None:
    print(f"error: feature '{slug}' not found", file=sys.stderr)
    sys.exit(1)

phases = feature.setdefault("phases", {})
phase_key = str(phase_num)
phase_entry = phases.setdefault(phase_key, {})

# Derive feature root dir
root_dir = feature.get("root_dir", f".forge/features/{slug}")
phases_dir = os.path.join(root_dir, "phases")
os.makedirs(phases_dir, exist_ok=True)
bulk_file = os.path.join(phases_dir, f"{int(phase_num):02d}.json")

# BLK-3: write bulk FIRST
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
bulk = {
    "phase": int(phase_num),
    "slug": slug,
    "written": now,
    "status": phase_output.get("status"),
    "artifacts": phase_output.get("artifacts", []),
    "decisions": phase_output.get("decisions", []),
    "execution_details": phase_output.get("execution_details"),
    "review_findings": phase_output.get("review_findings"),
    "carry_forward": phase_output.get("carry_forward", ""),
}
tmp_bulk = bulk_file + ".tmp." + os.urandom(4).hex()
with open(tmp_bulk, "w") as f:
    json.dump(bulk, f, indent=2)
os.replace(tmp_bulk, bulk_file)

# Build ref envelope per REF-SPEC
summary = phase_output.get("carry_forward", "") or ""
if isinstance(summary, str):
    summary = summary[:120]

ref_envelope = {
    "type": "phase",
    "repo": ".forge",
    "locator": bulk_file,
    "summary": summary
}

# Update thin index entry (AFTER bulk write — BLK-3)
phase_entry["name"] = phase_output.get("name", phase_entry.get("name", f"Phase {phase_num}"))
phase_entry["status"] = phase_output.get("status", "completed")
phase_entry["started"] = phase_entry.get("started")
phase_entry["completed"] = now
phase_entry["ref"] = ref_envelope

# Atomic state save
tmp_state = state_file + ".tmp." + os.urandom(4).hex()
with open(tmp_state, "w") as f:
    json.dump(state, f, indent=2)
os.replace(tmp_state, state_file)

print(json.dumps({"ok": True, "bulk": bulk_file, "ref": ref_envelope}))
PYEOF
}

# ── verb: mark-complete ───────────────────────────────────────────────────────
# Mark a phase complete with a given status and optional summary (carry_forward).
# Usage: forge mark-complete <slug> <phase> <status> [--summary "..."]
# Writes bulk NN.json (minimal skeleton) FIRST, then updates index (BLK-3).
cmd_mark_complete() {
  [[ $# -ge 3 ]] || out_error "usage: forge mark-complete <slug> <phase> <status> [--summary '...']"
  local slug="$1" phase_num="$2" status="$3"
  validate_slug "$slug"
  shift 3
  local summary=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --summary) summary="$2"; shift 2 ;;
      *) out_error "unknown arg: $1" ;;
    esac
  done

  [[ -f "$STATE_FILE" ]] || out_error "state.json not found"

  python3 - "$STATE_FILE" "$slug" "$phase_num" "$status" "$summary" <<'PYEOF'
import json, sys, os, datetime

state_file, slug, phase_num, status, summary = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]

with open(state_file) as f:
    state = json.load(f)

feature = None
for feat in state.get("features", []):
    if (feat.get("slug") or feat.get("id")) == slug:
        feature = feat
        break
if feature is None:
    print(f"error: feature '{slug}' not found", file=sys.stderr)
    sys.exit(1)

phases = feature.setdefault("phases", {})
phase_key = str(phase_num)
phase_entry = phases.setdefault(phase_key, {})

root_dir = feature.get("root_dir", f".forge/features/{slug}")
phases_dir = os.path.join(root_dir, "phases")
os.makedirs(phases_dir, exist_ok=True)
bulk_file = os.path.join(phases_dir, f"{int(phase_num):02d}.json")

now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# BLK-3: write bulk skeleton FIRST
bulk = {
    "phase": int(phase_num),
    "slug": slug,
    "written": now,
    "status": status,
    "artifacts": [],
    "decisions": [],
    "execution_details": None,
    "review_findings": None,
    "carry_forward": summary,
}
# Preserve existing bulk content if present
if os.path.exists(bulk_file):
    try:
        with open(bulk_file) as bf:
            existing = json.load(bf)
        # merge: keep existing artifacts/decisions, update status/carry_forward
        bulk["artifacts"] = existing.get("artifacts", [])
        bulk["decisions"] = existing.get("decisions", [])
        bulk["execution_details"] = existing.get("execution_details")
        bulk["review_findings"] = existing.get("review_findings")
    except Exception:
        pass

tmp_bulk = bulk_file + ".tmp." + os.urandom(4).hex()
with open(tmp_bulk, "w") as f:
    json.dump(bulk, f, indent=2)
os.replace(tmp_bulk, bulk_file)

# Ref envelope
ref_envelope = {
    "type": "phase",
    "repo": ".forge",
    "locator": bulk_file,
    "summary": summary[:120] if summary else ""
}

# Update thin index AFTER bulk write (BLK-3)
phase_entry["name"] = phase_entry.get("name", f"Phase {phase_num}")
phase_entry["status"] = status
phase_entry["completed"] = now
if not phase_entry.get("started"):
    phase_entry["started"] = now
phase_entry["ref"] = ref_envelope

# Atomic state save
tmp_state = state_file + ".tmp." + os.urandom(4).hex()
with open(tmp_state, "w") as f:
    json.dump(state, f, indent=2)
os.replace(tmp_state, state_file)

print(json.dumps({"ok": True, "phase": int(phase_num), "status": status, "bulk": bulk_file}))
PYEOF
}

# ── verb: invalidate-downstream ───────────────────────────────────────────────
# Usage: forge invalidate-downstream <slug> <phase>
# Marks all phases > <phase> as invalidated (except pending ones that haven't started).
cmd_invalidate_downstream() {
  [[ $# -ge 2 ]] || out_error "usage: forge invalidate-downstream <slug> <phase>"
  local slug="$1" phase_num="$2"
  validate_slug "$slug"
  [[ -f "$STATE_FILE" ]] || out_error "state.json not found"

  python3 - "$STATE_FILE" "$slug" "$phase_num" <<'PYEOF'
import json, sys, os

state_file, slug, phase_num = sys.argv[1], sys.argv[2], int(sys.argv[3])

with open(state_file) as f:
    state = json.load(f)

feature = None
for feat in state.get("features", []):
    if (feat.get("slug") or feat.get("id")) == slug:
        feature = feat
        break
if feature is None:
    print(f"error: feature '{slug}' not found", file=sys.stderr)
    sys.exit(1)

phases = feature.get("phases", {})
invalidated = []
track = feature.get("track", "standard")
max_stage = 4 if track == "lite" else 12

for n in range(phase_num + 1, max_stage + 1):
    p = phases.get(str(n), {})
    st = p.get("status", "pending")
    if st not in ("pending", "invalidated"):
        p["status"] = "invalidated"
        phases[str(n)] = p
        invalidated.append(n)

tmp = state_file + ".tmp." + os.urandom(4).hex()
with open(tmp, "w") as f:
    json.dump(state, f, indent=2)
os.replace(tmp, state_file)

print(json.dumps({"ok": True, "invalidated": invalidated}))
PYEOF
}

# ── verb: repair ─────────────────────────────────────────────────────────────
# Scan index for:
#   1. Dangling phase refs: ref.locator file missing → mark phase incomplete
#   2. Orphan NN.json: bulk file exists but no index entry → flag
# Usage: forge repair [state-file]
cmd_repair() {
  local state_path="${1:-$STATE_FILE}"
  [[ -f "$state_path" ]] || out_error "state.json not found at ${state_path}"

  python3 - "$state_path" <<'PYEOF'
import json, sys, os

state_file = sys.argv[1]
with open(state_file) as f:
    state = json.load(f)

issues = []
fixed = []

for feat in state.get("features", []):
    slug = feat.get("slug") or feat.get("id", "unknown")
    phases = feat.get("phases", {})
    root_dir = feat.get("root_dir", f".forge/features/{slug}")
    phases_dir = os.path.join(root_dir, "phases")

    # Check 1: dangling refs
    for phase_key, phase in phases.items():
        ref = phase.get("ref")
        if ref and ref.get("type") == "phase":
            locator = ref.get("locator", "")
            if locator and not os.path.exists(locator):
                issues.append(f"dangling ref: {slug}/phase {phase_key} → {locator}")
                # Mark incomplete
                phase["status"] = "pending"
                del phase["ref"]
                fixed.append(f"marked {slug}/phase {phase_key} as pending (ref missing)")

    # Check 2: orphan NN.json files
    if os.path.isdir(phases_dir):
        for fname in sorted(os.listdir(phases_dir)):
            if fname.endswith(".json") and fname[:-5].isdigit():
                phase_num = str(int(fname[:-5]))
                if phase_num not in phases:
                    issues.append(f"orphan bulk: {slug}/phases/{fname} (no index entry)")
                    # Don't auto-delete; flag only
                elif "ref" not in phases.get(phase_num, {}):
                    # Bulk exists but index missing ref — rebuild ref
                    bulk_path = os.path.join(phases_dir, fname)
                    try:
                        with open(bulk_path) as bf:
                            bulk = json.load(bf)
                        ref = {
                            "type": "phase",
                            "repo": ".forge",
                            "locator": bulk_path,
                            "summary": bulk.get("carry_forward", "")[:120] if bulk.get("carry_forward") else ""
                        }
                        phases[phase_num]["ref"] = ref
                        fixed.append(f"rebuilt ref for {slug}/phase {phase_num} from bulk")
                    except Exception as e:
                        issues.append(f"could not read bulk {bulk_path}: {e}")

if fixed:
    tmp = state_file + ".tmp." + os.urandom(4).hex()
    with open(tmp, "w") as f:
        json.dump(state, f, indent=2)
    os.replace(tmp, state_file)

result = {"ok": True, "issues": issues, "fixed": fixed}
print(json.dumps(result, indent=2))
PYEOF
}

# ── dispatch ─────────────────────────────────────────────────────────────────
verb="${1:-}"
shift || true

case "$verb" in
  init)                  cmd_init "$@" ;;
  status)                cmd_status "$@" ;;
  slice)                 cmd_slice "$@" ;;
  merge)                 cmd_merge "$@" ;;
  save)                  cmd_save "$@" ;;
  mark-complete)         cmd_mark_complete "$@" ;;
  invalidate-downstream) cmd_invalidate_downstream "$@" ;;
  repair)                cmd_repair "$@" ;;
  *)                     out_error "state.sh: unknown verb '${verb}'" ;;
esac
