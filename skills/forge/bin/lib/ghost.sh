#!/usr/bin/env bash
# ghost.sh — forge ghost verbs: ghost-snapshot, ghost-diff, ghost-guard
#
# DESIGN:
#   ghost-snapshot: snapshot project working tree onto refs/heads/forge-ghost/<slug>
#   IN THE PROJECT REPO, WITHOUT touching user's index/HEAD/working branch.
#   Uses a dedicated temp GIT_INDEX_FILE (non-existent path, git creates fresh).
#   Skeleton ignore excludes build junk; KEEPS .env (test artifact, ghost never pushed).
#
#   ghost-diff: git diff between two ghost SHAs in the PROJECT repo (not .forge).
#
# EDGE CASES:
#   - No git repo in project → print "ghost: no project git, snapshot skipped" + exit 2
#   - Submodules → detect gitlink entries, warn, skip them
#   - Detached HEAD → fine (ghost ref is independent)
#
# CROSS-REPO NOTE (REF-SPEC.md):
#   ghost-sha trailer in forge commits resolves against PROJECT repo .git, NOT .forge/.git.

set -euo pipefail

JSON_MODE="${FORGE_JSON_MODE:-0}"
FORGE_PROJECT_ROOT="${FORGE_PROJECT_ROOT}"

out_error() {
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":false,"error":"%s"}\n' "$1" >&2
  else
    printf 'forge/ghost: error: %s\n' "$1" >&2
  fi
  exit 1
}

out_warn() { printf 'forge/ghost: warn: %s\n' "$1" >&2; }

# Returns the project repo root (user's .git, NOT .forge/.git).
find_project_git_root() {
  # Walk up from FORGE_PROJECT_ROOT looking for a .git that isn't the .forge nested git
  local dir="$FORGE_PROJECT_ROOT"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "${dir}/.git" ]] || [[ -f "${dir}/.git" ]]; then
      # Resolve the actual git dir
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

# ── verb: ghost-snapshot ──────────────────────────────────────────────────────
cmd_ghost_snapshot() {
  [[ $# -ge 1 ]] || out_error "usage: forge ghost-snapshot <slug>"
  local slug="$1"

  local proj_root
  if ! proj_root="$(find_project_git_root)"; then
    printf 'ghost: no project git, snapshot skipped\n' >&2
    exit 2
  fi

  local proj_git_dir
  proj_git_dir="$(git -C "$proj_root" rev-parse --absolute-git-dir)"

  local ghost_ref="refs/heads/forge-ghost/${slug}"

  # Create temp dir for our private index + exclude file
  # Use a module-level var so the EXIT trap can reference it reliably
  _GHOST_TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${_GHOST_TMP_DIR:-}"' EXIT
  local tmp_dir="$_GHOST_TMP_DIR"

  # GIT_INDEX_FILE must not pre-exist so git initializes a fresh empty index
  local tmp_index="${tmp_dir}/forge-ghost.idx"
  local tmp_exclude="${tmp_dir}/forge-ghost.exclude"

  # Skeleton exclude patterns (build junk; .env intentionally absent = kept)
  cat > "$tmp_exclude" <<'EXCLUDEOF'
.forge/
.git/
node_modules/
target/
dist/
build/
.cache/
__pycache__/
.venv/
coverage/
*.log
EXCLUDEOF

  # Detect submodule paths (gitlink entries) to skip
  local submodule_paths=()
  if [[ -f "${proj_root}/.gitmodules" ]]; then
    while IFS= read -r sm_path; do
      [[ -n "$sm_path" ]] && submodule_paths+=("$sm_path")
    done < <(git -C "$proj_root" config \
               --file "${proj_root}/.gitmodules" \
               --get-regexp 'submodule\..*\.path' 2>/dev/null \
             | sed 's/^[^ ]* //' || true)
    if [[ ${#submodule_paths[@]} -gt 0 ]]; then
      out_warn "submodules detected (${submodule_paths[*]}): gitlink entries will be skipped"
    fi
  fi

  # Run all git ops in a subshell with the isolated index environment.
  # The subshell's env changes do not leak back.
  local commit_sha
  commit_sha="$(
    export GIT_INDEX_FILE="$tmp_index"
    export GIT_DIR="$proj_git_dir"
    export GIT_WORK_TREE="$proj_root"

    cd "$proj_root"

    # Stage all files from worktree into our fresh empty index.
    # -c core.excludesFile: our skeleton ignore (node_modules, *.log, etc.)
    # --all: stage everything present (tracked + untracked) MINUS skeleton excludes.
    # NOTE: do NOT use --force here — that would bypass excludesFile and stage junk.
    # Project's own .gitignore is also respected; we re-add .env explicitly below.
    git \
      -c "core.excludesFile=${tmp_exclude}" \
      -c "core.worktree=${proj_root}" \
      add --all -- . 2>/dev/null || true

    # Explicitly force-add .env: it may be in project's .gitignore but we keep it.
    # --force here is scoped to just this one path.
    if [[ -f "${proj_root}/.env" ]]; then
      git \
        -c "core.excludesFile=${tmp_exclude}" \
        add --force -- .env 2>/dev/null || true
    fi

    # Remove submodule gitlink entries — they can't be snapshotted cleanly
    for sm_path in "${submodule_paths[@]+"${submodule_paths[@]}"}"; do
      git rm --cached --ignore-unmatch -q -- "$sm_path" 2>/dev/null || true
    done

    # Write tree from our temp index
    local tree_sha
    tree_sha="$(git write-tree)"

    # Determine parent commit (previous ghost SHA if ref exists)
    local parent_args=()
    if git rev-parse --verify "${ghost_ref}" >/dev/null 2>&1; then
      parent_args=("-p" "$(git rev-parse "${ghost_ref}")")
    fi

    # Create forge-internal commit (no hooks, no GPG)
    local now_ts
    now_ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    GIT_AUTHOR_NAME="forge" \
    GIT_AUTHOR_EMAIL="forge@local" \
    GIT_COMMITTER_NAME="forge" \
    GIT_COMMITTER_EMAIL="forge@local" \
    git commit-tree "$tree_sha" \
      "${parent_args[@]}" \
      -m "forge-ghost snapshot: ${slug} at ${now_ts}"
  )"

  # Update the ghost ref in the project repo (no checkout, no index/HEAD side effects)
  GIT_DIR="$proj_git_dir" git update-ref "${ghost_ref}" "$commit_sha"

  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":true,"ghost_sha":"%s","ref":"%s","slug":"%s"}\n' \
      "$commit_sha" "$ghost_ref" "$slug"
  else
    printf 'ghost-snapshot: %s → %s\n' "$slug" "$commit_sha"
  fi
}

# ── verb: ghost-diff ──────────────────────────────────────────────────────────
# ghost-diff <slug> <sha1> <sha2>
# Diff between two SHAs in PROJECT repo. Both must exist in project .git.
cmd_ghost_diff() {
  [[ $# -ge 3 ]] || out_error "usage: forge ghost-diff <slug> <sha1> <sha2>"
  local slug="$1" sha1="$2" sha2="$3"

  local proj_root
  if ! proj_root="$(find_project_git_root)"; then
    out_error "ghost-diff: no project git repo found"
  fi

  git -C "$proj_root" rev-parse --verify "$sha1" >/dev/null 2>&1 \
    || out_error "sha1 '${sha1}' not found in project repo"
  git -C "$proj_root" rev-parse --verify "$sha2" >/dev/null 2>&1 \
    || out_error "sha2 '${sha2}' not found in project repo"

  if [[ "$JSON_MODE" -eq 1 ]]; then
    local diff_output
    diff_output="$(git -C "$proj_root" diff "$sha1" "$sha2" 2>&1 || true)"
    printf '%s' "$diff_output" | python3 -c "
import json, sys
diff = sys.stdin.read()
print(json.dumps({'ok': True, 'slug': sys.argv[1], 'sha1': sys.argv[2], 'sha2': sys.argv[3], 'diff': diff}))
" "$slug" "$sha1" "$sha2"
  else
    git -C "$proj_root" diff "$sha1" "$sha2"
  fi
}

# ── verb: ghost-guard ─────────────────────────────────────────────────────────
# ghost-guard install [--project-root <path>]
# Installs a pre-push hook refusing to push forge-ghost/* refs.
# See references/ghost.md for documentation.
cmd_ghost_guard() {
  [[ $# -ge 1 ]] || out_error "usage: forge ghost-guard install [--project-root <path>]"
  local subcmd="$1"; shift

  case "$subcmd" in
    install)
      local target_root="$FORGE_PROJECT_ROOT"
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --project-root) target_root="$2"; shift 2 ;;
          *) out_error "unknown arg: $1" ;;
        esac
      done

      local proj_git_dir
      proj_git_dir="$(git -C "$target_root" rev-parse --absolute-git-dir 2>/dev/null)" \
        || out_error "ghost-guard: no git repo at ${target_root}"

      local hook_file="${proj_git_dir}/hooks/pre-push"
      local hook_marker="# forge-ghost-guard"

      if [[ -f "$hook_file" ]] && grep -q "$hook_marker" "$hook_file" 2>/dev/null; then
        printf 'ghost-guard: pre-push hook already installed at %s\n' "$hook_file"
        return 0
      fi

      local guard_snippet
      read -r -d '' guard_snippet <<'HOOKEOF' || true

# forge-ghost-guard: refuse to push forge-ghost/* refs (forge internal snapshots, never public)
while read local_ref local_sha remote_ref remote_sha; do
  case "$remote_ref" in
    refs/heads/forge-ghost/*)
      echo "forge-ghost-guard: refusing to push internal forge ghost ref: $remote_ref" >&2
      exit 1
      ;;
  esac
done
HOOKEOF

      if [[ -f "$hook_file" ]]; then
        printf '%s\n' "$guard_snippet" >> "$hook_file"
        printf 'ghost-guard: appended guard to existing hook at %s\n' "$hook_file"
      else
        mkdir -p "${proj_git_dir}/hooks"
        printf '#!/usr/bin/env bash\n%s\n' "$guard_snippet" > "$hook_file"
        chmod +x "$hook_file"
        printf 'ghost-guard: installed pre-push hook at %s\n' "$hook_file"
      fi
      ;;
    *)
      out_error "ghost-guard: unknown subcommand '${subcmd}'. Usage: forge ghost-guard install"
      ;;
  esac
}

# ── dispatch ──────────────────────────────────────────────────────────────────
verb="${1:-}"
shift || true

case "$verb" in
  ghost-snapshot) cmd_ghost_snapshot "$@" ;;
  ghost-diff)     cmd_ghost_diff "$@" ;;
  ghost-guard)    cmd_ghost_guard "$@" ;;
  *)              out_error "ghost.sh: unknown verb '${verb}'" ;;
esac
