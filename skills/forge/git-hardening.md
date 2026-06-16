# Git Hardening Specification

## Overview

Forge's `.forge/.git` repository must be completely isolated from the user's global git configuration. This isolation prevents execution hangs due to GPG signing prompts, pre-commit/post-commit hooks, credential authentication prompts, or user identity settings that could interfere with forge operations.

**Problem Statement (RC-3):**
- User's global git config may require GPG signing (commits hang indefinitely)
- Pre-commit/post-commit hooks may execute side effects (unpredictable behavior)
- Credential helpers may prompt for authentication (task agents cannot interact)
- Forge should have its own identity, not leak user's git identity

**Solution:** Defensive initialization applies explicit idempotent configuration that prevents all execution risks while ensuring forge's git operations never depend on user config.

---

## Component 1: Defensive Git Initialization

### Requirement: initialize_forge_git(project_root)

Idempotent function to initialize `.forge/.git` with defensive configuration. Can be called multiple times safely; subsequent calls verify config is correct and overwrite if necessary.

#### Algorithm

```
FUNCTION initialize_forge_git(project_root):
    forge_dir = project_root + "/.forge"
    git_dir = forge_dir + "/.git"

    // Step 1: Create .forge directory structure (idempotent)
    CREATE_DIRECTORY(forge_dir)
    CREATE_DIRECTORY(forge_dir + "/features")
    CREATE_DIRECTORY(forge_dir + "/context")

    // Step 2: Initialize git repo (idempotent: safe to run if already exists)
    RUN("git init", cwd: forge_dir)

    // Step 3: Apply defensive config (all idempotent)
    // Each command succeeds silently if already set to desired value
    EXECUTE_IDEMPOTENT([
        "git -C " + forge_dir + " config commit.gpgsign false",
        "git -C " + forge_dir + " config core.hooksPath /dev/null",
        "git -C " + forge_dir + " config tag.gpgsign false",
        "git -C " + forge_dir + " config user.name 'forge'",
        "git -C " + forge_dir + " config user.email 'forge@local'",
        "git -C " + forge_dir + " config core.ignorecase false"
    ])

    // Step 4: Create .git/info/exclude (local gitignore, prevents tracking of temp files)
    CREATE_FILE(git_dir + "/info/exclude", content: """
# Forge internal files (not tracked)
.DS_Store
*.tmp
*.swp
*.lock
.phase-*-output.json
.phase-*-error.json
""")

    // Step 5: Initial commit (verifies git is working)
    RUN("git -C " + forge_dir + " add -A", expect: success)

    commit_msg = "forge: init workspace"
    RUN("git -C " + forge_dir + " commit -m '" + commit_msg + "'",
        timeout: 5_seconds,
        on_error: "warn (may have no changes if re-initializing)")

    // Step 6: Log initialization
    APPEND_LINE(forge_dir + "/operations.jsonl", {
        ts: ISO8601_NOW(),
        op: "git_init",
        message: "Initialized .forge/.git with defensive config"
    })

    RETURN {success: true, git_dir: git_dir}
END FUNCTION
```

#### Idempotent Config Application

Each `git config` command is idempotent:
```bash
git -C .forge config commit.gpgsign false
# If already false: no change, command succeeds silently
# If true or unset: changed to false, command succeeds silently
# If unsupported option: command fails with error (trapped and logged)
```

**Defensive Config Settings Explained:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `commit.gpgsign` | `false` | Disable GPG signing on commits (prevents passphrase prompts) |
| `core.hooksPath` | `/dev/null` | Disable all hooks (pre-commit, post-commit, etc.) |
| `tag.gpgsign` | `false` | Disable GPG signing on tags |
| `user.name` | `forge` | Forge's own identity (not user's) |
| `user.email` | `forge@local` | Forge's own email domain (not user's) |
| `core.ignorecase` | `false` | Case-sensitive filenames (consistent across OS) |

**Why Each is Necessary:**

- **No GPG signing:** Forge commits must never prompt for passphrases. User's global config may require signing.
- **No hooks:** Pre/post-commit hooks can execute arbitrary side effects. Forge should not run them.
- **Forge identity:** Forge commits should not leak user identity. Use forge@local to signal internal operations.
- **Case sensitivity:** Ensures artifact paths are consistent across macOS (case-insensitive) and Linux (case-sensitive).

#### Error Handling for Initialization

```
TRY initialize_forge_git(project_root):

CATCH permission_denied:
    LOG: "Permission denied creating .forge/ or .git/ directories"
    LOG: "Check that project root is writable"
    OFFER_USER: ["Retry", "Use different project root", "Abort"]

CATCH git_not_found:
    LOG: "git CLI not found or not accessible"
    OFFER_USER: ["Install git", "Update PATH", "Abort"]

CATCH git_command_failed:
    LOG: "git init or config command failed: {error}"
    LOG: "This may indicate git is misconfigured globally"
    OFFER_USER: ["Retry", "Try --global git config reset", "Abort"]
```

---

## Component 2: Phase Artifact Commits

### Requirement: commit_phase_artifacts(forge_dir, phase_number, phase_description)

After orchestrator completes a phase, all artifacts are committed to forge git. Commits must be atomic and handle GPG signing timeouts.

#### Algorithm

```
FUNCTION commit_phase_artifacts(forge_dir, phase_number, phase_description):
    // Step 1: Stage all changes in .forge/
    RUN("git -C " + forge_dir + " add -A")

    // Step 2: Check if there are changes to commit
    status_output = RUN("git -C " + forge_dir + " status --porcelain")
    IF status_output is empty:
        LOG: "No changes to commit for phase " + phase_number
        RETURN {sha: null, success: true, reason: "no_changes"}

    // Step 3: Prepare commit message
    message = "forge: phase " + phase_number + " — " + phase_description

    // Step 4: Attempt commit with timeout (prevents GPG hang)
    TRY:
        RUN("git -C " + forge_dir + " commit -m '" + message + "'",
            timeout: 5_seconds)
    CATCH timeout_exceeded:
        LOG: "git commit timed out (5s); suspected GPG signing prompt"
        LOG: "Retrying with --no-gpg-sign flag"
        RUN("git -C " + forge_dir + " commit -m '" + message + "' --no-gpg-sign")

    // Step 5: Get commit SHA for state.json
    sha = RUN("git -C " + forge_dir + " rev-parse --short HEAD")

    // Step 6: Log commit operation
    APPEND_LINE(forge_dir + "/operations.jsonl", {
        ts: ISO8601_NOW(),
        op: "git_commit",
        phase: phase_number,
        sha: sha,
        message: message
    })

    RETURN {sha: sha, success: true}
END FUNCTION
```

#### Commit Message Format

```
forge: phase {N} — {description}

Example:
  forge: phase 1 — requirement analysis complete
  forge: phase 3 — design review (round 1, PASS)
  forge: phase 8 — code implementation + quality gate passed
```

#### Error Handling for Commits

```
TRY commit_phase_artifacts(...):

CATCH timeout_and_retry_fails:
    LOG: "git commit failed even with --no-gpg-sign"
    LOG: "This indicates a more serious git configuration issue"
    OFFER_USER: [
        "Try again" (max 3 total attempts),
        "Skip commit (phase complete, but not recorded in git)",
        "Check git config manually and retry",
        "Abort phase"
    ]

CATCH git_index_locked:
    LOG: "git index is locked (another git process running?)"
    SLEEP(1_second)
    RETRY: 3 times with exponential backoff

CATCH git_commit_failed:
    LOG: "git commit failed: {exit_code}, {stderr}"
    OFFER_USER: ["Retry", "Abort"]
```

---

## Component 3: Rollback Operations (Atomic Transaction)

### Requirement: rollback_to_phase(forge_dir, feature_dir, target_phase_sha)

Atomically roll back to a prior phase commit. This involves:
1. Acquiring a file lock (prevent concurrent modifications)
2. Marking all downstream phases as invalidated in state.json
3. Atomically writing new state.json (temp file + rename)
4. Executing git checkout to restore artifacts
5. Logging operation

Rollback must be transactional: if any step fails, state.json is restored to preserve consistency.

#### Algorithm

```
FUNCTION rollback_to_phase(forge_dir, feature_dir, target_phase_sha):
    state_file = forge_dir + "/state.json"
    lock_file = state_file + ".lock"
    operations_file = forge_dir + "/operations.jsonl"

    // Step 1: Acquire lock (with timeout)
    LOCK(lock_file, timeout: 30_seconds)

    IF lock_acquire_failed:
        RETURN {success: false, reason: "state.json locked; try again later"}

    // Step 2: Read current state (backup for rollback on error)
    TRY:
        current_state = READ_JSON(state_file)
        original_state = DEEP_COPY(current_state)
    CATCH json_parse_error:
        RELEASE_LOCK(lock_file)
        RETURN {success: false, reason: "state.json corrupted"}

    // Step 3: Find target phase number from git SHA
    TRY:
        target_phase = find_phase_by_sha(current_state, target_phase_sha)
    CATCH phase_not_found:
        RELEASE_LOCK(lock_file)
        RETURN {success: false, reason: "target phase SHA not found in state.json"}

    // Step 4: Mark all downstream phases as invalidated
    FOR phase_num FROM (target_phase + 1) TO 12:
        IF phase_num IN current_state.features[0].phases:
            current_state.features[0].phases[phase_num].status = "invalidated"
            current_state.features[0].phases[phase_num].completed = null
            current_state.features[0].phases[phase_num].artifacts = []
            current_state.features[0].phases[phase_num].decisions = []

    // Step 5: Atomic write state.json (temp + rename)
    temp_file = state_file + ".tmp." + random_hex(8)

    TRY:
        WRITE_JSON(temp_file, current_state)
        ATOMIC_RENAME(temp_file, state_file)  // Atomic on POSIX filesystems
    CATCH write_failed:
        RELEASE_LOCK(lock_file)
        DELETE(temp_file)  // Cleanup temp file
        RETURN {success: false, reason: "state.json write failed"}

    // Step 6: Execute git checkout to restore artifacts to target phase
    TRY:
        RUN("git -C " + forge_dir + " checkout " + target_phase_sha + " -- " + feature_dir,
            timeout: 10_seconds)
    CATCH git_checkout_failed:
        // Git checkout failed; restore state.json to original (rollback the rollback)
        LOG: "git checkout failed; restoring state.json to previous state"
        WRITE_JSON(state_file, original_state)
        RELEASE_LOCK(lock_file)
        RETURN {
            success: false,
            reason: "git checkout failed; state.json restored to previous state",
            error: git_checkout_output
        }

    // Step 7: Append operation log
    APPEND_LINE(operations_file, {
        ts: ISO8601_NOW(),
        op: "phase_rollback",
        target_phase: target_phase,
        target_phase_sha: target_phase_sha,
        invalidated_phases: [target_phase + 1, ..., 12],
        status: "completed"
    })

    // Step 8: Release lock
    RELEASE_LOCK(lock_file)

    RETURN {
        success: true,
        rolled_back_to_phase: target_phase,
        invalidated_phases: [target_phase + 1, ..., 12]
    }
END FUNCTION
```

#### Atomic Semantics Explanation

**Why temp file + rename (not direct write)?**

On POSIX filesystems (Linux, macOS), `mv` (rename) is atomic if source and destination are on the same filesystem. This guarantees:
- If process crashes mid-write, old state.json remains intact (not corrupted)
- No concurrent reader sees partial JSON

**Alternative: Write to same file + fsync**

Some systems may not support atomic rename. Alternative strategy:
```
1. Write directly to state.json
2. Call fsync() to flush to disk
3. Verify file is readable + valid JSON (paranoid check)
4. If verification fails, offer user recovery
```

**Lock Semantics:**

```
lock_file = state.json.lock
LOCK strategy:
  1. Try to create lock_file with PID + timestamp
  2. If already exists:
     - Read PID from lock_file
     - If PID is running: wait 100ms, retry (max 30 attempts)
     - If PID is not running: assume stale lock, overwrite
  3. On success: proceed with state.json update
  4. On exit (success or error): delete lock_file
```

**Why lock?**

Prevents race condition where two task agents (or orchestrator + user) try to update state.json simultaneously:
- Without lock: last writer wins, earlier changes lost
- With lock: one writer at a time, all changes preserved

---

## Component 4: Error Recovery Strategies

### Defensive Error Handling

#### Git Command Failures

```
// If any git command fails unexpectedly:

ON git_command_error:
    1. Log full command: {cmd}
    2. Log exit code: {exit_code}
    3. Log stderr: {stderr}
    4. Log stderr/stdout for operator diagnosis

    OFFER_USER:
       - "Try again" (max 3 total attempts with exponential backoff)
       - "Skip phase" (mark phase as failed, move to next)
       - "Rollback to previous phase" (start over)
       - "Check git config" (display current config, offer to reset)
       - "Abort" (stop operation)

    NOT_PERMITTED:
       - Never proceed with unknown git state
       - Never silently skip errors
       - Always require explicit user confirmation
```

#### State.json Write Failures

```
// If state.json write fails during update:

ON state_write_error:
    1. Verify the error type:
       - ENOSPC (disk full)
       - EACCES (permission denied)
       - EINVAL (invalid path)
       - Other I/O error

    2. Log error: {errno}, {message}

    3. Attempt recovery:
       - If ENOSPC: "Disk full. Free space and retry?"
       - If EACCES: "Permission denied. Check .forge/ directory ownership"
       - If EINVAL: "Invalid path or filesystem issue"
       - For other errors: "Attempt automatic recovery from git commit"

    4. OFFER_USER:
       - "Retry write" (after fixing underlying issue)
       - "Restore from last git commit" (git -C .forge show HEAD:state.json > state.json)
       - "Abort" (stop operation, state.json unchanged)

    NOT_PERMITTED:
       - Never proceed without state.json successfully written
       - Never assume state.json is valid if write failed
```

#### Lock Acquisition Timeout

```
// If lock acquisition times out:

ON lock_timeout:
    1. Log: "state.json.lock acquired by other process (PID: X, age: Y seconds)"

    2. If age < 5 minutes:
       OFFER_USER: ["Wait and retry", "Force unlock and retry", "Abort"]

    3. If age >= 5 minutes:
       LOG: "Stale lock (age > 5 min); assuming previous process crashed"
       Automatically overwrite lock and proceed

    4. Prevent deadlock:
       - Max lock wait: 30 seconds
       - If exceeded: escalate to user
```

---

## Component 5: Audit Trail

### Operations Log Format (operations.jsonl)

Every git operation is recorded in append-only JSON Lines format. One JSON object per line. Never delete or reorder lines.

#### Git Operations

```jsonl
# Git initialization
{"ts":"2026-04-10T10:00:00Z","op":"git_init","message":"Initialized .forge/.git with defensive config"}

# Phase commits
{"ts":"2026-04-10T10:30:00Z","op":"git_commit","phase":1,"sha":"abc123def456","message":"forge: phase 1 — requirement analysis complete"}
{"ts":"2026-04-10T11:15:00Z","op":"git_commit","phase":2,"sha":"def456ghi789","message":"forge: phase 2 — design creation complete"}

# Rollback operations
{"ts":"2026-04-10T12:00:00Z","op":"phase_rollback","target_phase":2,"target_phase_sha":"def456ghi789","invalidated_phases":[3,4,5,6,7,8,9,10,11,12],"status":"completed"}

# Git errors (for debugging)
{"ts":"2026-04-10T12:05:00Z","op":"git_error","command":"git -C .forge commit -m 'test'","exit_code":128,"stderr":"error: pathspec 'features/' did not match any files","recovery":"Ignored (no changes to commit)"}
```

#### Operation Fields

| Field | Type | Purpose | Example |
|-------|------|---------|---------|
| `ts` | ISO 8601 | Timestamp | `2026-04-10T10:00:00Z` |
| `op` | string | Operation type | `git_init`, `git_commit`, `phase_rollback` |
| `phase` | number | Phase number (if applicable) | `1`, `2`, ..., `12` |
| `sha` | string | Git short SHA | `abc123def456` |
| `message` | string | Commit message or operation description | `"forge: phase 1 — requirement analysis complete"` |
| `target_phase` | number | Target phase for rollback | `2` |
| `invalidated_phases` | array | Phases marked invalid by rollback | `[3, 4, 5, ...]` |
| `status` | string | Completion status | `"completed"`, `"failed"` |
| `stderr` | string | Git error output (if error) | Full stderr from git command |
| `recovery` | string | Action taken on error | `"Retried with --no-gpg-sign"` |

#### Query Examples

```bash
# Find all commits for phase 3
grep '"phase":3' .forge/operations.jsonl

# Count successful phase commits
grep '"op":"git_commit"' .forge/operations.jsonl | wc -l

# Find all rollback operations
grep '"op":"phase_rollback"' .forge/operations.jsonl

# Check for git errors
grep '"op":"git_error"' .forge/operations.jsonl

# Timeline of all operations (with timestamps)
jq '.ts + " | " + .op + " | " + .message' .forge/operations.jsonl
```

---

## Component 6: Configuration Verification

### Check Current Git Config

Diagnostic command to verify forge git is properly hardened:

```
FUNCTION verify_forge_git_hardened(forge_dir):
    config_checks = [
        {key: "commit.gpgsign", expected: "false"},
        {key: "core.hooksPath", expected: "/dev/null"},
        {key: "tag.gpgsign", expected: "false"},
        {key: "user.name", expected: "forge"},
        {key: "user.email", expected: "forge@local"},
        {key: "core.ignorecase", expected: "false"}
    ]

    all_ok = true

    FOR check IN config_checks:
        actual = RUN("git -C " + forge_dir + " config " + check.key)
        IF actual != check.expected:
            LOG: "MISMATCH: " + check.key + " = " + actual + " (expected: " + check.expected + ")"
            all_ok = false
        ELSE:
            LOG: "OK: " + check.key + " = " + actual

    RETURN {all_ok: all_ok}
END FUNCTION
```

### Reset to Defensive Config

If git config is corrupted, re-apply defensive settings:

```
FUNCTION reset_forge_git_config(forge_dir):
    LOG: "Resetting .forge/ git config to defensive defaults"

    // Re-run initialization (idempotent)
    CALL initialize_forge_git(project_root)

    // Verify
    result = verify_forge_git_hardened(forge_dir)

    IF result.all_ok:
        LOG: "Config reset successful"
        RETURN {success: true}
    ELSE:
        LOG: "Config reset incomplete; manual intervention required"
        RETURN {success: false, reason: "config still mismatched"}
END FUNCTION
```

---

## Integration with Orchestrator

### Orchestrator Calls

The main orchestrator (skills/forge/SKILL.md) calls git hardening functions at these points:

1. **Initialization:** `initialize_forge_git(project_root)` when `.forge/` doesn't exist
2. **Phase completion:** `commit_phase_artifacts(forge_dir, phase_num, description)` after each phase
3. **Rollback:** `rollback_to_phase(forge_dir, feature_dir, target_phase_sha)` when user requests rollback
4. **Verification:** `verify_forge_git_hardened(forge_dir)` periodically (optional diagnostic)
5. **Recovery:** `reset_forge_git_config(forge_dir)` if config corruption is detected

### State.json Integration

Git hardening operations update state.json:
- `.latest_commit.sha` — Updated after each commit
- `.latest_commit.message` — Updated after each commit
- `.latest_commit.timestamp` — Updated after each commit
- `.phases[N].completed` — Set when phase is committed

### Example Execution Flow

```
1. User: /forge
2. Orchestrator: initialize_forge_git(project_root)
   └─ Defensive config set, initial commit

3. Task agent: Execute phase 1
4. Orchestrator: commit_phase_artifacts(.forge, 1, "requirement analysis complete")
   └─ git add -A
   └─ git commit -m "forge: phase 1 — requirement analysis complete"
   └─ state.json.phases[1].completed = now
   └─ operations.jsonl: append git_commit record

5. User: (Changes design due to review feedback)
6. Orchestrator: cascade_detect() → phases 4,6,8 affected
7. Orchestrator: rollback_to_phase(.forge, feature_dir, phase_2_sha)
   └─ Lock state.json
   └─ Mark phases 3-12 as invalidated
   └─ Atomic write state.json
   └─ git checkout phase_2_sha -- features/auth-middleware/
   └─ Unlock state.json
   └─ operations.jsonl: append phase_rollback record
```

---

## Edge Cases & Safety

### Case 1: Concurrent Write Attempts

**Scenario:** Two task agents try to update state.json simultaneously

**Prevention:** File lock (`.forge/state.json.lock`) serializes access

**Recovery:** If lock times out, user must intervene (likely indicates hung task agent)

### Case 2: Git Hangs on Commit

**Scenario:** `git commit` hangs waiting for GPG passphrase

**Prevention:** 5-second timeout on commit command

**Recovery:** Retry with `--no-gpg-sign` flag (defensive config should prevent this, but recovery is available)

### Case 3: Disk Full During state.json Write

**Scenario:** `WRITE_JSON(temp_file, ...)` fails due to ENOSPC

**Prevention:** Check disk space before writing (if possible)

**Recovery:** Prompt user to free space, retry write

### Case 4: .forge/.git Corrupted

**Scenario:** Git object store corrupted (user manually edited .git/, or disk error)

**Prevention:** None (external corruption)

**Recovery:**
1. Detect via `git fsck`
2. Offer: backup `.forge/.git` to `.forge/.git.backup`, reinitialize from state.json
3. Offer: manual recovery or escalate to user

### Case 5: Old Forge Repo (Pre-Hardening)

**Scenario:** User runs forge on old project that predates defensive config

**Prevention:** None (pre-existing repo)

**Recovery:** Initialize orchestrator runs `initialize_forge_git()` which re-applies defensive config (idempotent)

---

## Summary: Git Hardening Guarantees

| Guarantee | Mechanism |
|-----------|-----------|
| No GPG hangs | Set `commit.gpgsign=false`, timeout + `--no-gpg-sign` retry |
| No hook side effects | Set `core.hooksPath=/dev/null` |
| No credential prompts | Global credential config not inherited |
| Forge identity isolated | Set `user.name=forge`, `user.email=forge@local` |
| State consistency | Atomic writes (temp + rename), lock-based concurrency control |
| Audit trail | operations.jsonl append-only log |
| Error recovery | Full rollback on git checkout failure, state.json always restored |
| Idempotent init | Can re-run multiple times safely |
| Performance | Commits complete in <5 seconds (with timeout) |

---

## Implementation Checklist

- [ ] `initialize_forge_git()` — Create .forge/, .git/, apply defensive config
- [ ] `commit_phase_artifacts()` — Commit with timeout + GPG retry
- [ ] `rollback_to_phase()` — Atomic transaction with lock, temp file, rename, checkout
- [ ] `verify_forge_git_hardened()` — Diagnostic check
- [ ] `reset_forge_git_config()` — Recovery procedure
- [ ] operations.jsonl — Append-only audit trail for all git operations
- [ ] Error handling — All edge cases with user offers
- [ ] Orchestrator integration — Calls at right phases
- [ ] State.json integration — Updates latest_commit fields

---

**Created:** 2026-04-10
**Status:** Specification Complete
**Reviewer:** Phase 8 Implementation — Unit 3
