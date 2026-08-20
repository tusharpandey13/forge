#!/usr/bin/env bash
# metadata.sh — forge metadata verb: optional per-entry notes, lazy store
#
# Called by bin/forge with env vars set:
#   FORGE_STATE        absolute path to state.json
#   FORGE_DIR          .forge/ directory
#   FORGE_PROJECT_ROOT project root
#   FORGE_JSON_MODE    0|1
#
# DESIGN (CONTEXT.md / PLAN.md WS-F):
#   - Metadata = optional free-form note attached to a phase entry.
#   - Stored in NN.json bulk file (NOT the hot index slice) — costs nothing until deref'd.
#   - Absent by default; most phases have none.
#   - migrate-learnings: moves state.json top-level learnings → .forge/learnings.json (lazy).
#
# USAGE:
#   forge metadata set <slug> <phase> "<note>"
#   forge metadata get <slug> [--todos]
#   forge metadata migrate-learnings [--state <file>]  # dry-run against /tmp copies only

set -euo pipefail

JSON_MODE="${FORGE_JSON_MODE:-0}"
STATE_FILE="${FORGE_STATE}"
FORGE_DIR="${FORGE_DIR}"

# ── output helpers ────────────────────────────────────────────────────────────
out_error() {
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":false,"error":"%s"}\n' "$1" >&2
  else
    printf 'forge/metadata: error: %s\n' "$1" >&2
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

# ── verb: metadata ────────────────────────────────────────────────────────────
cmd_metadata() {
  [[ $# -ge 1 ]] || out_error "usage: forge metadata <set|get|migrate-learnings> [args...]"

  local sub="$1"
  shift

  case "$sub" in
    set)              cmd_metadata_set "$@" ;;
    get)              cmd_metadata_get "$@" ;;
    migrate-learnings) cmd_migrate_learnings "$@" ;;
    *) out_error "unknown metadata sub-command '${sub}'. Valid: set get migrate-learnings" ;;
  esac
}

# ── sub: metadata set <slug> <phase> "<note>" ─────────────────────────────────
# Attaches a note to a phase's NN.json bulk file. Never writes to hot index.
# If NN.json doesn't exist yet, creates a minimal envelope.
cmd_metadata_set() {
  [[ $# -ge 3 ]] || out_error "usage: forge metadata set <slug> <phase> \"<note>\""
  local slug="$1" phase_num="$2" note="$3"

  [[ -f "$STATE_FILE" ]] || out_error "state.json not found at ${STATE_FILE}"

  python3 - "$STATE_FILE" "$FORGE_DIR" "$slug" "$phase_num" "$note" "$JSON_MODE" <<'PYEOF'
import json, sys, os, datetime

state_file, forge_dir, slug, phase_num_s, note, json_mode_s = sys.argv[1:]
json_mode = json_mode_s == "1"
phase_num = int(phase_num_s)

# Verify feature exists in state
with open(state_file) as f:
    state = json.load(f)

feature = next((ft for ft in state.get("features", []) if ft.get("slug") == slug), None)
if feature is None:
    print(f"forge/metadata: error: feature '{slug}' not found in state", file=sys.stderr)
    sys.exit(1)

# Find phase in feature phases
phases = feature.get("phases", {})
phase_key = str(phase_num)
if phase_key not in phases and phase_num not in phases:
    print(f"forge/metadata: error: phase {phase_num} not found in feature '{slug}'", file=sys.stderr)
    sys.exit(1)

# Determine NN.json path — metadata always lives in bulk, never the hot index
phases_dir = os.path.join(forge_dir, "features", slug, "phases")
os.makedirs(phases_dir, exist_ok=True)
nn_padded = f"{phase_num:02d}"
bulk_path = os.path.join(phases_dir, f"{nn_padded}.json")

# Load or scaffold NN.json
if os.path.isfile(bulk_path):
    with open(bulk_path) as f:
        bulk = json.load(f)
else:
    # Minimal scaffold — existing hot index data stays in state.json
    phase_data = phases.get(phase_key) or phases.get(phase_num, {})
    bulk = {
        "slug": slug,
        "phase": phase_num,
        "scaffolded_by": "metadata.set",
        "artifacts": phase_data.get("artifacts", []) if isinstance(phase_data, dict) else [],
    }

# Attach or update metadata note
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
if "metadata" not in bulk:
    bulk["metadata"] = {}
bulk["metadata"]["note"] = note
bulk["metadata"]["updated"] = now

# Write bulk FIRST (BLK-3 write order)
tmp = bulk_path + ".tmp." + os.urandom(4).hex()
with open(tmp, "w") as f:
    json.dump(bulk, f, indent=2)
os.replace(tmp, bulk_path)

if json_mode:
    print(json.dumps({"ok": True, "slug": slug, "phase": phase_num, "bulk_path": bulk_path}))
else:
    print(f"metadata set: {slug} phase {phase_num} → {bulk_path}")
PYEOF
}

# ── sub: metadata get <slug> [--todos] ────────────────────────────────────────
# Retrieves notes across a feature's phases from their NN.json bulk files.
# --todos greps for todo-like lines in the notes.
cmd_metadata_get() {
  [[ $# -ge 1 ]] || out_error "usage: forge metadata get <slug> [--todos]"
  local slug="$1"
  shift

  local do_todos=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --todos) do_todos=1; shift ;;
      *) out_error "unknown arg: $1" ;;
    esac
  done

  [[ -f "$STATE_FILE" ]] || out_error "state.json not found at ${STATE_FILE}"

  python3 - "$STATE_FILE" "$FORGE_DIR" "$slug" "$do_todos" "$JSON_MODE" <<'PYEOF'
import json, sys, os, re

state_file, forge_dir, slug, todos_s, json_mode_s = sys.argv[1:]
do_todos = todos_s == "1"
json_mode = json_mode_s == "1"

with open(state_file) as f:
    state = json.load(f)

feature = next((ft for ft in state.get("features", []) if ft.get("slug") == slug), None)
if feature is None:
    print(f"forge/metadata: error: feature '{slug}' not found", file=sys.stderr)
    sys.exit(1)

phases_dir = os.path.join(forge_dir, "features", slug, "phases")
results = []

if os.path.isdir(phases_dir):
    for fname in sorted(os.listdir(phases_dir)):
        if not fname.endswith(".json") or fname == "archive.json":
            continue
        fpath = os.path.join(phases_dir, fname)
        try:
            with open(fpath) as f:
                bulk = json.load(f)
        except (json.JSONDecodeError, IOError):
            continue

        meta = bulk.get("metadata")
        if not meta:
            continue

        note = meta.get("note", "")
        if not note:
            continue

        if do_todos:
            # Grep for todo-like patterns (case-insensitive)
            todo_pattern = re.compile(r'(TODO|FIXME|HACK|XXX|todo:|fixme:)', re.IGNORECASE)
            matching_lines = [ln for ln in note.splitlines() if todo_pattern.search(ln)]
            if matching_lines:
                results.append({
                    "phase": bulk.get("phase", fname),
                    "todos": matching_lines
                })
        else:
            results.append({
                "phase": bulk.get("phase", fname),
                "updated": meta.get("updated", ""),
                "note": note
            })

if json_mode:
    print(json.dumps({"ok": True, "slug": slug, "metadata": results}))
else:
    if not results:
        label = "todos" if do_todos else "metadata notes"
        print(f"metadata get: no {label} found for feature '{slug}'")
    else:
        for entry in results:
            if do_todos:
                print(f"  phase {entry['phase']} todos:")
                for line in entry["todos"]:
                    print(f"    {line.strip()}")
            else:
                ts = f" ({entry['updated']})" if entry.get("updated") else ""
                print(f"  phase {entry['phase']}{ts}:")
                print(f"    {entry['note']}")
PYEOF
}

# ── sub: metadata migrate-learnings [--state <file>] ─────────────────────────
# Moves top-level `learnings` object from state.json → .forge/learnings.json.
# Leaves state.json WITHOUT the learnings blob (hot state clean).
# SAFE: only operates on --state <file> or $FORGE_STATE; refuses to touch real
# ~/.forge/state.json unless FORGE_ALLOW_REAL_STATE=1 is set explicitly.
cmd_migrate_learnings() {
  local target_state="$STATE_FILE"
  local dry_run=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --state)   target_state="$2"; shift 2 ;;
      --dry-run) dry_run=1; shift ;;
      *) out_error "unknown arg: $1" ;;
    esac
  done

  [[ -f "$target_state" ]] || out_error "state file not found: ${target_state}"

  # Safety guard: refuse to mutate the canonical ~/.forge/state.json unless explicitly allowed
  local real_forge_state
  real_forge_state="$(python3 -c "import os; print(os.path.realpath('${target_state}'))")"
  local real_home_forge
  real_home_forge="$(python3 -c "import os; print(os.path.realpath(os.path.expanduser('~/.forge/state.json')))")"
  if [[ "$real_forge_state" == "$real_home_forge" && "${FORGE_ALLOW_REAL_STATE:-0}" != "1" ]]; then
    out_error "migrate-learnings: refusing to mutate real ~/.forge/state.json. Use --state /tmp/copy.json to test safely."
  fi

  python3 - "$target_state" "$FORGE_DIR" "$dry_run" "$JSON_MODE" <<'PYEOF'
import json, sys, os, datetime

state_file, forge_dir, dry_run_s, json_mode_s = sys.argv[1:]
dry_run = dry_run_s == "1"
json_mode = json_mode_s == "1"

with open(state_file) as f:
    state = json.load(f)

learnings = state.get("learnings")
if not learnings:
    if json_mode:
        print(json.dumps({"ok": True, "msg": "no learnings key found, nothing to migrate"}))
    else:
        print("migrate-learnings: no 'learnings' key found in state.json — nothing to migrate")
    sys.exit(0)

# Target: .forge/learnings.json (lazy, keyed by topic)
learnings_path = os.path.join(forge_dir, "learnings.json")

# Load existing learnings.json if present (merge/append)
existing = {}
if os.path.isfile(learnings_path):
    try:
        with open(learnings_path) as f:
            existing = json.load(f)
    except (json.JSONDecodeError, IOError):
        existing = {}

# Merge: new topics overlay existing, don't clobber existing entries
merged = {**existing, **learnings}
merged["_migrated_at"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
merged["_migrated_from"] = os.path.basename(state_file)

if dry_run:
    if json_mode:
        print(json.dumps({"ok": True, "dry_run": True, "topics": list(learnings.keys()), "target": learnings_path}))
    else:
        print(f"migrate-learnings [dry-run]: would move {len(learnings)} topics to {learnings_path}")
        for k in learnings:
            print(f"  topic: {k}")
    sys.exit(0)

# Write learnings.json FIRST (BLK-3 write order)
tmp_l = learnings_path + ".tmp." + os.urandom(4).hex()
with open(tmp_l, "w") as f:
    json.dump(merged, f, indent=2)
os.replace(tmp_l, learnings_path)

# Remove learnings from state (atomic update)
del state["learnings"]
tmp_s = state_file + ".tmp." + os.urandom(4).hex()
with open(tmp_s, "w") as f:
    json.dump(state, f, indent=2)
os.replace(tmp_s, state_file)

if json_mode:
    print(json.dumps({"ok": True, "topics_migrated": list(learnings.keys()), "target": learnings_path}))
else:
    print(f"migrate-learnings: moved {len(learnings)} topic(s) to {learnings_path}")
    for k in learnings:
        print(f"  {k}")
    print(f"  state.json learnings key removed.")
PYEOF
}

# ── entry ─────────────────────────────────────────────────────────────────────
[[ $# -ge 1 ]] || { echo "no verb" >&2; exit 1; }
verb="$1"
shift
case "$verb" in
  metadata) cmd_metadata "$@" ;;
  *) out_error "metadata.sh: unexpected verb '${verb}'" ;;
esac
