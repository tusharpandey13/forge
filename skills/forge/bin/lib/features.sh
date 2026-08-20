#!/usr/bin/env bash
# features.sh — forge features verb: compact catalog of ALL features (any status)
# Cheap read: state.json once + phase bulk only for open-todo count.
#
# ENV (from dispatcher): FORGE_STATE, FORGE_DIR, FORGE_JSON_MODE
#
# Usage: forge features
# Output columns: slug | name | status | description (≤120 chars) | phase_progress | open_todo_count

set -euo pipefail

JSON_MODE="${FORGE_JSON_MODE:-0}"
STATE_FILE="${FORGE_STATE}"
FORGE_DIR="${FORGE_DIR}"

out_error() {
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":false,"error":"%s"}\n' "$1" >&2
  else
    printf 'forge/features: error: %s\n' "$1" >&2
  fi
  exit 1
}

cmd_features() {
  [[ -f "$STATE_FILE" ]] || out_error "state.json not found at ${STATE_FILE}"

  python3 - "$STATE_FILE" "$FORGE_DIR" "$JSON_MODE" <<'PYEOF'
import json, sys, os, re

state_file, forge_dir, json_mode_s = sys.argv[1:]
json_mode = json_mode_s == "1"

with open(state_file) as f:
    state = json.load(f)

feats = state.get("features", [])
if not feats:
    if json_mode:
        print(json.dumps({"ok": True, "features": []}))
    else:
        print("forge/features: no features found in state")
    sys.exit(0)

todo_re = re.compile(r'(TODO|FIXME|HACK|XXX)', re.IGNORECASE)

rows = []
for ft in feats:
    slug = ft.get("slug", "")
    name = ft.get("name", slug)
    status = ft.get("status", "unknown")
    desc_raw = ft.get("description", "")
    desc = (desc_raw[:120] + "…") if len(desc_raw) > 120 else desc_raw

    # phase_progress: done/total from hot index
    phases = ft.get("phases", {}) or {}
    total = len(phases)
    done = sum(1 for v in phases.values()
               if isinstance(v, dict) and v.get("status") in ("completed", "approved"))
    phase_progress = f"{done}/{total}" if total else "0/0"

    # open_todo_count from phase bulk files (skip archive.json)
    open_todos = 0
    phases_dir = os.path.join(forge_dir, "features", slug, "phases")
    if os.path.isdir(phases_dir):
        for fn in sorted(os.listdir(phases_dir)):
            if not fn.endswith(".json") or fn == "archive.json":
                continue
            try:
                b = json.load(open(os.path.join(phases_dir, fn)))
            except Exception:
                continue
            note = (b.get("metadata") or {}).get("note", "")
            for ln in note.splitlines():
                if todo_re.search(ln):
                    open_todos += 1

    rows.append({
        "slug": slug,
        "name": name,
        "status": status,
        "description": desc,
        "phase_progress": phase_progress,
        "open_todo_count": open_todos,
    })

if json_mode:
    print(json.dumps({"ok": True, "features": rows}))
else:
    # Aligned table — compact, cheap to read into agent context
    col_slug  = max(len(r["slug"])   for r in rows)
    col_name  = max(len(r["name"])   for r in rows)
    col_stat  = max(len(r["status"]) for r in rows)
    col_prog  = max(len(r["phase_progress"]) for r in rows)

    # header
    hdr = (f"{'SLUG':<{col_slug}}  {'NAME':<{col_name}}  "
           f"{'STATUS':<{col_stat}}  {'PHASES':>{col_prog}}  TODOS  DESCRIPTION")
    print(hdr)
    print("-" * len(hdr))

    for r in rows:
        line = (f"{r['slug']:<{col_slug}}  {r['name']:<{col_name}}  "
                f"{r['status']:<{col_stat}}  {r['phase_progress']:>{col_prog}}  "
                f"{r['open_todo_count']:>5}  {r['description']}")
        print(line)
PYEOF
}

cmd_features "$@"
