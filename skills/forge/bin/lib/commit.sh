#!/usr/bin/env bash
# commit.sh — forge commit verbs: commit-phase, log-query
#
# Called by bin/forge with env vars set:
#   FORGE_STATE        absolute path to state.json
#   FORGE_DIR          .forge/ directory
#   FORGE_PROJECT_ROOT project root
#   FORGE_JSON_MODE    0|1
#
# DESIGN:
#   commit-phase: build a forge commit in .forge/.git.
#     Body = agent-supplied log line + carry_forward.
#     Trailers: ghost-sha, artifacts, feature, phase, status.
#     This REPLACES FORGE-LOGS.md generation — do NOT write/regenerate FORGE-LOGS.md.
#
#   log-query: git log --format=... to reconstruct timeline/audit from commit trailers.
#     Cold path only. ghost-sha trailers resolve against PROJECT repo, not .forge.
#
# TRAILER FORMAT:
#   ghost-sha: <project-repo-sha>   ← resolves in project .git, NOT .forge/.git
#   artifacts: <comma-separated paths>
#   feature: <slug>
#   phase: <N>
#   status: <status>

set -euo pipefail

JSON_MODE="${FORGE_JSON_MODE:-0}"
STATE_FILE="${FORGE_STATE}"
FORGE_DIR="${FORGE_DIR}"

# ── output helpers ────────────────────────────────────────────────────────────
out_error() {
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":false,"error":"%s"}\n' "$1" >&2
  else
    printf 'forge/commit: error: %s\n' "$1" >&2
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

# ── ensure .forge git is initialized ─────────────────────────────────────────
ensure_forge_git() {
  if [[ ! -d "${FORGE_DIR}/.git" ]]; then
    git init "${FORGE_DIR}" -q
    git -C "${FORGE_DIR}" config commit.gpgsign false
    git -C "${FORGE_DIR}" config core.hooksPath /dev/null
    git -C "${FORGE_DIR}" config tag.gpgsign false
    git -C "${FORGE_DIR}" config user.name "forge"
    git -C "${FORGE_DIR}" config user.email "forge@local"
  fi
}

# ── verb: commit-phase ────────────────────────────────────────────────────────
# Usage: forge commit-phase <slug> <N> <status>
#          [--log-line "prose summary"]
#          [--carry "carry_forward text"]
#          [--ghost-sha <sha>]
#          [--artifacts "path1,path2,..."]
#          [--carry-file <path>]   # alternative: read carry_forward from file
#          [--log-file <path>]     # alternative: read log-line from file
#
# Writes a git commit to .forge/.git with trailers.
# Does NOT write or regenerate FORGE-LOGS.md.
cmd_commit_phase() {
  [[ $# -ge 3 ]] || out_error "usage: forge commit-phase <slug> <N> <status> [flags]"
  local slug="$1" phase_num="$2" status="$3"
  shift 3

  local log_line=""
  local carry_forward=""
  local ghost_sha=""
  local artifacts=""
  local carry_file=""
  local log_file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --log-line)   log_line="$2";   shift 2 ;;
      --carry)      carry_forward="$2"; shift 2 ;;
      --ghost-sha)  ghost_sha="$2";  shift 2 ;;
      --artifacts)  artifacts="$2";  shift 2 ;;
      --carry-file) carry_file="$2"; shift 2 ;;
      --log-file)   log_file="$2";   shift 2 ;;
      *) out_error "unknown arg: $1" ;;
    esac
  done

  # Load from files if provided (allows passing large text without shell quoting issues)
  if [[ -n "$log_file" ]]; then
    [[ -f "$log_file" ]] || out_error "--log-file not found: ${log_file}"
    log_line="$(cat "$log_file")"
  fi
  if [[ -n "$carry_file" ]]; then
    [[ -f "$carry_file" ]] || out_error "--carry-file not found: ${carry_file}"
    carry_forward="$(cat "$carry_file")"
  fi

  ensure_forge_git

  # Stage all current .forge state (state.json + any phase bulk files)
  # We add everything in FORGE_DIR except .git itself
  git -C "${FORGE_DIR}" add -A 2>/dev/null || true

  # Build commit message
  # Subject line
  local subject="phase(${slug}): phase ${phase_num} — ${status}"

  # Body: log line + carry_forward
  local body=""
  if [[ -n "$log_line" ]]; then
    body="${log_line}"
  fi
  if [[ -n "$carry_forward" ]]; then
    if [[ -n "$body" ]]; then
      body="${body}"$'\n\n'"carry_forward: ${carry_forward}"
    else
      body="carry_forward: ${carry_forward}"
    fi
  fi

  # Trailers (git trailer format: "key: value" at end of body, blank line before)
  local trailers=""
  trailers+="feature: ${slug}"$'\n'
  trailers+="phase: ${phase_num}"$'\n'
  trailers+="status: ${status}"$'\n'
  if [[ -n "$ghost_sha" ]]; then
    # NOTE: ghost-sha resolves against PROJECT repo, not .forge/.git
    trailers+="ghost-sha: ${ghost_sha}"$'\n'
  fi
  if [[ -n "$artifacts" ]]; then
    trailers+="artifacts: ${artifacts}"$'\n'
  fi

  # Assemble full commit message
  local commit_msg
  if [[ -n "$body" ]]; then
    commit_msg="${subject}"$'\n\n'"${body}"$'\n\n'"${trailers}"
  else
    commit_msg="${subject}"$'\n\n'"${trailers}"
  fi

  # Write commit to .forge git repo
  local commit_sha
  commit_sha="$(
    GIT_AUTHOR_NAME="forge" \
    GIT_AUTHOR_EMAIL="forge@local" \
    GIT_COMMITTER_NAME="forge" \
    GIT_COMMITTER_EMAIL="forge@local" \
    git -C "${FORGE_DIR}" commit \
      --no-gpg-sign \
      --allow-empty \
      -m "$commit_msg" \
      2>&1
  )" || out_error "git commit failed in .forge"

  # Extract SHA from git output or use rev-parse
  local sha
  sha="$(git -C "${FORGE_DIR}" rev-parse HEAD)"

  # Update latest_commit in state.json if it exists
  if [[ -f "$STATE_FILE" ]]; then
    python3 - "$STATE_FILE" "$slug" "$phase_num" "$status" "$sha" "$ghost_sha" <<'PYEOF'
import json, sys, os, datetime
state_file, slug, phase_num, status, sha, ghost_sha = sys.argv[1:]

with open(state_file) as f:
    state = json.load(f)

now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
state["latest_commit"] = {
    "sha": sha,
    "feature": slug,
    "phase": int(phase_num),
    "status": status,
    "ghost_sha": ghost_sha or None,
    "timestamp": now,
    # NOTE: ghost_sha resolves in PROJECT repo .git, not .forge/.git
    "ghost_sha_repo": "project"
}

tmp = state_file + ".tmp." + os.urandom(4).hex()
with open(tmp, "w") as f:
    json.dump(state, f, indent=2)
os.replace(tmp, state_file)
PYEOF
  fi

  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":true,"commit_sha":"%s","slug":"%s","phase":%s,"status":"%s"}\n' \
      "$sha" "$slug" "$phase_num" "$status"
  else
    printf 'commit-phase: %s phase %s [%s] → %s\n' "$slug" "$phase_num" "$status" "$sha"
  fi
}

# ── verb: log-query ───────────────────────────────────────────────────────────
# Usage: forge log-query [--feature <slug>] [--phase N] [--format short|full]
#
# Cold path: reconstructs timeline/audit from forge commit trailers.
# IMPORTANT: ghost-sha trailers resolve against PROJECT repo, not .forge/.git.
# This verb only reads + formats; it does not resolve ghost SHAs automatically
# (that would require opening the project repo — callers use forge ref for that).
cmd_log_query() {
  local filter_feature=""
  local filter_phase=""
  local fmt="short"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --feature) filter_feature="$2"; shift 2 ;;
      --phase)   filter_phase="$2";   shift 2 ;;
      --format)  fmt="$2";            shift 2 ;;
      *) out_error "unknown arg: $1" ;;
    esac
  done

  [[ -d "${FORGE_DIR}/.git" ]] || out_error "no .forge git repo at ${FORGE_DIR}"

  # Use git log with a format that exposes trailers
  # %B = raw body (includes trailers), %H = full sha, %ai = author date iso
  local git_log_format="%H%x09%ai%x09%s%x09%B%x1e"

  local raw_log
  raw_log="$(git -C "${FORGE_DIR}" log --format="${git_log_format}" 2>/dev/null || true)"

  if [[ -z "$raw_log" ]]; then
    if [[ "$JSON_MODE" -eq 1 ]]; then
      printf '{"ok":true,"entries":[]}\n'
    else
      printf 'forge/log-query: no commits in .forge git\n'
    fi
    return 0
  fi

  # Parse with python3: split records on \x1e, extract trailers
  python3 - "$raw_log" "$filter_feature" "$filter_phase" "$fmt" "$JSON_MODE" <<'PYEOF'
import sys, re, json

raw, filter_feat, filter_phase, fmt, json_mode_s = \
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
json_mode = json_mode_s == "1"

def parse_trailers(body):
    """Extract trailer key: value pairs from commit body."""
    trailers = {}
    for line in body.splitlines():
        m = re.match(r'^([a-zA-Z0-9_-]+):\s*(.+)$', line.strip())
        if m:
            trailers[m.group(1).lower().replace('-', '_')] = m.group(2).strip()
    return trailers

entries = []
for record in raw.split('\x1e'):
    record = record.strip()
    if not record:
        continue
    parts = record.split('\t', 3)
    if len(parts) < 4:
        continue
    sha, date, subject, body = parts[0], parts[1], parts[2], parts[3]

    trailers = parse_trailers(body)
    feat = trailers.get('feature', '')
    phase = trailers.get('phase', '')
    status = trailers.get('status', '')
    ghost_sha = trailers.get('ghost_sha', '')
    artifacts = trailers.get('artifacts', '')

    # Apply filters
    if filter_feat and feat != filter_feat:
        continue
    if filter_phase and phase != filter_phase:
        continue

    entry = {
        'sha': sha[:12],
        'date': date[:19],
        'subject': subject,
        'feature': feat,
        'phase': phase,
        'status': status,
        'ghost_sha': ghost_sha,
        # IMPORTANT: ghost_sha resolves in PROJECT repo .git, not .forge/.git
        'ghost_sha_repo': 'project' if ghost_sha else '',
        'artifacts': artifacts,
    }

    if fmt == 'full':
        entry['body'] = body.strip()

    entries.append(entry)

if json_mode:
    print(json.dumps({'ok': True, 'entries': entries}))
else:
    if not entries:
        print('forge/log-query: no matching entries')
        sys.exit(0)
    for e in entries:
        ghost_hint = f"  ghost-sha: {e['ghost_sha']} (project repo)" if e['ghost_sha'] else ""
        art_hint = f"  artifacts: {e['artifacts']}" if e['artifacts'] else ""
        print(f"[{e['sha']}] {e['date']}  {e['subject']}")
        print(f"  feature={e['feature']} phase={e['phase']} status={e['status']}")
        if ghost_hint:
            print(ghost_hint)
        if art_hint:
            print(art_hint)
        if fmt == 'full' and e.get('body'):
            print(f"  body:\n{e['body']}")
        print()
PYEOF
}

# ── dispatch ──────────────────────────────────────────────────────────────────
verb="${1:-}"
shift || true

case "$verb" in
  commit-phase) cmd_commit_phase "$@" ;;
  log-query)    cmd_log_query "$@" ;;
  *)            out_error "commit.sh: unknown verb '${verb}'" ;;
esac
