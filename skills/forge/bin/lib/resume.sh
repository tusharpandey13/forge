#!/usr/bin/env bash
# resume.sh — forge resume verb: fuzzy-find a feature (ANY status) and surface
# everything needed to continue it: status, phase pointer, open todos, last
# carry_forward, suggested next action. Deterministic; small output.
#
# ENV (from dispatcher): FORGE_STATE, FORGE_DIR, FORGE_JSON_MODE
#
# Usage: forge resume <query>
#   <query> = fuzzy substring matched against feature slug + name (case-insensitive,
#             non-alnum stripped). Best single match wins; ambiguous → list candidates.

set -euo pipefail

JSON_MODE="${FORGE_JSON_MODE:-0}"
STATE_FILE="${FORGE_STATE}"
FORGE_DIR="${FORGE_DIR}"

out_error() {
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":false,"error":"%s"}\n' "$1" >&2
  else
    printf 'forge/resume: error: %s\n' "$1" >&2
  fi
  exit 1
}

cmd_resume() {
  [[ $# -ge 1 ]] || out_error "usage: forge resume <query>"
  # join all args as the query (allows unquoted multi-word)
  local query="$*"
  [[ -f "$STATE_FILE" ]] || out_error "state.json not found at ${STATE_FILE}"

  python3 - "$STATE_FILE" "$FORGE_DIR" "$query" "$JSON_MODE" <<'PYEOF'
import json, sys, os, re

state_file, forge_dir, query, json_mode_s = sys.argv[1:]
json_mode = json_mode_s == "1"

def norm(s):
    return re.sub(r'[^a-z0-9]', '', (s or '').lower())

with open(state_file) as f:
    state = json.load(f)

feats = state.get("features", [])
if not feats:
    print("forge/resume: error: no features in state", file=sys.stderr); sys.exit(1)

q = norm(query)

# score each feature: substring hit on slug or name = strong; token overlap = weak
def score(ft):
    slug_n = norm(ft.get("slug"))
    name_n = norm(ft.get("name"))
    s = 0
    if q and (q in slug_n or q in name_n): s += 100
    if q and (slug_n in q or name_n in q): s += 50
    # token overlap
    qt = set(re.findall(r'[a-z0-9]+', query.lower()))
    ft_t = set(re.findall(r'[a-z0-9]+', (ft.get("slug","")+" "+ft.get("name","")).lower()))
    s += 5 * len(qt & ft_t)
    return s

scored = sorted(((score(ft), ft) for ft in feats), key=lambda x: x[0], reverse=True)
best_score, best = scored[0]

if best_score == 0:
    msg = f"no feature matches '{query}'. Known: " + ", ".join(ft.get("slug","?") for ft in feats)
    if json_mode: print(json.dumps({"ok": False, "error": msg}))
    else: print("forge/resume: " + msg, file=sys.stderr)
    sys.exit(1)

# ambiguity: multiple features tie at top score
ties = [ft for sc, ft in scored if sc == best_score]
if len(ties) > 1:
    cands = [ft.get("slug") for ft in ties]
    if json_mode:
        print(json.dumps({"ok": False, "ambiguous": True, "candidates": cands})); sys.exit(0)
    print(f"forge/resume: ambiguous '{query}' — candidates: {', '.join(cands)}")
    print("Re-run: forge resume <exact-slug>")
    sys.exit(0)

slug = best.get("slug")
name = best.get("name", slug)
status = best.get("status", "unknown")
phases = best.get("phases", {})

# find current/next phase
def pnum(k):
    try: return int(k)
    except: return 0
ordered = sorted(phases.items(), key=lambda kv: pnum(kv[0]))
completed = [k for k,v in ordered if isinstance(v,dict) and v.get("status") in ("completed","approved")]
pending   = [k for k,v in ordered if isinstance(v,dict) and v.get("status") in ("pending",None)]
last_done = completed[-1] if completed else None
next_ph   = pending[0] if pending else None

# last carry_forward = summary of last completed phase ref
last_cf = ""
if last_done:
    r = phases[last_done].get("ref") if isinstance(phases[last_done], dict) else None
    if isinstance(r, dict): last_cf = r.get("summary","")

# open todos across phase bulk files
phases_dir = os.path.join(forge_dir, "features", slug, "phases")
todos = []
if os.path.isdir(phases_dir):
    todo_re = re.compile(r'(TODO|FIXME|HACK|XXX)', re.IGNORECASE)
    for fn in sorted(os.listdir(phases_dir)):
        if not fn.endswith(".json") or fn == "archive.json": continue
        try:
            b = json.load(open(os.path.join(phases_dir, fn)))
        except Exception: continue
        note = (b.get("metadata") or {}).get("note","")
        for ln in note.splitlines():
            if todo_re.search(ln): todos.append(ln.strip())

# suggested next action
if status in ("completed",) and not next_ph:
    if todos:
        nxt = f"Feature COMPLETE. {len(todos)} open todo(s). To act: start a follow-up feature seeded with these todos."
    else:
        nxt = "Feature COMPLETE, no open todos. Start a new feature."
elif next_ph:
    nm = phases[next_ph].get("name","") if isinstance(phases[next_ph],dict) else ""
    nxt = f"Resume at phase {next_ph} — {nm}."
else:
    nxt = "No pending phases; inspect via forge log-query."

if json_mode:
    print(json.dumps({"ok": True, "slug": slug, "name": name, "status": status,
        "last_completed_phase": last_done, "next_phase": next_ph,
        "last_carry_forward": last_cf, "open_todos": todos, "suggested_next": nxt}))
else:
    print(f"FORGE :: resume match → {name}  [{slug}]")
    print(f"  status: {status}   last-done: {last_done or '-'}   next: {next_ph or '-'}")
    if last_cf: print(f"  last carry_forward: {last_cf}")
    if todos:
        print(f"  open todos ({len(todos)}):")
        for t in todos: print(f"    - {t}")
    print(f"  → {nxt}")
PYEOF
}

cmd_resume "$@"
