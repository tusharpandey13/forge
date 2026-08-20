---
name: forge-autopilot
description: Automated multi-phase execution for forge workflow. Drives the Standard 12-phase pipeline or the Lite 4-stage lane based on feature.track. Dispatches to qc-readonly task agents using state.json, with gate evaluation, fix cycles, and optional parallelism for independent phases.
license: Proprietary
metadata:
  author: Auth0 SDKs Team <sdks@auth0.com>
---

# Forge Autopilot (Dispatcher Model)

Automated orchestration that dispatches all 12 phases to qc-readonly task agents using the dispatcher architecture. Manages state.json, evaluates gates, executes fix cycles, and handles escalation on repeated failures.

## When to Use

- User wants to run the complete forge pipeline end-to-end with minimal intervention
- User says "autopilot", "run forge automatically", "forge auto", or similar
- User has an active feature and wants phases executed sequentially or in parallel (where independent)

## Prerequisites

- `.forge/` workspace initialized (run `/forge` first)
- `.forge/state.json` exists with active feature
- `.forge/FORGE-CONFIG.md` exists
- Phase 1 through current phase either completed or approved

## Core Architecture

### Dispatcher Model (aligned with orchestrator)
- Autopilot is a **thin dispatch wrapper** that cycles through phases automatically
- All phases dispatch to **qc-readonly task agents** (not full-context opus/sonnet models)
- Prompts constructed via [task-agent-prompt-template.md](../forge/references/task-agent-prompt-template.md)
- Task agents produce phase output; autopilot reads and validates
- State.json is source of truth (not FORGE-LOGS.md)

### State Management
- Load state.json before each phase dispatch
- Update state.json atomically after phase completion
- Read review_findings from state.json for gate decisions
- Append operation records to .forge/operations.jsonl

### Gate Evaluation
- Review phases (3, 5, 7, 9, 11) produce `review_findings` in state.json
- Gate rule: `review_findings.gate == "PASS"` (0 CRITICAL, 0 MAJOR)
- Failure triggers fix cycle (max 2 per phase)
- After 2 failures → escalate to user

### Fix Cycles
1. Reload state.json to get latest review_findings
2. Dispatch original phase again with review feedback
3. Re-review (dispatch review phase again)
4. Evaluate new gate
5. Repeat up to 2 times; then escalate

### Parallelism (Optional)
- Identify independent phases from IMPL-PLAN.md unit tiers
- Implementation (Phase 8) units can dispatch in parallel if independent
- Test implementation (Phase 10) units can dispatch in parallel if independent
- All other phases sequential (dependencies require sequential execution)
- Autopilot can opt to run sequentially for simplicity or parallel for speed

## Track Awareness

Autopilot reads `feature.track` from state.json and drives the matching pipeline:

- `track == "standard"` → the 12-phase loop below.
- `track == "lite"` → the 4-stage Lite loop (see **Lite Lane Autopilot** below).

Autopilot NEVER changes the track and NEVER converts a lite feature to standard (or vice versa). Track is fixed at feature creation by the orchestrator (`select_track`). If `track` is absent (legacy state), default to `standard`.

```
FUNCTION autopilot_entry(feature):
    track = feature.track OR "standard"
    IF track == "lite":
        RETURN autopilot_run_lite(feature)   // L1 → L4
    ELSE:
        RETURN autopilot_run(feature)         // Phases 1 → 12
END FUNCTION
```

## Workflow — Standard Track (12 Phases)

```
LOOP phases 1 → 12:

  IF phase.status == "pending":
    1. Dispatch to qc-readonly task agent
    2. Poll for completion (.phase-{N}-output.json appears)
    3. Merge output into state.json
    4. Commit phase artifacts

  IF phase is review phase (3, 5, 7, 9, 11):
    5. Check state.json.phases[N].review_findings.gate
    6. IF gate == "FAIL" AND fix_cycle_count < 2:
         a. Dispatch original phase with review feedback
         b. Re-review
         c. Re-check gate
         d. increment fix_cycle_count
    7. IF gate == "FAIL" AND fix_cycle_count >= 2:
         Escalate to user with summary

  IF phase passed or skipped:
    8. Continue to next phase

END LOOP

OUTPUT: Feature complete or escalation message
```

## Phase Specifications

All 12 phases dispatch using the orchestrator's dispatcher model:

| Phase | Name | Type | Input | Output | Review | Gate |
|-------|------|------|-------|--------|--------|------|
| 1 | Requirement Analysis | task_agent | context/* | REQUIREMENTS.md | N/A | N/A |
| 2 | Design Creation | task_agent | REQUIREMENTS.md | DESIGN.md | N/A | N/A |
| 3 | Design Review | task_agent | DESIGN.md + REQUIREMENTS.md | DESIGN-REVIEW-{N}.md | Yes | review_findings |
| 4 | Implementation Planning | task_agent | DESIGN.md | IMPL-PLAN.md | N/A | N/A |
| 5 | Impl Plan Review | task_agent | IMPL-PLAN.md + DESIGN.md | IMPL-PLAN-REVIEW-{N}.md | Yes | review_findings |
| 6 | Test Planning | task_agent | DESIGN.md | TEST-PLAN.md | N/A | N/A |
| 7 | Test Plan Review | task_agent | TEST-PLAN.md + DESIGN.md | TEST-PLAN-REVIEW-{N}.md | Yes | review_findings |
| 8 | Code Implementation | task_agent | IMPL-PLAN.md | source files | N/A | N/A |
| 9 | Code Review | task_agent | code + IMPL-PLAN.md | CODE-REVIEW-{N}.md | Yes | review_findings |
| 10 | Test Implementation | task_agent | TEST-PLAN.md | test files | N/A | N/A |
| 11 | Test Review | task_agent | tests + TEST-PLAN.md | TEST-REVIEW-{N}.md | Yes | review_findings |
| 12 | Documentation | task_agent | all artifacts | docs + context | N/A | N/A |

**References:** All phases use Tier 1 specs from orchestrator (state-schema.md, task-agent-prompt-template.md, cascade-detector.md)

## Autopilot Dispatch Loop (Pseudocode)

```
FUNCTION autopilot_run(feature_id):
    state = load_state()
    feature = find_active_feature(state)

    IF NOT feature:
        OUTPUT: "No active feature. Use /forge to create one."
        RETURN

    // Display initial status
    display_phase_timeline(feature)

    fix_cycle_counters = {}  // phase → count

    FOR phase_num = 1 TO 12:
        IF feature.phases[phase_num].status IN ["approved", "completed"]:
            CONTINUE  // Skip already-completed phases

        IF feature.phases[phase_num].status == "failed":
            OUTPUT: "Phase {{phase_num}} previously failed. Resuming from user action."
            // Wait for user to retry or skip
            RETURN

        // Phase pending or invalidated
        OUTPUT: ">>> Dispatching Phase {{phase_num}}: {{ PHASE_NAMES[phase_num] }}"

        // 1. Dispatch to task agent
        result = dispatch_phase_to_task_agent(state, phase_num)
        IF NOT result.success:
            OUTPUT: "Phase {{phase_num}} dispatch failed (timeout after 30 min)"
            feature.phases[phase_num].status = "failed"
            save_state_atomic(state, {op: "phase_timeout", phase: phase_num})
            RETURN

        // 2. Merge output into state.json
        phase_output = result.output
        merge_phase_output(feature, phase_num, phase_output)
        save_state_atomic(state, {op: "phase_complete", phase: phase_num})

        // 3. Commit phase artifacts
        commit_phase_artifacts(phase_num, "completed")

        // 4. Review gate evaluation (if review phase)
        IF phase_num IN [3, 5, 7, 9, 11]:
            fix_cycle_counters[phase_num] = 0  // Reset counter for this phase

            LOOP fix_cycle_attempts = 1 TO 2:
                IF feature.phases[phase_num].review_findings.gate == "PASS":
                    OUTPUT: "Phase {{phase_num}}: Gate PASS"
                    BREAK

                IF feature.phases[phase_num].review_findings.gate == "FAIL":
                    IF fix_cycle_attempts < 2:
                        OUTPUT: "Phase {{phase_num}}: Gate FAIL — attempting fix cycle {{fix_cycle_attempts}}"

                        // Re-dispatch original phase with review feedback
                        OUTPUT: "  Re-dispatching phase {{phase_num - 1}} with review findings"
                        result = dispatch_phase_fix_cycle(state, phase_num - 1, phase_num)
                        IF NOT result.success:
                            OUTPUT: "Fix cycle dispatch failed"
                            BREAK

                        // Re-dispatch review phase
                        OUTPUT: "  Re-reviewing phase {{phase_num}}"
                        result = dispatch_phase_to_task_agent(state, phase_num)
                        IF NOT result.success:
                            OUTPUT: "Review re-dispatch failed"
                            BREAK

                        // Merge new review findings
                        phase_output = result.output
                        merge_phase_output(feature, phase_num, phase_output)
                        save_state_atomic(state, {op: "phase_fix_cycle", phase: phase_num, cycle: fix_cycle_attempts})
                        commit_phase_artifacts(phase_num, "fix_cycle_{{fix_cycle_attempts}}")
                    ELSE:  // fix_cycle_attempts >= 2
                        OUTPUT: "ESCALATION: Phase {{phase_num}} failed after 2 fix cycles"
                        OUTPUT: "Review artifact: .forge/features/{{feature.id}}/{{PHASE_ARTIFACTS[phase_num]}}"
                        OUTPUT: "Findings: "
                        FOR finding IN phase_output.findings:
                            IF finding.severity IN ["CRITICAL", "MAJOR"]:
                                OUTPUT: "  [{{finding.severity}}] {{finding.text}}"

                        feature.phases[phase_num].status = "failed"
                        save_state_atomic(state, {op: "escalation", phase: phase_num})
                        RETURN

        // 5. Mark phase as approved (for non-review phases)
        IF phase_num NOT IN [3, 5, 7, 9, 11]:
            feature.phases[phase_num].status = "approved"
            save_state_atomic(state, {op: "phase_approve", phase: phase_num})
            commit_phase_artifacts(phase_num, "approved")

        // 6. Cascade detection (optional; orchestrator owns this)
        IF phase_output.artifacts NOT empty:
            OUTPUT: "  Cascade detection: checking for downstream impact"
            affected = detect_affected_phases(phase_output.artifacts[0].path, feature)
            IF affected.downstream NOT empty:
                OUTPUT: "  Affected phases: {{ affected.downstream }}"
                FOR affected_phase IN affected.downstream:
                    feature.phases[affected_phase].status = "invalidated"
                save_state_atomic(state, {op: "cascade_invalidate", phase: phase_num, affected: affected.downstream})

    // All phases completed
    OUTPUT: "Feature complete! All 12 phases approved."
    feature.status = "completed"
    save_state_atomic(state, {op: "feature_complete", feature_id: feature.id})
    commit_phase_artifacts(12, "feature_complete")
    RETURN
END FUNCTION
```

## Lite Lane Autopilot (4 Stages)

For `track == "lite"`, autopilot runs the raven-style pipeline: **L1 Plan → L2 Build → L3 Test → L4 Review**. Same dispatcher model, state atomicity, git commit, and escalation semantics as Standard — only the stage set and gate differ.

### Lite Stage Table

| Stage | Name | Input | Output | Gate |
|-------|------|-------|--------|------|
| L1 | Plan | context/*, FORGE-CONFIG.md | `lite/STORY.md` | N/A |
| L2 | Build | STORY.md, named source files | source diffs + `lite/BUILD-NOTES.md` | N/A |
| L3 | Test | STORY.md, touched files | `lite/VERIFY.md` (check table) | all checks PASS |
| L4 | Review | diffs, STORY.md, VERIFY.md, FORGE-CONFIG.md | `lite/LITE-REVIEW.md` | `ok-to-merge` |

Artifacts under `.forge/features/<slug>/lite/`. Internal artifacts (STORY.md, BUILD-NOTES.md, VERIFY.md, LITE-REVIEW.md) are caveman-ultra; product code/diffs are normal.

### Lite Dispatch Loop (Pseudocode)

```
FUNCTION autopilot_run_lite(feature):
    state = load_state()
    display_lite_timeline(feature)   // shows L1..L4, not 1..12

    fix_cycles = 0
    LITE_STAGES = [1, 2, 3, 4]   // L1..L4

    FOR stage_num IN LITE_STAGES:
        IF feature.phases[stage_num].status IN ["approved", "completed"]:
            CONTINUE
        IF feature.phases[stage_num].status == "failed":
            OUTPUT: "Lite stage L{{stage_num}} previously failed. Awaiting user action."
            RETURN

        OUTPUT: ">>> Dispatching L{{stage_num}}: {{ LITE_STAGE_NAMES[stage_num] }}"
        result = dispatch_phase_to_task_agent(state, stage_num)   // uses lite skill + caveman constraints
        IF NOT result.success:
            feature.phases[stage_num].status = "failed"
            save_state_atomic(state, {op: "phase_timeout", phase: stage_num})
            OUTPUT: "L{{stage_num}} dispatch failed (timeout)"
            RETURN

        phase_output = result.output
        merge_phase_output(feature, stage_num, phase_output)
        save_state_atomic(state, {op: "phase_complete", phase: stage_num})
        commit_phase_artifacts(stage_num, "completed")

        // L3 Test gate: every check must PASS
        IF stage_num == 3:
            IF phase_output.verify.any_fail:
                OUTPUT: "L3 Test: FAIL — check(s) failed. Looping back to L2 Build."
                IF fix_cycles < 2:
                    fix_cycles += 1
                    reset_stage(feature, 2)   // re-run Build with failing-check notes
                    reset_stage(feature, 3)
                    save_state_atomic(state, {op: "lite_fix_cycle", phase: 3, cycle: fix_cycles})
                    RESTART FOR at stage_num = 2
                ELSE:
                    OUTPUT: "ESCALATION: L3 failing after 2 fix cycles"
                    feature.phases[3].status = "failed"
                    save_state_atomic(state, {op: "escalation", phase: 3})
                    RETURN

        // L4 Review gate: ok-to-merge | needs-fix
        IF stage_num == 4:
            gate = phase_output.review_findings.gate   // "ok-to-merge" | "needs-fix"
            IF gate == "needs-fix":
                IF fix_cycles < 2:
                    fix_cycles += 1
                    OUTPUT: "L4 Review: needs-fix — looping L4 → L2 with issue list"
                    // issue list: caveman-ultra [file:line] [problem] [fix]
                    dispatch_lite_fix(state, phase_output.review_findings.issues)
                    reset_stage(feature, 2)
                    reset_stage(feature, 3)
                    reset_stage(feature, 4)
                    save_state_atomic(state, {op: "lite_fix_cycle", phase: 4, cycle: fix_cycles})
                    RESTART FOR at stage_num = 2
                ELSE:
                    OUTPUT: "ESCALATION: L4 needs-fix after 2 fix cycles"
                    feature.phases[4].status = "failed"
                    save_state_atomic(state, {op: "escalation", phase: 4})
                    RETURN
            ELSE:  // ok-to-merge
                OUTPUT: "L4 Review: ok-to-merge"

        IF stage_num != 4 AND stage_num != 3:
            feature.phases[stage_num].status = "approved"
            save_state_atomic(state, {op: "phase_approve", phase: stage_num})
            commit_phase_artifacts(stage_num, "approved")

    // All lite stages done
    feature.phases[4].status = "approved"
    feature.status = "completed"
    save_state_atomic(state, {op: "feature_complete", feature_id: feature.id})
    commit_phase_artifacts(4, "feature_complete")
    OUTPUT: "Lite feature complete — ok-to-merge (L1→L4 approved)."
    RETURN
END FUNCTION
```

**Lite fix cycle:** on L4 `needs-fix`, re-dispatch L2 Build with the review issue list (caveman-ultra `[file:line] [problem] [fix]`), then re-run L3 and L4. Max 2 cycles, then escalate — identical budget to Standard.

## Fix Cycle Dispatch

```
FUNCTION dispatch_phase_fix_cycle(state, artifact_phase, review_phase):
    // artifact_phase: the phase that produced the artifact being reviewed (e.g., 2 for Design)
    // review_phase: the review phase (e.g., 3 for Design Review)

    // 1. Get review findings from state
    review_findings = state.phases[review_phase].review_findings

    // 2. Construct fix prompt with review feedback
    prompt = construct_agent_prompt(
        feature_name: state.features[0].name,
        phase_number: artifact_phase,
        phase_name: PHASE_NAMES[artifact_phase],
        feature_dir: state.features[0].root_dir,
        config_path: ".forge/FORGE-CONFIG.md",
        input_artifacts: prior_artifacts(artifact_phase),
        output_path: compute_output_path(artifact_phase),
        instructions: extract_phase_instructions(artifact_phase),
        quality_gate: PHASE_QUALITY_GATES[artifact_phase]
    )

    // 3. Append fix cycle instruction
    prompt += "\n\n## Fix Cycle Feedback\n\n"
    prompt += "The previous review produced these findings:\n\n"
    FOR finding IN review_findings.findings:
        IF finding.severity IN ["CRITICAL", "MAJOR"]:
            prompt += "- [{{finding.severity}}] {{finding.text}}\n"
    prompt += "\nResolve all CRITICAL and MAJOR findings in your updated artifact.\n"

    // 4. Dispatch and wait
    result = dispatch_task_agent_async(qc_readonly, prompt)
    phase_output = poll_for_completion(result.task_id, timeout: 30_min)

    RETURN phase_output
END FUNCTION
```

## State Operations

Autopilot delegates state management to orchestrator but records operations:

```
FUNCTION save_state_atomic(state, operation_record):
    // 1. Write temp file
    temp_path = ".forge/state.json.tmp." + random_hex(8)
    write_json(temp_path, state)

    // 2. Atomic rename
    atomic_rename(temp_path, ".forge/state.json")

    // 3. Append operation
    operation = {
        ts: ISO8601_NOW(),
        op: operation_record.op,
        phase: operation_record.phase,
        message: operation_record.message or ""
    }
    append_jsonl(".forge/operations.jsonl", operation)

    RETURN success
END FUNCTION
```

## Resumability

If autopilot is interrupted:

1. Run `/forge` or autopilot again
2. Autopilot reads state.json, including `feature.track`
3. Resumes the matching pipeline (Standard 1→12 or Lite L1→L4)
4. Skips all stages with status="approved" or "completed"
5. Resumes from first pending or invalidated stage
6. If a stage is "in_progress", restart from beginning (task agents are idempotent)
7. If a stage is "failed", halt and ask user to retry or fix

## Escalation Conditions

Autopilot escalates to user (halts) if:

1. **Gate failure after 2 fix cycles** — design/plan/code quality issues cannot be resolved
2. **Task agent timeout** — phase execution > 30 minutes
3. **State corruption** — state.json unreadable or invalid
4. **Cascade invalidation** — upstream artifact changes invalidate multiple downstream phases
5. **User intervention required** — requirements need clarification, design decisions need approval

Escalation message includes:
- Phase number and name
- Specific finding or error
- Artifact path for review
- Suggested next action

## Integration Points

**Orchestrator functions reused:**
- `dispatch_phase_to_task_agent()` — from orchestrator (Step 3: Dispatch or Nudge)
- `detect_affected_phases()` — cascade detector
- `save_state_atomic()` — state manager
- `commit_phase_artifacts()` — git operations
- Task agent prompt template from [task-agent-prompt-template.md](../forge/references/task-agent-prompt-template.md)

**References:**
- [state-schema.md](../forge/references/state-schema.md) — state.json structure and operations
- [cascade-detector.md](../forge/references/cascade-detector.md) — downstream impact detection
- [task-agent-prompt-template.md](../forge/references/task-agent-prompt-template.md) — prompt construction for all phases
- [FORGE-CONFIG.md](.forge/FORGE-CONFIG.md) — project conventions (read by task agents)

## Execution Strategy

**Sequential (default):**
- Phases 1-12 execute in order
- Each phase waits for completion before starting next
- Simple, predictable, no parallel complexity

**Parallel (optional, phases 8 & 10):**
- Read IMPL-PLAN.md unit tiers for phase 8 dependencies
- Read TEST-PLAN.md suite tiers for phase 10 dependencies
- Dispatch independent units/suites in parallel
- Wait for all to complete before proceeding to next phase
- Requires orchestrator support for parallel task agent dispatch

## User Interaction Minimized

Autopilot requires user input **only for:**
1. **Escalations** — respond to gate failures or clarifications needed
2. **Resume decisions** — if interrupted, choose to resume or restart

All other phase transitions are automatic.

---

**Status:** Rewritten for dispatcher architecture
**Version:** 2.0 (Dispatcher Model)
**Created:** 2026-04-10
**References:** Orchestrator (SKILL.md), State Schema, Task Agent Prompt Template
