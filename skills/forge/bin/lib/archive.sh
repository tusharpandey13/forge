#!/usr/bin/env bash
# archive.sh — forge archive verb
#
# Usage: forge archive <slug>
#
# Moves a terminal (completed/inactive) feature's phase bulk files into
# features/<slug>/archive.json and leaves a thin stub in the state.json index.
# This removes completed feature bulk from hot state while preserving a pointer.
#
# Archive format:
#   features/<slug>/archive.json = {
#     "slug": "...",
#     "archived": "<ISO8601>",
#     "phases": { "1": <bulk>, "2": <bulk>, ... }
#   }
#
# Stub left in index:
#   feature entry with phases stripped to {status, ref→archive.json#phase-N}
#
# After archive:
#   - features/<slug>/phases/*.json may be removed (data is in archive.json)
#   - state.json index entry for feature is minimal

set -euo pipefail

JSON_MODE="${FORGE_JSON_MODE:-0}"
STATE_FILE="${FORGE_STATE}"

out_error() {
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":false,"error":"%s"}\n' "$1" >&2
  else
    printf 'forge/archive: error: %s\n' "$1" >&2
  fi
  exit 1
}

cmd_archive() {
  [[ $# -ge 1 ]] || out_error "usage: forge archive <slug>"
  local slug="$1"
  [[ -f "$STATE_FILE" ]] || out_error "state.json not found at ${STATE_FILE}"

  python3 - "$STATE_FILE" "$slug" "$JSON_MODE" <<'PYEOF'
import json, sys, os, datetime

state_file, slug, json_mode_s = sys.argv[1], sys.argv[2], sys.argv[3]
json_mode = json_mode_s == "1"

with open(state_file) as f:
    state = json.load(f)

feature = None
feat_idx = None
for i, feat in enumerate(state.get("features", [])):
    if (feat.get("slug") or feat.get("id")) == slug:
        feature = feat
        feat_idx = i
        break
if feature is None:
    print(f"error: feature '{slug}' not found", file=sys.stderr)
    sys.exit(1)

# Safety: refuse to archive active feature
if feature.get("is_active") or feature.get("status") == "active":
    print(f"error: refusing to archive active feature '{slug}'. Set status to completed/inactive first.", file=sys.stderr)
    sys.exit(1)

root_dir = feature.get("root_dir", f".forge/features/{slug}")
phases_dir = os.path.join(root_dir, "phases")
archive_file = os.path.join(root_dir, "archive.json")

now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# Collect all bulk phase data
bulk_phases = {}
phases_raw = feature.get("phases", {})

for phase_key, phase_entry in phases_raw.items():
    # Load bulk from NN.json if ref points to it
    ref = phase_entry.get("ref", {})
    locator = ref.get("locator", "")

    bulk_data = None
    if locator and os.path.isabs(locator) and os.path.exists(locator):
        try:
            with open(locator) as bf:
                bulk_data = json.load(bf)
        except Exception:
            pass
    elif locator and os.path.exists(locator):
        try:
            with open(locator) as bf:
                bulk_data = json.load(bf)
        except Exception:
            pass

    # If no bulk file, synthesize from v1 inline data (migration path)
    if bulk_data is None:
        bulk_data = {
            "phase": int(phase_key) if phase_key.isdigit() else phase_key,
            "slug": slug,
            "status": phase_entry.get("status"),
            "artifacts": phase_entry.get("artifacts", []),
            "decisions": phase_entry.get("decisions", []),
            "execution_details": phase_entry.get("execution_details"),
            "review_findings": phase_entry.get("review_findings"),
            "carry_forward": phase_entry.get("ref", {}).get("summary", "") if phase_entry.get("ref") else "",
        }

    bulk_phases[phase_key] = bulk_data

# Write archive.json (all bulk consolidated)
archive = {
    "slug": slug,
    "name": feature.get("name", slug),
    "archived": now,
    "original_status": feature.get("status"),
    "track": feature.get("track", "standard"),
    "created": feature.get("created"),
    "phases": bulk_phases
}

tmp_archive = archive_file + ".tmp." + os.urandom(4).hex()
with open(tmp_archive, "w") as f:
    json.dump(archive, f, indent=2)
os.replace(tmp_archive, archive_file)

# Build thin stub phases: status + ref → archive.json (with anchor hint)
stub_phases = {}
for phase_key in phases_raw:
    original = phases_raw[phase_key]
    old_ref = original.get("ref", {})
    stub_phases[phase_key] = {
        "name": original.get("name", f"Phase {phase_key}"),
        "status": original.get("status", "pending"),
        "ref": {
            "type": "artifact",
            "repo": ".forge",
            "locator": archive_file,
            "summary": old_ref.get("summary", "") if old_ref else ""
        }
    }

# Update feature in state: replace phases with stubs, mark archived
state["features"][feat_idx]["phases"] = stub_phases
state["features"][feat_idx]["archived"] = now
state["features"][feat_idx]["archive_ref"] = {
    "type": "artifact",
    "repo": ".forge",
    "locator": archive_file,
    "summary": f"archived {len(stub_phases)} phases"
}

# Atomic state save
tmp_state = state_file + ".tmp." + os.urandom(4).hex()
with open(tmp_state, "w") as f:
    json.dump(state, f, indent=2)
os.replace(tmp_state, state_file)

# Remove individual NN.json files (data is now in archive.json)
removed_bulk = []
if os.path.isdir(phases_dir):
    for fname in os.listdir(phases_dir):
        if fname.endswith(".json") and fname[:-5].isdigit():
            fpath = os.path.join(phases_dir, fname)
            os.remove(fpath)
            removed_bulk.append(fname)

result = {
    "ok": True,
    "slug": slug,
    "archive": archive_file,
    "phases_archived": len(bulk_phases),
    "bulk_removed": removed_bulk
}

if json_mode:
    print(json.dumps(result))
else:
    print(json.dumps(result, indent=2))
PYEOF
}

# ── dispatch ──────────────────────────────────────────────────────────────────
verb="${1:-}"
shift || true

case "$verb" in
  archive) cmd_archive "$@" ;;
  *)       out_error "archive.sh: unexpected verb '${verb}'" ;;
esac
