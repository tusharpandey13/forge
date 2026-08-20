#!/usr/bin/env bash
# ref.sh — forge ref verb: deref protocol per REF-SPEC.md
#
# Called by bin/forge with env vars set (FORGE_STATE, FORGE_DIR, etc.)
#
# DEREF PROTOCOL (REF-SPEC.md):
#   1. Read envelope from feature index (state.json thin slice).
#   2. Switch on (type, repo):
#      - artifact/project|.forge  → print file path
#      - phase/.forge             → print features/<slug>/phases/NN.json path
#      - ghost/project            → git show <sha> or diff
#   3. --print prints content slice; default prints resolved locator only.
#
# WRITE ORDER (BLK-3):
#   When called to write (--write), writes bulk NN.json FIRST,
#   then atomically updates index in state.json.
#
# USAGE:
#   forge ref <feat-slug> <phase-num-or-name> [--print] [--write <bulk-json>]

set -euo pipefail

JSON_MODE="${FORGE_JSON_MODE:-0}"
STATE_FILE="${FORGE_STATE}"

out_error() {
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":false,"error":"%s"}\n' "$1" >&2
  else
    printf 'forge/ref: error: %s\n' "$1" >&2
  fi
  exit 1
}

validate_slug() {
  local slug="$1"
  if [[ ! "$slug" =~ ^[A-Za-z0-9_-]+$ ]]; then
    out_error "invalid slug '${slug}': must match ^[A-Za-z0-9_-]+\$"
  fi
}

# ── verb: ref ─────────────────────────────────────────────────────────────────
cmd_ref() {
  [[ $# -ge 1 ]] || out_error "usage: forge ref <slug> <phase-or-name> [--print] [--write <bulk-json>]"

  local slug="${1:-}" key="${2:-}"
  validate_slug "$slug"
  shift 2 || out_error "usage: forge ref <slug> <phase-or-name> [--print] [--write <bulk-json>]"

  local do_print=0
  local do_write=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --print) do_print=1; shift ;;
      --write) do_write="${2:-}"; shift 2 ;;
      *) out_error "unknown arg: $1" ;;
    esac
  done

  [[ -f "$STATE_FILE" ]] || out_error "state.json not found at ${STATE_FILE}"

  if [[ -n "$do_write" ]]; then
    # Write mode: write bulk FIRST, then update index (BLK-3)
    [[ -f "$do_write" ]] || out_error "--write: file not found: $do_write"
    _ref_write "$slug" "$key" "$do_write"
  else
    # Deref mode
    _ref_deref "$slug" "$key" "$do_print"
  fi
}

# ── deref: resolve ref envelope → locator (or content) ───────────────────────
_ref_deref() {
  local slug="$1" key="$2" do_print="$3"

  python3 - "$STATE_FILE" "$slug" "$key" "$do_print" "$JSON_MODE" <<'PYEOF'
import json, sys, os, subprocess

state_file, slug, key, do_print_s, json_mode_s = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
do_print = do_print_s == "1"
json_mode = json_mode_s == "1"

with open(state_file) as f:
    state = json.load(f)

# Find feature
feature = None
for feat in state.get("features", []):
    if (feat.get("slug") or feat.get("id")) == slug:
        feature = feat
        break
if feature is None:
    print(f"error: feature '{slug}' not found", file=sys.stderr)
    sys.exit(1)

phases = feature.get("phases", {})

# Resolve key: numeric phase number or phase name substring
envelope = None
matched_phase_key = None
if key.isdigit():
    phase_entry = phases.get(key, {})
    envelope = phase_entry.get("ref")
    matched_phase_key = key
else:
    # Try phase name match
    for pk, pv in phases.items():
        if key.lower() in pv.get("name", "").lower():
            envelope = pv.get("ref")
            matched_phase_key = pk
            break

if envelope is None:
    print(f"error: no ref found for '{slug}' phase '{key}'", file=sys.stderr)
    sys.exit(1)

# Deref per REF-SPEC: switch on (type, repo)
ref_type = envelope.get("type", "phase")
ref_repo = envelope.get("repo", ".forge")
locator  = envelope.get("locator", "")
summary  = envelope.get("summary", "")

def resolve_path(loc, repo):
    """Return absolute path for artifact/phase refs."""
    if os.path.isabs(loc):
        return loc
    if repo == ".forge":
        forge_dir = os.path.dirname(state_file)
        return os.path.join(forge_dir, loc)
    else:  # project
        return os.path.join(os.path.dirname(os.path.dirname(state_file)), loc)

if ref_type in ("artifact", "phase"):
    resolved = resolve_path(locator, ref_repo)
    if json_mode:
        result = {"ok": True, "type": ref_type, "repo": ref_repo,
                  "locator": resolved, "summary": summary}
        if do_print and os.path.exists(resolved):
            with open(resolved) as f:
                result["content"] = json.load(f)
        print(json.dumps(result))
    else:
        print(resolved)
        if summary:
            print(f"# {summary}")
        if do_print:
            if os.path.exists(resolved):
                with open(resolved) as f:
                    print(f.read())
            else:
                print(f"(file not found: {resolved})", file=sys.stderr)

elif ref_type == "ghost":
    # ghost/project → git show <sha>
    project_root = state.get("repository", {}).get("root", "")
    sha = locator
    if json_mode:
        result = {"ok": True, "type": "ghost", "repo": "project",
                  "sha": sha, "summary": summary}
        if do_print and project_root:
            try:
                out = subprocess.check_output(
                    ["git", "-C", project_root, "show", sha],
                    stderr=subprocess.DEVNULL
                ).decode()
                result["content"] = out
            except subprocess.CalledProcessError as e:
                result["error"] = f"git show failed: {e}"
        print(json.dumps(result))
    else:
        print(f"ghost sha: {sha} (project repo: {project_root})")
        if summary:
            print(f"# {summary}")
        if do_print and project_root:
            os.execlp("git", "git", "-C", project_root, "show", sha)
else:
    print(f"error: unknown ref type '{ref_type}'", file=sys.stderr)
    sys.exit(1)
PYEOF
}

# ── write: bulk first, then index (BLK-3) ────────────────────────────────────
_ref_write() {
  local slug="$1" phase_num="$2" bulk_json="$3"

  python3 - "$STATE_FILE" "$slug" "$phase_num" "$bulk_json" "$JSON_MODE" <<'PYEOF'
import json, sys, os, datetime

state_file, slug, phase_num, bulk_json, json_mode_s = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
json_mode = json_mode_s == "1"

with open(state_file) as f:
    state = json.load(f)
with open(bulk_json) as f:
    bulk_data = json.load(f)

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

root_dir = feature.get("root_dir", f".forge/features/{slug}")
phases_dir = os.path.join(root_dir, "phases")
os.makedirs(phases_dir, exist_ok=True)
bulk_file = os.path.join(phases_dir, f"{int(phase_num):02d}.json")

now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# BLK-3: write bulk FIRST (atomic)
bulk_out = dict(bulk_data)
bulk_out["written"] = now
bulk_out["phase"] = int(phase_num)
bulk_out["slug"] = slug

tmp_bulk = bulk_file + ".tmp." + os.urandom(4).hex()
with open(tmp_bulk, "w") as f:
    json.dump(bulk_out, f, indent=2)
os.replace(tmp_bulk, bulk_file)  # atomic

# Build ref envelope per REF-SPEC
summary = bulk_data.get("carry_forward", "")
if isinstance(summary, str):
    summary = summary[:120]
else:
    summary = ""

ref_envelope = {
    "type": "phase",
    "repo": ".forge",
    "locator": bulk_file,
    "summary": summary
}

# Update thin index AFTER bulk write
phase_entry = phases.setdefault(phase_key, {})
phase_entry["status"] = bulk_data.get("status", "completed")
phase_entry["completed"] = now
if not phase_entry.get("started"):
    phase_entry["started"] = now
phase_entry["ref"] = ref_envelope
# Drop bulk fields from index (enforce thin index)
for drop_field in ("artifacts", "decisions", "execution_details", "review_findings", "carry_forward"):
    phase_entry.pop(drop_field, None)

# Atomic state save
tmp_state = state_file + ".tmp." + os.urandom(4).hex()
with open(tmp_state, "w") as f:
    json.dump(state, f, indent=2)
os.replace(tmp_state, state_file)

result = {"ok": True, "bulk": bulk_file, "ref": ref_envelope}
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
  ref) cmd_ref "$@" ;;
  *)   out_error "ref.sh: unexpected verb '${verb}'" ;;
esac
