# Ghost Branch Reference

## Overview

`forge-ghost/<slug>` is an internal branch in the **PROJECT repo** (not `.forge`). It snapshots the project working tree at each phase boundary without touching the user's index, HEAD, or working branch.

## How it works

1. A dedicated `GIT_INDEX_FILE` (a temp path, never the user's index) is created.
2. `git add --all` runs against that temp index using a skeleton excludes file.
3. `git write-tree` produces a tree SHA from the temp index.
4. `git commit-tree` creates a commit with the previous ghost SHA as parent.
5. `git update-ref refs/heads/forge-ghost/<slug>` updates the ref.

The user's index, HEAD, and working branch are never touched.

## Skeleton ignore

Files excluded from snapshots (build junk):
- `node_modules/`
- `target/`
- `dist/`
- `build/`
- `.cache/`
- `__pycache__/`
- `.venv/`
- `coverage/`
- `*.log`

**Intentionally kept**: `.env` — test artifact, ghost never pushed.

## Cross-repo SHA resolution (REF-SPEC.md)

Ghost SHAs live in the **PROJECT repo** (`repo: project`). The forge commit trailer `ghost-sha:` always resolves against the project's `.git`, NOT `.forge/.git`.

When `log-query` or `forge ref` encounters a `ghost-sha` trailer, it must target the project repo:
```
git -C <project_root> show <ghost-sha>
git -C <project_root> diff <sha1> <sha2>
```

## Push guard (B6)

Ghost branches must never be pushed. Install the pre-push hook:

```bash
forge ghost-guard install
```

This installs (or appends to) `.git/hooks/pre-push` in the project repo. The hook refuses any push of `refs/heads/forge-ghost/*`.

To install for a different project root:
```bash
forge ghost-guard install --project-root /path/to/project
```

### Hook snippet (for manual installation)

```bash
# forge-ghost-guard: refuse to push forge-ghost/* refs (forge internal snapshots, never public)
while read local_ref local_sha remote_ref remote_sha; do
  case "$remote_ref" in
    refs/heads/forge-ghost/*)
      echo "forge-ghost-guard: refusing to push internal forge ghost ref: $remote_ref" >&2
      exit 1
      ;;
  esac
done
```

## Verbs

| Verb | Args | Description |
|---|---|---|
| `ghost-snapshot` | `<slug>` | Snapshot project tree → `forge-ghost/<slug>`. Prints resulting SHA. |
| `ghost-diff` | `<slug> <sha1> <sha2>` | `git diff <sha1> <sha2>` in project repo. |
| `ghost-guard install` | `[--project-root <path>]` | Install pre-push hook refusing forge-ghost pushes. |

## Edge cases

- **No project git repo**: prints `ghost: no project git, snapshot skipped` to stderr, exits 2 (nonfatal).
- **Submodules**: gitlink entries detected, warned, skipped from snapshot.
- **Detached HEAD**: works fine; ghost ref is independent of HEAD.
