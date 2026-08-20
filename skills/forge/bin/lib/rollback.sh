#!/usr/bin/env bash
# rollback.sh — forge rollback verb
#
# Called by bin/forge with env vars set:
#   FORGE_STATE        absolute path to state.json
#   FORGE_DIR          .forge/ directory
#   FORGE_PROJECT_ROOT project root
#   FORGE_JSON_MODE    0|1
#
# DESIGN:
#   Default: refs-only rollback (safe).
#     - Reset forge state.json: mark phases N+1..max as pending, drop their refs
#     - Reset forge-ghost/<slug> ref in PROJECT repo to ghost SHA at phase N (if recorded)
#     - Does NOT touch project working tree
#
#   --tree-restore flag: ALSO restore project working tree from ghost snapshot.
#     DESTRUCTIVE: overwrites uncommitted project changes.
#     Requires flag explicitly — will not proceed without it.
#
# Usage:
#   forge rollback <slug> <N>                     # refs-only (safe)
#   forge rollback <slug> <N> --tree-restore      # + restore project working tree (destructive)

set -euo pipefail

JSON_MODE="${FORGE_JSON_MODE:-0}"
STATE_FILE="${FORGE_STATE}"
FORGE_DIR="${FORGE_DIR}"
FORGE_PROJECT_ROOT="${FORGE_PROJECT_ROOT}"

out_error() {
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":false,"error":"%s"}\n' "$1" >&2
  else
    printf 'forge/rollback: error: %s\n' "$1" >&2
  fi
  exit 1
}

validate_slug() {
  local slug="$1"
  if [[ ! "$slug" =~ ^[A-Za-z0-9_-]+$ ]]; then
    out_error "invalid slug '${slug}': must match ^[A-Za-z0-9_-]+\$"
  fi
}

# Returns project repo root (user's .git, NOT .forge/.git)
find_project_git_root() {
  local dir="$FORGE_PROJECT_ROOT"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "${dir}/.git" ]] || [[ -f "${dir}/.git" ]]; then
      local real_git
      real_git="$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null)" || true
      if [[ -n "$real_git" && "$real_git" != *"/.forge/.git" && "$real_git" != *"/.forge/.git/"* ]]; then
        echo "$dir"
        return 0
      fi
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# ── verb: rollback ────────────────────────────────────────────────────────────
cmd_rollback() {
  [[ $# -ge 2 ]] || out_error "usage: forge rollback <slug> <N> [--tree-restore]"
  local slug="$1" target_phase="$2"
  validate_slug "$slug"
  shift 2

  local tree_restore=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tree-restore) tree_restore=1; shift ;;
      *) out_error "unknown arg: $1" ;;
    esac
  done

  [[ -f "$STATE_FILE" ]] || out_error "state.json not found at ${STATE_FILE}"

  # Single python3 pass: rollback state + return ghost SHA at target phase
  local py_result
  py_result="$(python3 - "$STATE_FILE" "$slug" "$target_phase" <<'PYEOF'
import json, sys, os
state_file, slug, target_phase = sys.argv[1], sys.argv[2], int(sys.argv[3])

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

# Extract ghost SHA at target phase (for ghost ref reset)
ghost_sha = ""
phase_entry_at_n = phases.get(str(target_phase), {})
ref_at_n = phase_entry_at_n.get("ref", {})
if ref_at_n.get("type") == "ghost":
    ghost_sha = ref_at_n.get("locator", "")

# Roll back phases after target_phase → pending
rolled_back = []
for n in range(target_phase + 1, max_stage + 1):
    phase_key = str(n)
    p = phases.get(phase_key, {})
    if p and p.get("status") not in ("pending",):
        p["status"] = "pending"
        p.pop("ref", None)
        p.pop("completed", None)
        phases[phase_key] = p
        rolled_back.append(n)

# Atomic save
tmp = state_file + ".tmp." + os.urandom(4).hex()
with open(tmp, "w") as f:
    json.dump(state, f, indent=2)
os.replace(tmp, state_file)

print(json.dumps({"ok": True, "rolled_back_phases": rolled_back, "ghost_sha": ghost_sha}))
PYEOF
  )"

  local ghost_sha rolled_back_phases
  ghost_sha="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('ghost_sha',''))" "$py_result")"
  rolled_back_phases="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('rolled_back_phases',[]))" "$py_result")"

  # Reset forge-ghost/<slug> ref in project repo to ghost SHA at target phase
  local ghost_ref_result="no ghost SHA recorded at phase ${target_phase} — ghost ref NOT reset"
  local proj_root=""
  if proj_root="$(find_project_git_root 2>/dev/null)"; then
    local ghost_ref="refs/heads/forge-ghost/${slug}"
    if [[ -n "$ghost_sha" ]]; then
      if git -C "$proj_root" rev-parse --verify "$ghost_sha" >/dev/null 2>&1; then
        git -C "$proj_root" update-ref "$ghost_ref" "$ghost_sha"
        ghost_ref_result="reset ${ghost_ref} → ${ghost_sha}"
      else
        ghost_ref_result="ghost SHA ${ghost_sha} not found in project repo — ghost ref NOT reset"
        printf 'forge/rollback: warn: %s\n' "$ghost_ref_result" >&2
      fi
    fi
  else
    ghost_ref_result="no project git repo — ghost ref NOT reset"
  fi

  # Optional: tree-restore (destructive — requires explicit flag)
  local tree_restore_result=""
  if [[ "$tree_restore" -eq 1 ]]; then
    if [[ -z "$proj_root" ]] && ! proj_root="$(find_project_git_root 2>/dev/null)"; then
      out_error "tree-restore: no project git repo found"
    fi
    if [[ -z "$ghost_sha" ]]; then
      out_error "tree-restore: no ghost SHA at phase ${target_phase} — cannot restore tree"
    fi

    git -C "$proj_root" rev-parse --verify "$ghost_sha" >/dev/null 2>&1 \
      || out_error "tree-restore: ghost SHA ${ghost_sha} not found in project repo"

    # Restore working tree from ghost snapshot tree without touching HEAD or the
    # real git index. Uses a temp index so `git status` shows NO staged changes.
    local ghost_tree
    ghost_tree="$(git -C "$proj_root" rev-parse "${ghost_sha}^{tree}")"

    local tmp_idx
    tmp_idx="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '${tmp_idx}'" RETURN

    GIT_INDEX_FILE="$tmp_idx" git -C "$proj_root" read-tree "$ghost_tree"
    GIT_INDEX_FILE="$tmp_idx" git -C "$proj_root" checkout-index -a -f --prefix="${proj_root}/"
    rm -f "$tmp_idx"

    tree_restore_result="project working tree restored from ghost snapshot ${ghost_sha} (index NOT staged)"
    printf 'forge/rollback: WARNING: this overwrites working-tree files but does NOT stage anything.\n' >&2
    printf 'forge/rollback: %s\n' "$tree_restore_result"
  fi

  if [[ "$JSON_MODE" -eq 1 ]]; then
    python3 -c "
import json, sys
print(json.dumps({
    'ok': True,
    'slug': sys.argv[1],
    'target_phase': int(sys.argv[2]),
    'ghost_ref': sys.argv[3],
    'tree_restore': sys.argv[4] == '1',
    'tree_restore_result': sys.argv[5]
}))
" "$slug" "$target_phase" "$ghost_ref_result" "$tree_restore" "$tree_restore_result"
  else
    printf 'rollback: %s → phase %s\n' "$slug" "$target_phase"
    printf '  state: phases %s reset to pending\n' "$rolled_back_phases"
    printf '  ghost: %s\n' "$ghost_ref_result"
    if [[ -n "$tree_restore_result" ]]; then
      printf '  tree:  %s\n' "$tree_restore_result"
    fi
  fi
}

# ── dispatch ──────────────────────────────────────────────────────────────────
verb="${1:-}"
shift || true

case "$verb" in
  rollback) cmd_rollback "$@" ;;
  *)        out_error "rollback.sh: unknown verb '${verb}'" ;;
esac
