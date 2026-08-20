#!/usr/bin/env bash
# autowrite.sh — forge autowrite-phase verb: merge+mark-complete+commit-phase in one call
#
# Called by bin/forge with env vars set:
#   FORGE_STATE        absolute path to state.json
#   FORGE_DIR          .forge/ directory
#   FORGE_PROJECT_ROOT project root
#   FORGE_JSON_MODE    0|1
#
# DESIGN (PLAN.md WS-F F2a):
#   The phase-completion path already calls commit-phase (WS-B commit.sh).
#   autowrite-phase is a convenience wrapper that does:
#     1. forge merge <slug> <phase> <output-json>
#     2. forge mark-complete <slug> <phase> <status> [--summary "..."]
#     3. forge commit-phase <slug> <phase> <status> [--log-line "..."] [--carry "..."] [--ghost-sha <sha>]
#   in one atomic call, ensuring ref + carry_forward are persisted on phase completion
#   (the "optimistic auto-write during active run" described in CONTEXT.md).
#
# USAGE:
#   forge autowrite-phase <slug> <phase> <status>
#     [--output-json <path>]     # phase output JSON to merge (optional)
#     [--log-line "<prose>"]     # commit log line
#     [--carry "<text>"]         # carry_forward summary
#     [--ghost-sha <sha>]        # project ghost SHA
#     [--artifacts "p1,p2,..."]  # artifact paths
#     [--summary "<text>"]       # mark-complete summary (defaults to carry)

set -euo pipefail

JSON_MODE="${FORGE_JSON_MODE:-0}"
STATE_FILE="${FORGE_STATE}"
FORGE_DIR="${FORGE_DIR}"
FORGE_BIN_DIR="${FORGE_BIN_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ── output helpers ────────────────────────────────────────────────────────────
out_error() {
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":false,"error":"%s"}\n' "$1" >&2
  else
    printf 'forge/autowrite: error: %s\n' "$1" >&2
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

# ── verb: autowrite-phase ─────────────────────────────────────────────────────
cmd_autowrite_phase() {
  [[ $# -ge 3 ]] || out_error "usage: forge autowrite-phase <slug> <phase> <status> [flags]"
  local slug="$1" phase_num="$2" status="$3"
  shift 3

  local output_json=""
  local log_line=""
  local carry_forward=""
  local ghost_sha=""
  local artifacts=""
  local summary=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --output-json) output_json="$2"; shift 2 ;;
      --log-line)    log_line="$2";    shift 2 ;;
      --carry)       carry_forward="$2"; shift 2 ;;
      --ghost-sha)   ghost_sha="$2";   shift 2 ;;
      --artifacts)   artifacts="$2";   shift 2 ;;
      --summary)     summary="$2";     shift 2 ;;
      *) out_error "unknown arg: $1" ;;
    esac
  done

  # Default summary = carry_forward (most useful handoff text)
  if [[ -z "$summary" && -n "$carry_forward" ]]; then
    summary="$carry_forward"
  fi

  local forge_bin="${FORGE_BIN_DIR}/forge"
  [[ -x "$forge_bin" ]] || out_error "forge binary not found at ${forge_bin}"

  # Step 1: merge phase output into state index (optional — skip if no output-json)
  if [[ -n "$output_json" ]]; then
    if [[ ! -f "$output_json" ]]; then
      out_error "--output-json: file not found: ${output_json}"
    fi
    "$forge_bin" merge "$slug" "$phase_num" "$output_json" || out_error "merge failed for ${slug} phase ${phase_num}"
    printf 'autowrite-phase: merged %s phase %s\n' "$slug" "$phase_num" >&2 || true
  fi

  # Step 2: mark-complete — writes thin index entry + bulk NN.json
  local mark_args=("$slug" "$phase_num" "$status")
  if [[ -n "$summary" ]]; then
    mark_args+=(--summary "$summary")
  fi
  "$forge_bin" mark-complete "${mark_args[@]}" || out_error "mark-complete failed for ${slug} phase ${phase_num}"
  printf 'autowrite-phase: mark-complete %s phase %s [%s]\n' "$slug" "$phase_num" "$status" >&2 || true

  # Step 3: commit-phase — persists ref + carry_forward to .forge git
  local commit_args=("$slug" "$phase_num" "$status")
  if [[ -n "$log_line" ]]; then
    commit_args+=(--log-line "$log_line")
  fi
  if [[ -n "$carry_forward" ]]; then
    commit_args+=(--carry "$carry_forward")
  fi
  if [[ -n "$ghost_sha" ]]; then
    commit_args+=(--ghost-sha "$ghost_sha")
  fi
  if [[ -n "$artifacts" ]]; then
    commit_args+=(--artifacts "$artifacts")
  fi
  local commit_out
  commit_out="$("$forge_bin" commit-phase "${commit_args[@]}")" || out_error "commit-phase failed for ${slug} phase ${phase_num}"

  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":true,"slug":"%s","phase":%s,"status":"%s","commit":"%s"}\n' \
      "$slug" "$phase_num" "$status" "$commit_out"
  else
    printf 'autowrite-phase: %s phase %s [%s] persisted\n' "$slug" "$phase_num" "$status"
    printf '  commit: %s\n' "$commit_out"
  fi
}

# ── entry ─────────────────────────────────────────────────────────────────────
verb="$1"
shift
case "$verb" in
  autowrite-phase) cmd_autowrite_phase "$@" ;;
  *) out_error "autowrite.sh: unexpected verb '${verb}'" ;;
esac
