---
name: forge-migrate
description: Migrate existing forge projects from old artifact structure to new state.json model with feature namespacing. Use when running /forge on a project with old forge/ directory.
license: Proprietary
metadata:
  author: Auth0 SDKs Team <sdks@auth0.com>
---

# Forge Migrate

**Purpose:** Convert existing forge projects with flat artifact structure (`forge/design/`, `forge/plan/`, etc.) to the new Forge DX architecture with feature-scoped directories (`.forge/features/<slug>/`) and machine-readable state.json.

**Scope:** Preserves existing work, artifacts, and phase history while enabling adoption of new state management model.

## When to Use

- Running `/forge` on a project with old `forge/` directory (pre-state.json architecture)
- User requests migration: `forge migrate --feature <slug> [--name <name>]`
- Project has existing artifacts in old locations that should be preserved
- User wants to continue work using new Forge architecture

## When NOT to Use

- Project already has `.forge/state.json` (already migrated; use `/forge` normally)
- No old `forge/` directory exists (use `/forge new` to create new feature instead)
- User wants to start fresh without preserving old artifacts (delete old `forge/` and create new)

## Prerequisites

**Existing Project State**
- Old `forge/` directory with artifacts:
  - `forge/requirement/REQUIREMENTS.md` (Phase 1)
  - `forge/design/DESIGN.md`, `forge/design/DESIGN-REVIEW-*.md` (Phases 2-3)
  - `forge/plan/IMPL-PLAN.md`, `forge/plan/IMPL-PLAN-REVIEW-*.md`, `forge/plan/TEST-PLAN.md`, `forge/plan/TEST-PLAN-REVIEW-*.md` (Phases 4-7)
  - `forge/review/CODE-REVIEW-*.md`, `forge/review/TEST-REVIEW-*.md` (Phases 9, 11)
- Old `.forge/FORGE-LOGS.md` (optional; contains phase history and decisions)
- Old `.forge/FORGE-CONFIG.md` (optional; project conventions)
- Old `.forge/.git` repository with commit history (optional)

**User Input Required**
- Feature name (e.g., "Authentication Middleware")
- Feature slug in kebab-case (e.g., "auth-middleware")
- Confirmation to proceed with migration
- Archive strategy for old `forge/` directory

## Algorithm

### Step 1: Pre-Migration Checks

**Check for existing state.json:**
```
IF .forge/state.json exists:
  OUTPUT: "Feature already migrated. Use /forge to continue."
  RETURN
```

**Check for old forge/ directory:**
```
IF forge/ NOT found AND .forge/FORGE-LOGS.md NOT found:
  OUTPUT: "No old artifacts found. Use /forge new to create new feature."
  RETURN
```

**Validate git state:**
```
IF .forge/.git exists:
  - Read git config to detect old commits
  - Check for artifacts in old paths (forge/design/, etc.)
ELSE:
  - Mark as "no git history" (fallback to filesystem analysis)
```

### Step 2: Prompt for Feature Details

**Input Phase:**
```
OUTPUT: "Migrate existing Forge artifacts to new structure"
INPUT: "Feature name (e.g., 'Auth Middleware'): "
  VALIDATE: non-empty, < 100 chars

INPUT: "Feature slug (kebab-case, e.g., 'auth-middleware'): "
  VALIDATE: kebab-case (lowercase letters, numbers, hyphens only)
  VALIDATE: no existing .forge/features/<slug>/ directory

CONFIRM: "Migrate {{ feature_name }} to .forge/features/{{ slug }}/? (y/n): "
```

### Step 3: Extract Metadata from Old FORGE-LOGS.md

**Parse FORGE-LOGS.md (if exists):**
```
READ: .forge/FORGE-LOGS.md (if exists)

EXTRACT: Current Section
  - Current phase number (1-12)
  - Current phase name

EXTRACT: Artifacts Section
  - List of artifact files with paths

EXTRACT: Log Section (per-phase entries)
  FOR each phase entry:
    - Phase number
    - Phase name
    - Status (approved, completed, failed, etc.)
    - Artifacts produced (file paths)
    - Decisions (if documented)
    - Timestamps (if available)
    - Review findings (critical, major, minor counts if applicable)

STORE in temporary metadata structure:
{
  "current_phase": <number>,
  "phases": [
    {
      "number": 1,
      "name": "Requirement Analysis",
      "status": "approved",
      "started": <timestamp or null>,
      "completed": <timestamp or null>,
      "artifacts": [
        { "old_path": "forge/requirement/REQUIREMENTS.md", "file_size": <bytes> }
      ],
      "decisions": [
        "DD-1: Scoped to API layer",
        "DD-2: Deferred UI to v2"
      ],
      "review_findings": null
    },
    {
      "number": 2,
      "name": "Design Creation",
      "status": "approved",
      "started": <timestamp or null>,
      "completed": <timestamp or null>,
      "artifacts": [
        { "old_path": "forge/design/DESIGN.md", "file_size": <bytes> }
      ],
      "decisions": [
        "DD-1: Middleware pattern",
        "DD-2: JWT with RS256"
      ],
      "review_findings": null
    },
    {
      "number": 3,
      "name": "Design Review",
      "status": "approved",
      "started": <timestamp or null>,
      "completed": <timestamp or null>,
      "artifacts": [
        { "old_path": "forge/design/DESIGN-REVIEW-1.md", "file_size": <bytes> }
      ],
      "decisions": [],
      "review_findings": {
        "round": 1,
        "critical": 0,
        "major": 0,
        "minor": 2,
        "suggestion": 1,
        "gate": "PASS"
      }
    }
  ]
}
```

**If FORGE-LOGS.md malformed or missing:**
```
PROMPT user for manual input:
  INPUT: "How many phases have been completed? (0-12): "
  INPUT: "What is the current phase? (1-12): "
  INPUT: "Are artifacts in old forge/ directory? (y/n): "

FALLBACK: Analyze filesystem to infer phase count
  FOR each old artifact path:
    - forge/requirement/REQUIREMENTS.md → Phase 1 completed
    - forge/design/DESIGN.md → Phase 2 completed
    - forge/design/DESIGN-REVIEW-*.md → Phase 3 completed
    - etc.

  DETERMINE: Highest phase with artifacts is "current phase"
  COUNT: Number of completed phases
```

### Step 4: Organize and Copy Artifacts

**Create new directory structure:**
```
mkdir -p .forge/features/{{ slug }}/requirement/
mkdir -p .forge/features/{{ slug }}/design/
mkdir -p .forge/features/{{ slug }}/plan/
mkdir -p .forge/features/{{ slug }}/review/
mkdir -p .forge/features/{{ slug }}/context/
```

**Path mapping (old → new):**
```
MAPPING = {
  "forge/requirement/REQUIREMENTS.md":
    ".forge/features/{{ slug }}/requirement/REQUIREMENTS.md",

  "forge/design/DESIGN.md":
    ".forge/features/{{ slug }}/design/DESIGN.md",
  "forge/design/DESIGN-REVIEW-*.md":
    ".forge/features/{{ slug }}/design/DESIGN-REVIEW-*.md",

  "forge/plan/IMPL-PLAN.md":
    ".forge/features/{{ slug }}/plan/IMPL-PLAN.md",
  "forge/plan/IMPL-PLAN-REVIEW-*.md":
    ".forge/features/{{ slug }}/plan/IMPL-PLAN-REVIEW-*.md",

  "forge/plan/TEST-PLAN.md":
    ".forge/features/{{ slug }}/plan/TEST-PLAN.md",
  "forge/plan/TEST-PLAN-REVIEW-*.md":
    ".forge/features/{{ slug }}/plan/TEST-PLAN-REVIEW-*.md",

  "forge/review/CODE-REVIEW-*.md":
    ".forge/features/{{ slug }}/review/CODE-REVIEW-*.md",
  "forge/review/TEST-REVIEW-*.md":
    ".forge/features/{{ slug }}/review/TEST-REVIEW-*.md"
}

FOR each old_artifact IN metadata.phases[*].artifacts:
  old_path = old_artifact.old_path
  new_path = map(old_path, slug)

  IF file exists at old_path:
    COPY(old_path, new_path)
    OUTPUT: "✓ {{ old_path }} → {{ new_path }}"
  ELSE:
    OUTPUT: "⚠ Missing: {{ old_path }} (phase {{ phase_number }})"
```

**List missing artifacts:**
```
IF any expected artifact missing:
  FOR each missing artifact:
    OUTPUT: "  - {{ artifact_path }} (Phase {{ N }})"

  PROMPT: "Skip missing artifacts or abort? (skip/abort): "
  IF abort: RETURN
```

### Step 5: Generate state.json

**Create feature skeleton:**
```
feature = {
  "id": "{{ slug }}",
  "name": "{{ feature_name }}",
  "status": infer_status(metadata),
    // "pending" if no phases completed
    // "in_progress" if some phases completed
    // "completed" if all phases approved
  "created": extract_timestamp(metadata, "earliest"),
    // Timestamp of first phase completion, or now()
  "is_active": true,
  "root_dir": ".forge/features/{{ slug }}",
  "phases": {},  // Will be populated per phase
  "dependency_graph": {
    "forward": {},  // Will be populated via artifact analysis
    "backward": {}
  },
  "context": {
    "config_path": ".forge/FORGE-CONFIG.md",
    "custom": {
      "migration_source": "forge/",
      "migration_date": now_iso8601(),
      "note": "Migrated from old Forge structure"
    }
  }
}
```

**Populate phases[] from metadata:**
```
FOR each completed_phase IN metadata.phases:
  phase_number = completed_phase.number

  phase = {
    "name": completed_phase.name,
    "status": map_status(completed_phase.status),
      // "approved" if completed_phase.status == "approved"
      // "completed" otherwise
    "started": completed_phase.started OR null,
    "completed": completed_phase.completed OR null,
    "execution": "manual",  // Old phases were manual (not task agents)
    "artifacts": [],  // Will be populated below
    "decisions": completed_phase.decisions OR [],
    "execution_details": null,  // Old phases don't have execution metrics
    "review_findings": completed_phase.review_findings OR null
      // Only for review phases (3, 5, 7, 9, 11)
  }

  // Add artifacts with SHAs
  FOR each artifact IN completed_phase.artifacts:
    artifact_path = new_path(artifact.old_path, slug)
    file_size = os.path.getsize(artifact_path)

    // Get git SHA if .forge/.git exists
    IF .forge/.git exists:
      sha = git_sha_for_file(artifact_path)
        // Run: git -C .forge log --oneline -- {{ artifact_path }} | head -1
        // Extract SHA and truncate to 12 chars
    ELSE:
      sha = file_hash_sha1(artifact_path)[0:12]
        // Fallback: hash file content for deterministic ID

    artifact_obj = {
      "path": artifact_path,
      "phase": phase_number,
      "sha": sha,
      "size_bytes": file_size,
      "created": file_mtime(artifact_path)  // Or completed_phase.completed
    }

    phase.artifacts.push(artifact_obj)

  feature.phases[str(phase_number)] = phase

// Populate pending phases (not yet started)
FOR phase_number IN 1..12:
  IF phase_number NOT IN feature.phases:
    feature.phases[str(phase_number)] = {
      "name": PHASE_NAMES[phase_number],
      "status": "pending",
      "started": null,
      "completed": null,
      "execution": null,
      "artifacts": [],
      "decisions": [],
      "execution_details": null,
      "review_findings": null
    }
```

**Build dependency_graph from artifact references:**
```
// Infer edges by parsing artifact content
dependency_graph = {
  "forward": {},   // A → [B, C] means A is used by B and C
  "backward": {}   // A ← [B] means A depends on B
}

// Establish base rules
base_edges = {
  "phase_1": ["phase_2"],  // REQUIREMENTS → DESIGN
  "phase_2": ["phase_4", "phase_6"],  // DESIGN → PLAN, TEST-PLAN
  "phase_4": ["phase_8", "phase_10"],  // PLAN → CODE, TESTS
  "phase_6": ["phase_10"]  // TEST-PLAN → TESTS
}

FOR each base_rule IN base_edges:
  upstream_phase = base_rule[0]
  downstream_phases = base_rule[1]

  IF feature.phases[upstream_phase].artifacts not empty:
    upstream_artifact = feature.phases[upstream_phase].artifacts[0].path

    FOR each downstream_phase IN downstream_phases:
      IF feature.phases[downstream_phase].artifacts not empty:
        downstream_artifact = feature.phases[downstream_phase].artifacts[0].path

        // Add forward edge
        IF upstream_artifact NOT IN dependency_graph.forward:
          dependency_graph.forward[upstream_artifact] = []
        dependency_graph.forward[upstream_artifact].push(downstream_artifact)

        // Add backward edge
        IF downstream_artifact NOT IN dependency_graph.backward:
          dependency_graph.backward[downstream_artifact] = []
        dependency_graph.backward[downstream_artifact].push(upstream_artifact)

feature.dependency_graph = dependency_graph
```

**Write state.json:**
```
state = {
  "version": "1.0",
  "repository": {
    "root": get_project_root(),  // Absolute path
    "created": feature.created,
    "git_initialized": .forge/.git exists
  },
  "features": [feature],
  "latest_commit": {
    "sha": null,  // Will be set after git commit
    "message": null,
    "timestamp": null
  }
}

WRITE_JSON(".forge/state.json", state)
OUTPUT: "✓ Generated .forge/state.json"
```

### Step 6: Generate operations.jsonl

**Create operation records for completed phases:**
```
operations = []

// For each completed phase, create operation record
FOR each completed_phase IN metadata.phases:
  IF completed_phase.status IN ["approved", "completed"]:
    operation = {
      "ts": completed_phase.completed OR "2000-01-01T00:00:00Z",
        // Use phase completion time, or fallback to epoch if unknown
      "op": "phase_complete",
      "phase": completed_phase.number,
      "feature_id": "{{ slug }}",
      "status": map_status(completed_phase.status),
      "artifact_count": len(completed_phase.artifacts),
      "message": "Migrated from old structure"
    }

    operations.push(operation)

// Sort operations by timestamp (chronological order)
operations.sort_by("ts")

// Add migration marker (final operation)
migration_op = {
  "ts": now_iso8601(),
  "op": "feature_migrate",
  "from": "forge/",
  "to": ".forge/features/{{ slug }}/",
  "artifact_count": total_artifacts_migrated,
  "message": "Completed migration from old Forge structure to state.json model"
}
operations.push(migration_op)

// Append all operations to .forge/operations.jsonl
FOR each operation IN operations:
  APPEND_LINE(".forge/operations.jsonl", JSON(operation))

OUTPUT: "✓ Generated .forge/operations.jsonl with {{ len(operations) }} operations"
```

### Step 7: Initialize and Commit to Forge Git

**Initialize .forge/.git (if not already initialized):**
```
IF .forge/.git NOT exists:
  MKDIR(.forge)
  EXEC: git -C .forge init

  // Defensive config
  EXEC: git -C .forge config commit.gpgsign false
  EXEC: git -C .forge config core.hooksPath /dev/null
  EXEC: git -C .forge config tag.gpgsign false
  EXEC: git -C .forge config user.name "forge"
  EXEC: git -C .forge config user.email "forge@local"

  OUTPUT: "✓ Initialized .forge/.git with defensive config"
```

**Commit migrated state:**
```
EXEC: git -C .forge add -A
EXEC: git -C .forge commit -m "forge: migrate feature '{{ name }}' to state.json model"
  // If commit hangs (GPG), timeout and retry with --no-gpg-sign

IF commit successful:
  EXEC: sha = git -C .forge rev-parse --short HEAD

  // Update state.json with latest_commit
  state = LOAD_JSON(".forge/state.json")
  state.latest_commit = {
    "sha": sha,
    "message": "forge: migrate feature '{{ name }}' to state.json model",
    "timestamp": now_iso8601()
  }
  WRITE_JSON(".forge/state.json", state)

  // Re-commit with updated latest_commit
  EXEC: git -C .forge add state.json
  EXEC: git -C .forge commit -m "forge: update latest_commit after migration"

  OUTPUT: "✓ Committed migration ({{ sha }})"
ELSE:
  OUTPUT: "✗ Git commit failed. Check .forge/.git/ config and retry."
  RETURN (abort)
```

### Step 8: Archive Old Artifacts

**Prompt user for archival strategy:**
```
OUTPUT: "\nWhat to do with old forge/ directory?"
OUTPUT: "  A) Delete (clean, can't undo)"
OUTPUT: "  B) Rename to forge-archived/ (safe, preserves history)"
OUTPUT: "  C) Leave in place (you'll clean up later)"

INPUT: "Choose (A/B/C): "
  VALIDATE: input IN ["A", "B", "C", "a", "b", "c"]

IF choice == "A":
  DELETE: forge/
  OUTPUT: "✓ Deleted old forge/ directory"

IF choice == "B":
  RENAME: forge/ → forge-archived/
  OUTPUT: "✓ Renamed old forge/ → forge-archived/"

IF choice == "C":
  OUTPUT: "✓ Keeping old forge/ (you can delete manually later)"
```

**Update .gitignore:**
```
IF .gitignore NOT exists OR ".forge/" NOT in .gitignore:
  APPEND ".forge/" to .gitignore

  EXEC: git add .gitignore
  EXEC: git commit -m "forge: add .forge/ to .gitignore"

  OUTPUT: "✓ Updated .gitignore to exclude .forge/"
ELSE:
  OUTPUT: "✓ .forge/ already in .gitignore"
```

### Step 9: Output Migration Summary

**Display completion summary:**
```
OUTPUT:
═══════════════════════════════════════════════════════════════
FORGE :: MIGRATION COMPLETE

Feature:       {{ feature_name }} ({{ slug }})
Artifacts:     {{ artifact_count }} migrated
Phases:        {{ completed_phase_count }} completed, {{ pending_phase_count }} pending
Current Phase: {{ current_phase }} ({{ current_phase_name }})

New Structure:
  .forge/features/{{ slug }}/
    ├─ requirement/
    ├─ design/
    ├─ plan/
    ├─ review/
    └─ context/

Git Commits:   {{ commit_count }}
State File:    .forge/state.json
Operations:    .forge/operations.jsonl

Next Steps:
  1. Run `/forge` to load new state and continue
  2. Review migrated artifacts: ls -la .forge/features/{{ slug }}/
  3. (Optional) Delete old forge/ if not already archived

═══════════════════════════════════════════════════════════════
```

## Anti-Patterns (Forbidden)

DO NOT:

1. **Symlinks Instead of Copies**
   - ✗ `ln -s ../../../forge/design/DESIGN.md .forge/features/slug/design/DESIGN.md`
   - ✓ `cp forge/design/DESIGN.md .forge/features/slug/design/DESIGN.md`
   - Reason: Symlinks break isolation, are fragile, and confuse orchestrator

2. **File References Instead of Real Content**
   - ✗ `artifacts.append({path: "../forge/design/DESIGN.md"})`
   - ✓ `artifacts.append({path: ".forge/features/slug/design/DESIGN.md"})` with actual file
   - Reason: Relative paths break when parent directory moves

3. **Partial Copies (missing artifacts)**
   - ✗ Copy only REQUIREMENTS.md, skip DESIGN.md
   - ✓ Copy ALL artifacts for completed phases, or explicitly skip with justification
   - Reason: Incomplete migrations lead to phase gaps and orchestrator confusion

4. **Leaving Old forge/ Artifacts in Place Without Archiving**
   - ✗ Create `.forge/features/slug/` while `forge/` still exists and is referenced
   - ✓ Archive or delete old `forge/` after successful migration
   - Reason: Ambiguity about source of truth; user edits old instead of new

5. **Direct state.json Edits**
   - ✗ Create state.json manually or via script without validation
   - ✓ Generate state.json from extraction logic, validate schema before commit
   - Reason: Malformed state breaks orchestrator

## Error Handling

### Scenario: FORGE-LOGS.md is malformed or missing

**Behavior:**
1. Display warning: "⚠ FORGE-LOGS.md is malformed or missing"
2. Fallback to filesystem analysis:
   - Scan `forge/` directory recursively
   - Count artifacts per phase directory
   - Infer completed phases from artifact presence
3. Prompt user for manual verification:
   - "How many phases have been completed? (0-12): "
   - "What is the current phase? (1-12): "
4. Continue with user-provided metadata

**Example:**
```
⚠ FORGE-LOGS.md is malformed or missing

Analyzing filesystem...
  ✓ forge/requirement/REQUIREMENTS.md (Phase 1)
  ✓ forge/design/DESIGN.md (Phase 2)
  ✓ forge/design/DESIGN-REVIEW-1.md (Phase 3)
  ? forge/plan/IMPL-PLAN.md (not found)

Inferred: 3 phases completed

How many phases have been completed? (0-12): 3
What is the current phase? (1-12): 4
```

### Scenario: Artifacts not found in expected locations

**Behavior:**
1. List missing artifacts
2. Prompt user to move them manually or skip
3. Continue with available artifacts
4. Log discrepancies in operations.jsonl

**Example:**
```
⚠ Missing artifacts:
  - forge/design/DESIGN.md (Phase 2)
  - forge/plan/IMPL-PLAN-REVIEW-1.md (Phase 5)

Options:
  A) Skip and continue (recommended)
  B) Abort and fix manually

Choose (A/B): A

Continuing with Phase 1 only.
```

### Scenario: Git commit fails (e.g., GPG hanging)

**Behavior:**
1. Attempt commit with timeout (5-10 seconds)
2. If timeout, retry with `--no-gpg-sign` flag
3. If still fails, surface error and rollback
4. Offer user to retry or fix git config

**Example:**
```
Committing migration...
  ⏳ git -C .forge commit (timeout: 5s)...
  ✗ Timeout (likely GPG signing issue)

  Retrying with --no-gpg-sign...
  ✓ Committed successfully

✓ Saved state to git (sha: abc123)
```

### Scenario: Old forge/ directory not found

**Behavior:**
1. Check for `.forge/.git` with old commits (fallback indicator)
2. Check for `.forge/FORGE-LOGS.md` (fallback indicator)
3. If neither found, abort with helpful message

**Example:**
```
✗ Migration failed

No old artifacts found:
  - forge/ directory missing
  - .forge/FORGE-LOGS.md missing

Options:
  A) Use `/forge new` to create new feature
  B) Restore old forge/ directory and retry
  C) Check if artifacts are in different location

```

### Scenario: Slug collision (already have `.forge/features/{{ slug }}/`)

**Behavior:**
1. Detect existing feature
2. Prompt user for different slug or merge decision
3. Append timestamp or random suffix if proceeding

**Example:**
```
⚠ Feature slug collision

.forge/features/auth-middleware/ already exists

Options:
  A) Use different slug: {{ slug }}-v2
  B) Merge into existing feature (advanced)
  C) Abort and rename manually

Choose (A/B/C): A

New slug: auth-middleware-v2
```

## Edge Cases

### EC-1: Partial migration (some phases complete, others missing)

**Handling:** Create state.json with only completed phases populated; pending phases remain empty. User can proceed to next phase normally.

```
state = {
  "features": [{
    "phases": {
      "1": { "status": "approved", "artifacts": [...] },
      "2": { "status": "approved", "artifacts": [...] },
      "3": { "status": "pending", "artifacts": [] },  // Not completed
      ...
    }
  }]
}
```

### EC-2: Artifacts with unusual names or paths

**Handling:** Copy artifacts as-is (preserve original naming). If destination path has special characters, sanitize or skip with warning.

```
COPY: forge/design/DESIGN-v2-FINAL-APPROVED.md
  → .forge/features/{{ slug }}/design/DESIGN-v2-FINAL-APPROVED.md

COPY: forge/design/design artifact - cache strategy.md
  → .forge/features/{{ slug }}/design/design artifact - cache strategy.md
```

### EC-3: Very old FORGE-LOGS.md (years old, timestamps missing)

**Handling:** Use filesystem metadata (file modification times) to estimate phase completion times. Timestamps may be inaccurate but are better than null.

```
feature.phases[1].completed = os.path.getmtime(forge/requirement/REQUIREMENTS.md)
// Use file mtime as proxy for phase completion time
```

### EC-4: User edits artifacts during migration

**Handling:** If user modifies old artifacts mid-migration, use state.json "created" timestamp of artifacts (at time of copy), not current mtime.

```
artifact.created = time_of_copy, not current_mtime
// Otherwise state will show "created" as "now" not actual creation date
```

### EC-5: Multiple features in old forge/ (unlikely but possible)

**Handling:** Current implementation assumes single feature. If multiple features detected, prompt user to migrate one at a time.

```
⚠ Multiple potential features detected:
  - REQUIREMENTS.md with "Authentication"
  - REQUIREMENTS.md with "Caching" (different version?)

Migrate as:
  A) Single feature: "{{ project_name }}"
  B) Specify feature names manually

Choose (A/B): A
```

### EC-6: .forge/state.json already exists (partial migration)

**Handling:** Detect at Step 1 and abort (user already migrated). Suggest using `/forge` to continue.

```
✗ Migration aborted

.forge/state.json already exists.

Feature is already migrated. Use `/forge` to continue working.

If you want to migrate a DIFFERENT feature, use:
  forge migrate --feature <new-slug> --name "<new-name>"
```

## Example: Migration Walkthrough

### Before Migration

**Project structure:**
```
project/
├─ forge/
│  ├─ requirement/
│  │  └─ REQUIREMENTS.md (1.2KB)
│  ├─ design/
│  │  ├─ DESIGN.md (3.5KB)
│  │  └─ DESIGN-REVIEW-1.md (0.8KB)
│  ├─ plan/
│  │  └─ IMPL-PLAN.md (2.1KB)
│  └─ review/
│     └─ CODE-REVIEW-1.md (1.0KB)
├─ .forge/
│  ├─ FORGE-LOGS.md (5KB, prose journal)
│  ├─ FORGE-CONFIG.md (2KB, project conventions)
│  └─ .git/ (git history)
├─ src/
└─ package.json
```

**FORGE-LOGS.md excerpt:**
```markdown
# Forge Logs

## Current
Phase 4: Implementation Planning (pending)

## Artifacts
- forge/requirement/REQUIREMENTS.md
- forge/design/DESIGN.md
- forge/design/DESIGN-REVIEW-1.md
- forge/plan/IMPL-PLAN.md

## Timeline
Phase 1: Requirement Analysis — approved (completed 2026-04-08)
Phase 2: Design Creation — approved (completed 2026-04-09)
Phase 3: Design Review — approved (completed 2026-04-09)
...
```

### User Invokes Migration

```
$ forge migrate --feature auth-middleware

FORGE :: Migrate Artifacts to New Structure

Checking for existing state...
  ✓ No state.json found

Detecting old artifacts...
  ✓ forge/ directory found (4 artifacts)
  ✓ FORGE-LOGS.md found

Feature name (e.g., 'Auth Middleware'): Auth Middleware
Feature slug (kebab-case, e.g., 'auth-middleware'): auth-middleware

Parsing FORGE-LOGS.md...
  ✓ Extracted metadata:
    - 3 phases completed
    - Current phase: 4
    - Decisions: 5 documented

Creating new structure...
  ✓ .forge/features/auth-middleware/requirement/
  ✓ .forge/features/auth-middleware/design/
  ✓ .forge/features/auth-middleware/plan/
  ✓ .forge/features/auth-middleware/review/

Copying artifacts...
  ✓ forge/requirement/REQUIREMENTS.md → .forge/features/auth-middleware/requirement/REQUIREMENTS.md
  ✓ forge/design/DESIGN.md → .forge/features/auth-middleware/design/DESIGN.md
  ✓ forge/design/DESIGN-REVIEW-1.md → .forge/features/auth-middleware/design/DESIGN-REVIEW-1.md
  ✓ forge/plan/IMPL-PLAN.md → .forge/features/auth-middleware/plan/IMPL-PLAN.md

Generating state.json...
  ✓ Created feature skeleton
  ✓ Populated 3 phases with artifacts
  ✓ Built dependency graph (3 edges)
  ✓ Wrote .forge/state.json

Generating operations.jsonl...
  ✓ Created 3 phase_complete operations
  ✓ Added feature_migrate marker

Committing to git...
  ✓ Initialized .forge/.git with defensive config
  ✓ Committed migration (sha: d1a2b3c)

Archive old artifacts?
  A) Delete old forge/ (clean)
  B) Rename to forge-archived/ (safe)
  C) Leave in place (manual cleanup)

  Choose (A/B/C): B
  ✓ Renamed old forge/ → forge-archived/

Updating .gitignore...
  ✓ Added .forge/ to .gitignore

═══════════════════════════════════════════════════════════════
FORGE :: MIGRATION COMPLETE

Feature:       Auth Middleware (auth-middleware)
Artifacts:     4 migrated
Phases:        3 completed, 9 pending
Current Phase: 4 (Implementation Planning)

New Structure:
  .forge/features/auth-middleware/
    ├─ requirement/REQUIREMENTS.md
    ├─ design/DESIGN.md, DESIGN-REVIEW-1.md
    ├─ plan/IMPL-PLAN.md
    └─ review/CODE-REVIEW-1.md

Next: Run `/forge` to load state and continue

═══════════════════════════════════════════════════════════════
```

### After Migration

**New project structure:**
```
project/
├─ forge-archived/  (old structure, preserved)
│  ├─ requirement/
│  ├─ design/
│  ├─ plan/
│  └─ review/
├─ .forge/
│  ├─ state.json (machine-readable state)
│  ├─ operations.jsonl (audit log)
│  ├─ FORGE-LOGS.md (generated from state.json)
│  ├─ FORGE-CONFIG.md
│  ├─ features/
│  │  └─ auth-middleware/
│  │     ├─ requirement/REQUIREMENTS.md
│  │     ├─ design/DESIGN.md, DESIGN-REVIEW-1.md
│  │     ├─ plan/IMPL-PLAN.md
│  │     └─ review/CODE-REVIEW-1.md
│  └─ .git/
├─ src/
├─ package.json
└─ .gitignore (now includes .forge/)
```

**state.json structure:**
```json
{
  "version": "1.0",
  "repository": {
    "root": "/absolute/path/to/project",
    "created": "2026-04-08T10:00:00Z",
    "git_initialized": true
  },
  "features": [
    {
      "id": "auth-middleware",
      "name": "Auth Middleware",
      "status": "in_progress",
      "created": "2026-04-08T10:00:00Z",
      "is_active": true,
      "root_dir": ".forge/features/auth-middleware",
      "phases": {
        "1": {
          "name": "Requirement Analysis",
          "status": "approved",
          "completed": "2026-04-08T14:30:00Z",
          "artifacts": [{
            "path": ".forge/features/auth-middleware/requirement/REQUIREMENTS.md",
            "sha": "abc123",
            "size_bytes": 1200
          }],
          "decisions": ["DD-1: API-only scope", "DD-2: Defer UI to v2"]
        },
        ...
      },
      "dependency_graph": { ... },
      "context": {
        "config_path": ".forge/FORGE-CONFIG.md",
        "custom": {
          "migration_source": "forge/",
          "migration_date": "2026-04-10T12:00:00Z"
        }
      }
    }
  ],
  "latest_commit": {
    "sha": "d1a2b3c",
    "message": "forge: migrate feature 'Auth Middleware' to state.json model",
    "timestamp": "2026-04-10T12:00:00Z"
  }
}
```

**User continues with `/forge`:**
```
$ forge

FORGE :: Auth Middleware
  Phase: 4 of 12 — Implementation Planning (pending)
  Started: 2 days ago
  Current: Ready to create implementation plan
  Next: Run phase 4

Phase Timeline:
  Phase 1  — Requirement Analysis    [✓ approved]
  Phase 2  — Design Creation         [✓ approved]
  Phase 3  — Design Review           [✓ approved]
  Phase 4  — Implementation Planning [⊘ pending]
  Phases 5-12 [⊘ pending]

Artifacts: 4 (committed)
Latest commit: d1a2b3c — forge: update latest_commit after migration

Ready to continue. Type `/forge run --phase 4` to start.
```

## Troubleshooting

### "No old artifacts found"

**Cause:** No `forge/` directory or `.forge/FORGE-LOGS.md` detected.

**Solution:**
- Check artifact locations: `ls -la forge/` and `ls -la .forge/`
- If artifacts in different location, move to `forge/` and retry
- If starting fresh, use `forge new` instead

### "FORGE-LOGS.md is malformed"

**Cause:** Corrupted FORGE-LOGS.md file (invalid JSON, malformed headers, etc.).

**Solution:**
- Review FORGE-LOGS.md manually: `cat .forge/FORGE-LOGS.md`
- Provide manual input when prompted (phases completed, current phase)
- Or delete FORGE-LOGS.md and restart migration (will use filesystem analysis)

### "Git commit failed"

**Cause:** Usually GPG signing or hook conflicts in user's global git config.

**Solution:**
- Check git config: `git -C .forge config -l`
- Retry migration (will retry with `--no-gpg-sign`)
- If still fails, check git status: `git -C .forge status`

### "Feature slug collision"

**Cause:** `.forge/features/{{ slug }}/` already exists (possibly from partial migration).

**Solution:**
- Use different slug: `forge migrate --feature {{ slug }}-v2`
- Or delete existing feature: `rm -rf .forge/features/{{ slug }}/`

## See Also

- `/forge` — Main orchestrator (loads state and dispatches phases)
- `.forge/state.json` — Machine-readable state (source of truth)
- `.forge/operations.jsonl` — Append-only audit log
- `/forge/design/DESIGN.md` — Full architecture (Forge DX Overhaul)

---

**Status:** Complete and documented
**Tier:** 2 (depends on state schema)
**Last Updated:** 2026-04-10
