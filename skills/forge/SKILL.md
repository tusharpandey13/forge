---
name: forge
description: Dispatcher-based orchestrator for forge development workflow. Manages state, dispatches phases to task agents, tracks progress, and handles cascade detection. Use when starting features, checking status, or progressing through phases.
---

# Forge — Orchestrator (Dispatcher Architecture)

Main orchestrator skill implementing the dispatcher-based workflow. Manages state.json, dispatches phases to qc-readonly task agents, displays status dashboards, and coordinates cascade detection.

## Key Design Principles

1. **State as Source of Truth:** `.forge/state.json` (machine-readable) + `.forge/operations.jsonl` (append-only audit trail)
2. **Dispatcher Model:** Non-interactive phases run as background task agents; orchestrator displays status
3. **Hardened Git:** Defensive initialization isolates from user config (no GPG, no hooks)
4. **Feature Namespacing:** All artifacts under `.forge/features/<feature-slug>/`
5. **Mandatory Status Display:** First output always shows phase timeline and current status (NFR-4)
6. **Cascade Detection:** After artifact changes, invalidate downstream phases (FR-6)

**References:**
- See [state-schema.md](./state-schema.md) for complete state.json structure
- See [cascade-detector.md](./cascade-detector.md) for dependency graph and invalidation logic
- See [git-hardening.md](./git-hardening.md) for defensive git operations
- See [forge-logs-generator.md](./forge-logs-generator.md) for FORGE-LOGS.md generation
- See [task-agent-prompt-template.md](./task-agent-prompt-template.md) for prompt construction

## When to Use

- User types `/forge` or says "forge"
- User is starting a new feature
- User asks about workflow phases or status
- User needs to progress to next phase
- User wants to check phase timeline or review findings

## On Trigger: Main Orchestrator Flow

### Step 0: Git Guard (Every Invocation)

**On EVERY `/forge` trigger (including after init):**

Apply defensive git config to prevent GPG hangs and enforce safe git settings. This runs regardless of phase status and is idempotent.

```
IF .forge/.git exists:
    git -C .forge config commit.gpgsign false
    git -C .forge config core.hooksPath /dev/null
    git -C .forge config tag.gpgsign false
    git -C .forge config user.name "forge"
    git -C .forge config user.email "forge@local"
```

**Rationale:** Git config can revert to system defaults or user config over time. Running this guard on every invocation ensures the forge git repository stays hardened against GPG prompts and external hooks that could hang the orchestrator.

**Performance:** ~100ms total (5 config operations, no I/O beyond git metadata)

### Step 1: Check Workspace Initialization

**If `.forge/` directory NOT found:**

1. Create directory structure:
   - `mkdir -p .forge/features/`
   - `mkdir -p .forge/context/`

2. Initialize git (DEFENSIVE — FR-1):
   - `git init .forge`
   - Apply defensive config:
     ```bash
     git -C .forge config commit.gpgsign false
     git -C .forge config core.hooksPath /dev/null
     git -C .forge config tag.gpgsign false
     git -C .forge config user.name 'forge'
     git -C .forge config user.email 'forge@local'
     ```
   - Create `.forge/.git/info/exclude`:
     ```
     # Forge internal
     .DS_Store
     *.tmp
     *.swp
     *.lock
     .phase-*-output.json
     .phase-*-error.json
     ```

3. Create initial `.forge/state.json` (version 1.0):
   ```json
   {
     "version": "1.0",
     "repository": {
       "root": "/absolute/project/root",
       "created": "ISO8601-now",
       "git_initialized": true
     },
     "features": [],
     "latest_commit": null
   }
   ```

4. Create initial `.forge/operations.jsonl` (empty)

5. Run config initialization flow (see **Config Initialization** below)
   - If `.forge/FORGE-CONFIG.md` missing, detect codebase conventions and create it

6. Generate initial FORGE-LOGS.md via [forge-logs-generator.md](./forge-logs-generator.md)

7. Commit:
   ```bash
   git -C .forge add -A
   git -C .forge commit -m "forge: init workspace"
   ```

8. Output:
   ```
   FORGE :: INIT
     Workspace created
     Config: .forge/FORGE-CONFIG.md
     Artifacts: .forge/features/

     Next: Create a new feature or drop context into .forge/features/<slug>/context/
   ```

**If `.forge/` found:**
1. Load `.forge/state.json` (strict JSON parsing)
2. If missing → reinitialize (idempotent)
3. If corrupted → offer rollback to last git commit
4. Proceed to Step 2

### Step 2: Load State & Display Status (MANDATORY FIRST OUTPUT)

```
state = read_json(.forge/state.json)
active_feature = find_active_feature(state)

IF active_feature NOT found:
    OUTPUT:
    ```
    FORGE :: NO ACTIVE FEATURE
      Status: Workspace initialized but no features yet
      Next: Create a new feature
    ```
    RETURN

IF active_feature found:
    current_phase = find_current_phase(active_feature)

    OUTPUT:
    ```
    FORGE :: {{ active_feature.name }}
      Phase: {{ current_phase.number }} of 12 — {{ current_phase.name }} ({{ current_phase.status }})
      Started: {{ format_date(active_feature.created) }}
      Current: {{ phase_status_description(current_phase) }}
      Next: {{ next_action(current_phase) }}

      Phase Timeline:
    ```

    FOR phase_num = 1 TO 12:
        phase = active_feature.phases[phase_num]
        icon = status_icon(phase.status)
        OUTPUT: "  Phase {{ phase_num }}:  {{ phase.name | pad(25) }}  [{{ icon }}  {{ phase.status }}]"

    OUTPUT: ""
    OUTPUT: "Artifacts: {{ count(active_feature.artifacts) }} (committed)"
    OUTPUT: "Latest commit: {{ state.latest_commit.sha }} — {{ state.latest_commit.message }}"
```

**Phase Timeline Status Icons:**
- `✓` = approved
- `✓` = completed
- `⏳` = in_progress
- `⊘` = pending
- `✗` = failed
- `↻` = invalidated

### Step 3: Dispatch or Nudge

After mandatory status display, determine next action based on current phase status:

```
SWITCH current_phase.status:
    CASE "pending":
        IF current_phase.number == 1:
            OUTPUT: "Next: Start requirement analysis"
            OUTPUT: "  Use: /require-analysis (or similar)"
        ELSE:
            OUTPUT: "Next: Complete phase {{ current_phase.number - 1 }} first"

    CASE "in_progress":
        OUTPUT: "Phase in progress..."
        CALL poll_for_completion(current_phase)

    CASE "completed":
        IF current_phase.number IN [3, 5, 7, 9, 11]:  // Review phase
            OUTPUT: "Phase {{ current_phase.number }} completed (review artifact produced)"
            OUTPUT: "Review findings: "
            IF review_findings NOT NULL:
                OUTPUT: "  Gate: {{ review_findings.gate }}"
                OUTPUT: "  Critical: {{ review_findings.critical }}, Major: {{ review_findings.major }}"
            OUTPUT: "Next: Review findings and approve or iterate"
        ELSE:
            OUTPUT: "Phase {{ current_phase.number }} completed"
            OUTPUT: "Next: Proceed to next phase"

    CASE "approved":
        next_phase = current_phase.number + 1
        IF next_phase <= 12:
            OUTPUT: "Phase {{ current_phase.number }} approved"
            OUTPUT: "Next: Start phase {{ next_phase }} — {{ phase_names[next_phase] }}"

            IF next_phase IN [3, 5, 7, 9, 11]:
                OUTPUT: "Tip: Review phases can run in this conversation or separately"
        ELSE:
            OUTPUT: "Feature complete! All 12 phases approved."

    CASE "failed":
        OUTPUT: "Phase {{ current_phase.number }} FAILED"
        IF review_findings NOT NULL:
            OUTPUT: "Review findings: "
            OUTPUT: "  Critical: {{ review_findings.critical }}, Major: {{ review_findings.major }}"
        OUTPUT: "Next: Fix issues and retry, or request help"

    CASE "invalidated":
        OUTPUT: "Phase {{ current_phase.number }} invalidated due to upstream change"
        OUTPUT: "Next: Re-run this phase or use 'forge cascade-fix' to re-execute all invalidated"
END SWITCH
```

### Step 4: Config Initialization (if needed)

Called once when `.forge/FORGE-CONFIG.md` doesn't exist. Fully specified in "## Config Initialization" section (see below).

```
FUNCTION config_initialization_flow():
    // See full spec in the "## Config Initialization" section
    RETURN create_forge_config_md()
END FUNCTION
```

## Phase Dispatch Pseudocode

When orchestrator needs to dispatch a phase to a task agent:

```
FUNCTION dispatch_phase(feature_state, phase_number):
    // 1. Check prerequisites
    IF phase_number > 1:
        prior_phase = feature_state.phases[phase_number - 1]
        IF prior_phase.status NOT IN ["approved", "completed"]:
            OUTPUT: "Cannot start phase {{ phase_number }}: phase {{ phase_number - 1 }} not complete"
            RETURN

    // 2. Resolve skill file and read full content (E2: Skill Content Inlining)
    skill_name = PHASE_SKILLS[phase_number]
    skill_file_path = resolve_path("skills/" + skill_name + "/SKILL.md")

    IF NOT file_exists(skill_file_path):
        OUTPUT: "ERROR: Skill file not found: " + skill_file_path
        RETURN {success: false, reason: "skill_not_found"}

    skill_content = READ_FILE(skill_file_path)  // Read entire file verbatim
    instructions_md = skill_content  // Embed full SKILL.md content (not reference or summary)

    // 3. Construct task agent prompt with absolute paths
    prompt = construct_agent_prompt(
        feature_name: feature_state.name,
        phase_number: phase_number,
        phase_name: PHASE_NAMES[phase_number],
        feature_dir: feature_state.root_dir,  // absolute path
        config_path: ".forge/FORGE-CONFIG.md",  // absolute path
        input_artifacts: resolve_input_artifacts(feature_state, phase_number),
        output_path: compute_output_path(feature_state, phase_number),
        instructions_md: instructions_md,  // Full skill content embedded
        quality_gate: PHASE_QUALITY_GATES[phase_number]
    )
    // See [task-agent-prompt-template.md](./task-agent-prompt-template.md) for full template

    // 4. Mark phase as in_progress
    feature_state.phases[phase_number].status = "in_progress"
    feature_state.phases[phase_number].started = ISO8601_NOW()

    // 5. Dispatch to qc-readonly task agent
    // Orchestrator yields control; task agent executes asynchronously
    DISPATCH_ASYNC(qc_readonly, prompt)

    // 6. Poll for completion
    poll_result = poll_for_completion(feature_state, phase_number)

    IF poll_result.success:
        RETURN {success: true}
    ELSE:
        RETURN {success: false, reason: poll_result.reason}
END FUNCTION
```

## Post-Phase Validation (E3: Enforcement)

Before marking phase complete and merging output into state, orchestrator validates artifacts and output structure. This prevents broken artifacts (symlinks, out-of-boundary files) from corrupting the state.

```
FUNCTION post_phase_validation(phase_number, phase_output):
    // Called after orchestrator reads .phase-N-output.json but BEFORE merge_phase_output()

    // Check 1: No symlinks in feature directory
    symlinks = find_all(".forge/features/", type="symlink")
    IF symlinks not empty:
        OUTPUT: "⚠ Symlinks detected in feature directory. Converting to real files."
        FOR each symlink IN symlinks:
            target = readlink(symlink)
            cp --dereference(target, symlink.tmp)
            rm(symlink)
            mv(symlink.tmp, symlink)
            OUTPUT: "  ✓ Converted: " + symlink

    // Check 2: All artifacts under .forge/features/ (except phases 8, 10, 12 which may have edge cases)
    IF phase_number NOT IN [8, 10, 12]:
        FOR each artifact IN phase_output.artifacts:
            IF NOT artifact.path starts_with(".forge/features/"):
                OUTPUT: "⚠ Artifact outside boundary: " + artifact.path
                correct_path = compute_correct_path(artifact.path, phase_number)
                MOVE(artifact.path, correct_path)
                artifact.path = correct_path
                OUTPUT: "  ✓ Moved to: " + correct_path

    // Check 3: No spurious files created outside .forge/ in project repo
    project_repo_status = git_status(".")  // Parent repo (not .forge/.git)
    unexpected_changes = project_repo_status.untracked_files + project_repo_status.modified_files
    IF unexpected_changes not empty:
        OUTPUT: "⚠ Unexpected changes in project repo:"
        FOR each change IN unexpected_changes:
            OUTPUT: "  - " + change
        OUTPUT: "Recommend: Review and stage/stash before committing."

    RETURN phase_output  // Modified if auto-fixes applied
END FUNCTION
```

### Polling for Phase Completion

Helper function for asynchronous phase monitoring:

```
FUNCTION poll_for_completion(feature_state, phase_number):
    // 1. Set polling parameters
    POLL_INTERVAL = IF phase_number IN [3, 5, 7, 9, 11] THEN 2_seconds ELSE 5_seconds
    MAX_RETRIES = 360  // 360 * 5s = ~30 minutes; 360 * 2s = ~12 minutes for review phases
    attempt = 0

    // 2. Compute expected output file path
    output_file_path = compute_phase_output_path(feature_state, phase_number)
    // Expected: /absolute/path/.forge/features/<slug>/.phase-{N}-output.json

    // 3. Poll loop
    WHILE attempt < MAX_RETRIES:
        attempt = attempt + 1
        SLEEP(POLL_INTERVAL)

        // 4. Check if phase output file exists
        IF file_exists(output_file_path):
            // 5. Read and validate the output file
            result = read_phase_output_file(output_file_path, phase_number)
            IF NOT result.success:
                OUTPUT: "Error reading phase output: {{ result.error }}"
                RETURN {success: false, reason: "corrupted_output"}

            phase_output = result.data

            // 6. Validate outputs (E3: Post-Phase Validation)
            phase_output = post_phase_validation(phase_number, phase_output)

            // 7. Merge task agent output into state
            merge_result = merge_phase_output(feature_state, phase_number, phase_output)
            IF NOT merge_result.success:
                OUTPUT: "Error merging phase output: {{ merge_result.error }}"
                RETURN {success: false, reason: "merge_failed"}

            // 8. Update state.json atomically
            save_result = save_state_atomic(feature_state, {
                op: "phase_complete",
                phase: phase_number,
                status: phase_output.status
            })
            IF NOT save_result.success:
                OUTPUT: "Error saving state: {{ save_result.error }}"
                RETURN {success: false, reason: "state_save_failed"}

            // 9. Generate FORGE-LOGS.md from state
            regenerate_forge_logs(feature_state)

            // 10. Commit to forge git
            commit_result = commit_phase_artifacts(phase_number, phase_output.status)
            IF NOT commit_result.success:
                OUTPUT: "Error committing to forge git: {{ commit_result.error }}"
                RETURN {success: false, reason: "git_commit_failed"}

            // 11. Run cascade detection if artifacts changed
            IF phase_output.artifacts not empty:
                affected = detect_affected(phase_output.artifacts[0].path, feature_state)
                IF affected.downstream not empty:
                    OUTPUT: "Cascade detection: phases {{ affected.downstream }} affected"
                    invalidate_downstream_phases(feature_state, phase_number)

            // 12. Display phase completion summary
            display_phase_completion(phase_number, phase_output)

            RETURN {success: true, phase_output: phase_output}

    // Timeout reached
    OUTPUT: "Phase {{ phase_number }} timed out after {{ MAX_RETRIES * POLL_INTERVAL }}s (no output file detected)"
    RETURN {success: false, reason: "timeout"}
END FUNCTION

FUNCTION read_phase_output_file(output_file_path, expected_phase):
    // 1. Read file
    IF NOT file_exists(output_file_path):
        RETURN {success: false, error: "file not found"}

    raw_json = read_file(output_file_path)

    // 2. Parse JSON
    result = parse_json_safe(raw_json)
    IF NOT result.success:
        RETURN {success: false, error: "invalid JSON: {{ result.error }}"}

    phase_output = result.data

    // 3. Validate structure
    required_fields = ["phase", "status", "artifacts", "execution_details"]
    FOR field IN required_fields:
        IF NOT field IN phase_output:
            RETURN {success: false, error: "missing field: {{ field }}"}

    // 4. Validate phase number matches
    IF phase_output.phase != expected_phase:
        RETURN {success: false, error: "phase mismatch (expected {{ expected_phase }}, got {{ phase_output.phase }})"}

    // 5. Validate status
    valid_statuses = ["completed", "approved", "failed"]
    IF NOT phase_output.status IN valid_statuses:
        RETURN {success: false, error: "invalid status: {{ phase_output.status }}"}

    RETURN {success: true, data: phase_output}
END FUNCTION
```

## Status Display Commands

### `forge status`

Display current phase and timeline (no artifacts).

```
Output:
  FORGE :: [Feature Name]
    Phase: [N] of 12 — [Phase Name] ([status])
    Started: [date]
    Current: [brief status]
    Next: [action]

    Phase Timeline:
      Phase 1  — Requirement Analysis    [✓ approved]
      Phase 2  — Design Creation         [✓ approved]
      Phase 3  — Design Review           [✓ approved]
      Phase 4  — Implementation Planning [⏳ in_progress]
      Phases 5-12 [⊘ pending]

    Artifacts: 4 (committed)
    Latest commit: [SHA] — [message]
```

### `forge report`

Display all review findings aggregated by phase.

```
Output:
  FORGE :: Review Report — [Feature Name]

  Phase 3: Design Review
    Round 1 — PASSED
    - CRITICAL: 0
    - MAJOR: 0
    - MINOR: 2
      - Unused import in AuthMiddleware
      - Missing JSDoc for error handler
    - SUGGESTION: 1

  Aggregate:
    - Critical issues: 0 (PASS)
    - Major issues: 0 (PASS)
    - Minor issues: 2
    - Suggestions: 1
```

### `forge affected <artifact-path>`

Show impact analysis for a changed artifact using cascade detector.

```
Output:
  Changed: .forge/features/auth-middleware/design/DESIGN.md

  Downstream impacts (depends on changed artifact):
    Phase 4: Implementation Planning → INVALIDATED
    Phase 6: Test Planning → INVALIDATED
    Phase 8: Code Implementation → INVALIDATED
    Phase 10: Test Implementation → INVALIDATED

  Upstream impacts (changed artifact depends on these):
    Phase 1: Requirements → marked for re-review

  Suggested action: Run "forge cascade-fix" to re-execute all invalidated phases
```

### `forge cascade-fix`

Automatically re-run all invalidated phases in dependency order.

```
Process:
  1. Find all phases with status="invalidated"
  2. Order by phase number (lowest first; respects dependencies)
  3. For each phase in order:
     - Dispatch to task agent
     - Wait for completion
     - Update state.json
     - Detect cascade for new artifacts
     - Continue to next phase

Output:
  Invalidated phases found: 4
  Re-executing in order: Phase 4, 6, 8, 10

  [Polling...]
  ✓ Phase 4: Implementation Planning [✓ approved]
  ✓ Phase 6: Test Planning [✓ approved]
  ✓ Phase 8: Code Implementation [✓ approved]
  ✓ Phase 10: Test Implementation [✓ approved]

  Cascade fix complete.
```

## Rollback Operation

When user requests rollback (e.g., after review failures):

```
FUNCTION rollback_to_phase(target_phase_number):
    state = load_state()

    // 1. Find target phase SHA in git
    target_commit = find_commit_for_phase(target_phase_number)

    IF target_commit NOT found:
        OUTPUT: "No commit found for phase {{ target_phase_number }}"
        RETURN {success: false}

    // 2. Acquire lock on state.json
    lock_file = ".forge/state.json.lock"
    ACQUIRE_LOCK(lock_file, timeout: 30_seconds)

    // 3. Mark downstream phases as invalidated
    FOR phase_num FROM (target_phase_number + 1) TO 12:
        state.phases[phase_num].status = "invalidated"
        state.phases[phase_num].completed = null
        state.phases[phase_num].artifacts = []

    // 4. Atomic write state.json (temp + rename)
    save_state_atomic(state, {
        op: "phase_rollback",
        target_phase: target_phase_number,
        invalidated_phases: [target_phase_number + 1, ..., 12]
    })

    // 5. Git checkout to restore artifacts
    RUN("git -C .forge checkout {{ target_commit }} -- .forge/features/")

    // 6. Release lock
    RELEASE_LOCK(lock_file)

    // 7. Regenerate FORGE-LOGS.md and commit
    regenerate_forge_logs(state)
    commit_phase_artifacts(target_phase_number, "rollback")

    OUTPUT: "Rolled back to phase {{ target_phase_number }}"
    OUTPUT: "Invalidated phases: {{ invalidated_phases }}"
```

## State Management

All state mutations follow atomic semantics via the StateManager component:

### State Manager Helper Methods

The orchestrator implements the following helper methods (pseudocode):

```
FUNCTION load_state():
    // 1. Check if .forge/state.json exists
    IF NOT file_exists(".forge/state.json"):
        RETURN {success: false, error: "state.json not found"}

    // 2. Read and parse JSON
    raw_json = read_file(".forge/state.json")
    state = parse_json(raw_json)

    // 3. Validate schema (version, features array, phases object)
    IF state.version != "1.0":
        RETURN {success: false, error: "unsupported state version"}

    RETURN {success: true, state: state}
END FUNCTION

FUNCTION save_state_atomic(state, operation_record):
    // 1. Write to temp file
    temp_file = ".forge/state.json.tmp." + random_hex(8)
    write_json(temp_file, state)

    // 2. Atomic rename (POSIX filesystems)
    atomic_rename(temp_file, ".forge/state.json")

    // 3. Append to operations.jsonl (audit trail)
    operation = {
        ts: ISO8601_NOW(),
        op: operation_record.op,
        phase: operation_record.phase,
        ...operation_record
    }
    append_jsonl(".forge/operations.jsonl", operation)

    RETURN {success: true}
END FUNCTION

FUNCTION mark_phase_complete(state, phase_number, phase_output):
    // 1. Update phase status
    state.phases[phase_number].status = phase_output.status  // "completed", "approved", or "failed"
    state.phases[phase_number].completed = ISO8601_NOW()

    // 2. Merge artifacts from .phase-N-output.json
    IF phase_output.artifacts:
        state.phases[phase_number].artifacts = phase_output.artifacts
        FOR artifact IN phase_output.artifacts:
            // Add to global artifacts array (dedup by path)
            IF NOT artifact_exists_in_state(artifact.path):
                state.artifacts.append(artifact)

    // 3. Merge decisions
    IF phase_output.decisions:
        state.phases[phase_number].decisions = phase_output.decisions

    // 4. For review phases, merge review_findings
    IF phase_number IN [3, 5, 7, 9, 11] AND phase_output.review_findings:
        state.phases[phase_number].review_findings = phase_output.review_findings

    // 5. Merge execution_details for telemetry
    IF phase_output.execution_details:
        state.phases[phase_number].execution_details = phase_output.execution_details

    RETURN state
END FUNCTION

FUNCTION merge_phase_output(state, phase_number, phase_output_json):
    // Called after orchestrator reads .phase-N-output.json from task agent
    // 1. Parse the phase output file
    phase_output = parse_json(phase_output_json)

    // 2. Validate structure
    IF phase_output.phase != phase_number:
        RETURN {success: false, error: "phase mismatch"}

    // 3. Update state using mark_phase_complete
    updated_state = mark_phase_complete(state, phase_number, phase_output)

    // 4. Save atomically
    save_state_atomic(updated_state, {
        op: "phase_complete",
        phase: phase_number,
        status: phase_output.status
    })

    // 5. Clean up temp output file
    delete_file(".phase-{{ phase_number }}-output.json")

    RETURN {success: true, state: updated_state}
END FUNCTION

FUNCTION invalidate_downstream_phases(state, changed_phase):
    // Called after cascade detection finds affected phases
    FOR phase_num FROM (changed_phase + 1) TO 12:
        IF state.phases[phase_num].status NOT IN ["pending", "invalidated"]:
            state.phases[phase_num].status = "invalidated"
            state.phases[phase_num].artifacts = []
            state.phases[phase_num].decisions = []

    RETURN state
END FUNCTION
```

## Config Initialization

Detailed flow for `config_initialization_flow()`:

1. **Language detection:**
   - Sample 10+ source files
   - Identify primary language (by file count)
   - Detect framework(s)
   - Identify package manager (package.json, requirements.txt, Cargo.toml, etc.)

2. **Naming conventions:**
   - Sample function/class names across 10+ files
   - Detect pattern (camelCase, snake_case, kebab-case, PascalCase)
   - Compute confidence (>80% = high)

3. **Error handling:**
   - Scan 10+ files for error patterns
   - Detect: try/catch, Result types, custom error classes, error handlers
   - Example: "TypeScript with typed errors extending AppError"

4. **Logging patterns:**
   - Scan 10+ files for log calls
   - Detect: console.log, logger.info, slog, logging library
   - Example: "winston logger with INFO as default"

5. **Test framework:**
   - Check package.json for test scripts
   - Detect: jest, vitest, mocha, pytest, etc.
   - Identify test location (co-located or separate)
   - Detect mocking library: jest.mock, MSW, unittest.mock, etc.

6. **Quality gate commands:**
   - From package.json: `scripts.test`, `scripts.lint`, `scripts.build`
   - From Makefile: test, lint, check targets
   - Example: `pnpm test && pnpm build && pnpm lint`

7. **Write FORGE-CONFIG.md:**
   - Store all detected conventions
   - Include auto-detected confidence levels
   - Prompt user for clarifications on low-confidence items

## Glossary & Phase Names

All 12 phases in order:

| Phase | Name | Execution | Review |
|-------|------|-----------|--------|
| 1 | Requirement Analysis | task_agent | N/A |
| 2 | Design Creation | task_agent | N/A |
| 3 | Design Review | task_agent | Review (findings) |
| 4 | Implementation Planning | task_agent | N/A |
| 5 | Impl Plan Review | task_agent | Review (findings) |
| 6 | Test Planning | task_agent | N/A |
| 7 | Test Plan Review | task_agent | Review (findings) |
| 8 | Code Implementation | task_agent | N/A |
| 9 | Code Review | task_agent | Review (findings) |
| 10 | Test Implementation | task_agent | N/A |
| 11 | Test Review | task_agent | Review (findings) |
| 12 | Documentation | task_agent | N/A |

## Edge Cases & Error Handling

### State.json Corrupted
- Read last commit from git: `git -C .forge show HEAD:state.json > .forge/state.json`
- Offer user: "Recovered from git. Check accuracy and confirm."

### Git Timeout on Commit
- Default timeout: 5 seconds
- If timeout: retry with `--no-gpg-sign` flag
- If still fails: escalate to user

### Lock Acquisition Timeout
- If lock held > 5 minutes: assume stale, overwrite
- If lock held < 5 minutes: wait for release
- Max wait: 30 seconds

### Task Agent Timeout
- If phase takes > 30 minutes: mark as timed out
- Offer user: "Resume, retry, or cancel"

## Integration Points

**Called by orchestrator:**
1. `initialize_workspace()` — First trigger if .forge/ missing
2. `load_state()` — Every trigger
3. `display_status()` — Mandatory first output
4. `dispatch_phase(phase_num)` — When user asks to progress
5. `detect_affected(artifact)` — After artifact changes
6. `mark_invalidated(phases)` — After cascade detection
7. `rollback_to_phase(phase_num)` — On user request

**References (see linked specs):**
- [state-schema.md](./state-schema.md) — state.json structure
- [cascade-detector.md](./cascade-detector.md) — dependency graph and cascade rules
- [git-hardening.md](./git-hardening.md) — defensive git init and rollback
- [forge-logs-generator.md](./forge-logs-generator.md) — FORGE-LOGS.md generation
- [task-agent-prompt-template.md](./task-agent-prompt-template.md) — prompt construction

## Implementation Assumptions

1. **Single Active Feature:** Currently one feature per state.json (architecture supports multi-feature via `.features[]` array)
2. **Absolute Paths:** All paths in state.json and prompts are absolute (no relative resolution)
3. **Idempotent Operations:** All initialization functions can be re-run safely
4. **Atomic Filesystem:** Temp file + rename is atomic on POSIX filesystems (Linux, macOS)
5. **Task Agent Dispatch:** Task agents can be dispatched asynchronously; orchestrator polls for completion
6. **Read-Only Task Agents:** Task agents use `qc-readonly` model (enforced write-only to artifacts)

## Workflow Summary

```
User: /forge

IF .forge/ not exist:
  INIT workspace
  Create state.json, operations.jsonl, git
  Run config detection
  COMMIT initial state

LOAD state.json
DISPLAY status dashboard (MANDATORY)

IF no active feature:
  OUTPUT: "No feature yet"
  RETURN

IF phase pending:
  NUDGE: "Ready to start phase N"

IF phase in_progress:
  POLL for completion

IF phase completed/approved:
  DISPLAY: Review findings (if review phase)
  NUDGE: "Ready for next phase"

IF phase failed:
  DISPLAY: Findings
  NUDGE: "Fix and retry"

IF phase invalidated:
  NUDGE: "Re-run this phase or use forge cascade-fix"
```

---

**Status:** Complete orchestrator rewrite for dispatcher architecture
**Version:** 2.0 (Dispatcher Model)
**Created:** 2026-04-10
