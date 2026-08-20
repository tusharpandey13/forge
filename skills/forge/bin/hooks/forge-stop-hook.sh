#!/usr/bin/env bash
# forge-stop-hook.sh — Claude Code session Stop hook for forge
#
# PURPOSE (PLAN.md WS-F F2b):
#   On Claude Code session Stop (intentional or interrupted), flush any in-progress
#   phase's partial carry_forward and refs to disk via forge verbs, so interrupted
#   work is captured across sessions.
#
# REGISTRATION (add to ~/.claude/settings.json — see references/auto-write.md):
#   "hooks": {
#     "Stop": [
#       {
#         "matcher": "",
#         "hooks": [
#           {
#             "type": "command",
#             "command": "/path/to/skills/forge/bin/hooks/forge-stop-hook.sh"
#           }
#         ]
#       }
#     ]
#   }
#
# HOW IT WORKS:
#   1. Locates forge project root (first ancestor with .forge/).
#   2. Reads state.json thin index to detect any feature with a phase in-progress
#      (status == "in_progress" or similar active marker).
#   3. For each in-progress phase: calls forge commit-phase with --log-line
#      "session-stop: partial flush" so refs + current state are committed.
#   4. Exits 0 always (hook failure must not block Claude Code Stop).
#
# SAFETY:
#   - Never mutates user's working tree.
#   - Never pushes to any remote.
#   - Reads forge binary path from FORGE_HOOK_BIN env var, or auto-discovers from
#     SKILL.md symlink path, or falls back to searching .claude/skills.
#   - All errors are logged to stderr and swallowed (exit 0 always).

set -uo pipefail
# NOTE: no set -e — this script must not abort on partial failure; exit 0 always.

# ── locate forge binary ───────────────────────────────────────────────────────
find_forge_bin() {
  # 1. Explicit override
  if [[ -n "${FORGE_HOOK_BIN:-}" && -x "${FORGE_HOOK_BIN}" ]]; then
    echo "$FORGE_HOOK_BIN"
    return 0
  fi

  # 2. Relative to this hook script (canonical path: skills/forge/bin/hooks/forge-stop-hook.sh)
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local candidate="${script_dir}/../forge"
  if [[ -x "$candidate" ]]; then
    echo "$(cd "$candidate" && pwd -P)" 2>/dev/null || echo "$candidate"
    return 0
  fi

  # 3. Search ~/.claude/skills/forge/bin/forge (symlink path)
  local symlink_candidate="${HOME}/.claude/skills/forge/bin/forge"
  if [[ -x "$symlink_candidate" ]]; then
    echo "$symlink_candidate"
    return 0
  fi

  return 1
}

# ── find project root (first ancestor with .forge/) ──────────────────────────
find_project_root() {
  local dir="${FORGE_PROJECT_ROOT:-$PWD}"
  # If FORGE_PROJECT_ROOT already set, trust it
  if [[ -d "${dir}/.forge" ]]; then
    echo "$dir"
    return 0
  fi
  # Walk up
  while [[ "$dir" != "/" ]]; do
    if [[ -d "${dir}/.forge" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  local forge_bin
  if ! forge_bin="$(find_forge_bin)"; then
    printf 'forge-stop-hook: forge binary not found, skipping flush\n' >&2
    return 0
  fi

  local project_root
  if ! project_root="$(find_project_root)"; then
    printf 'forge-stop-hook: no .forge/ directory found from %s, skipping\n' "$PWD" >&2
    return 0
  fi

  local state_file="${project_root}/.forge/state.json"
  if [[ ! -f "$state_file" ]]; then
    printf 'forge-stop-hook: no state.json at %s, skipping\n' "$state_file" >&2
    return 0
  fi

  # Find in-progress phases using python3 (deterministic, no jq dep)
  local in_progress_json
  in_progress_json="$(python3 - "$state_file" <<'PYEOF'
import json, sys
state_file = sys.argv[1]
try:
    with open(state_file) as f:
        state = json.load(f)
except Exception as e:
    print(f"[]")
    sys.exit(0)

results = []
active_statuses = {"in_progress", "active", "started", "running"}

for feat in state.get("features", []):
    slug = feat.get("slug", "")
    for phase_key, phase_data in feat.get("phases", {}).items():
        if isinstance(phase_data, dict):
            status = phase_data.get("status", "")
            if status in active_statuses:
                results.append({"slug": slug, "phase": phase_key, "status": status})

print(json.dumps(results))
PYEOF
  )" || {
    printf 'forge-stop-hook: failed to parse state.json, skipping\n' >&2
    return 0
  }

  local count
  count="$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$in_progress_json" 2>/dev/null || echo 0)"

  if [[ "$count" -eq 0 ]]; then
    printf 'forge-stop-hook: no in-progress phases found, nothing to flush\n' >&2
    return 0
  fi

  printf 'forge-stop-hook: flushing %s in-progress phase(s) to .forge git\n' "$count" >&2

  # Flush each in-progress phase
  python3 - "$in_progress_json" <<'PYEOF' | while IFS=$'\t' read -r slug phase status; do
import json, sys
items = json.loads(sys.argv[1])
for item in items:
    print(f"{item['slug']}\t{item['phase']}\t{item['status']}")
PYEOF
    printf 'forge-stop-hook: committing %s phase %s [%s]\n' "$slug" "$phase" "$status" >&2
    FORGE_PROJECT_ROOT="$project_root" \
    FORGE_STATE="$state_file" \
    FORGE_DIR="${project_root}/.forge" \
    FORGE_JSON_MODE=0 \
      "$forge_bin" commit-phase "$slug" "$phase" "${status}-session-stop" \
        --log-line "session-stop: partial flush from forge-stop-hook" \
        2>&1 || printf 'forge-stop-hook: commit-phase failed for %s phase %s (non-fatal)\n' "$slug" "$phase" >&2
  done

  printf 'forge-stop-hook: flush complete\n' >&2
}

# Run main, always exit 0
main 2>&1 || true
exit 0
