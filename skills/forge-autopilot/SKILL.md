---
name: forge-autopilot
description: Thin ref-holding driver for automated end-to-end forge execution. Drives the Standard 12-phase pipeline or Lite 4-stage lane based on feature.track. Dispatches fresh worker sub-agents per phase, accumulates only refs, and delegates all deterministic ops to the forge exec layer.
license: Proprietary
metadata:
  author: Auth0 SDKs Team <sdks@auth0.com>
---

# Forge Autopilot — Thin Ref-Holding Driver

Autopilot is a **driver**, not an executor. It holds refs, reads track + stage count from `forge slice`, dispatches fresh worker sub-agents one phase at a time, and calls `forge <verb>` for every deterministic op. No pseudocode. No state logic. No reimplemented git or state-CRUD.

## When to Use

- User says "autopilot", "run forge automatically", "forge auto", or similar
- User wants phases executed end-to-end with minimal intervention
- Active feature exists in state (run `/forge` first if not)

## Prerequisites

- `.forge/` workspace initialized (run `/forge` first)
- `.forge/state.json` exists with active feature
- `.forge/FORGE-CONFIG.md` exists

## Exec-Layer Entrypoint

All deterministic ops go through the single dispatcher. Locate relative to this SKILL.md:

```
FORGE_BIN="<skill_dir>/../forge/bin/forge"
# <skill_dir> = directory containing this SKILL.md (resolved once at runtime)
```

Invocation: `$FORGE_BIN <verb> [args...]`

Available verbs: `init` | `status` | `slice` | `merge` | `save` | `mark-complete` | `invalidate-downstream` | `repair` | `ref` | `archive` | `ghost-snapshot` | `ghost-diff` | `commit-phase` | `log-query` | `rollback`

Never read `state.json` directly. Never reimplement state, git, or ref logic.

## Driver Contract (Ref-Bus)

The autopilot driver holds **only refs** — never full phase bodies:

1. Call `forge slice --json` once to read `feature.track`, `max_stage`, `REVIEW_STAGES`, and per-phase status + ref pointers.
2. For each pending/invalidated phase: dispatch a **fresh worker sub-agent**. The worker loads its own phase skill, does its work, writes its output JSON, and returns **only its ref** (locator + carry_forward summary) to the driver.
3. After each phase, driver calls the post-phase sequence (merge → mark-complete → commit-phase → ghost-snapshot → cascade check). It receives small outputs from each verb.
4. **Accumulation rule:** driver context grows by ~1 ref per phase (the returned ref + carry_forward). Phase bodies, artifacts, and bulk state never enter the driver window.

## Track Selection

Call `forge slice --json` before the loop to read `feature.track`:

- `track == "standard"` → drive the 12-phase Standard pipeline (phases 1–12)
- `track == "lite"` → drive the 4-stage Lite pipeline (L1–L4)
- `track` absent (legacy state) → default to `standard`

Autopilot NEVER changes the track and NEVER converts between tracks. Track is set at feature creation by the orchestrator.

---

## Standard Track — 12-Phase Loop Policy

Before the loop, call `forge slice --json` to get current phase statuses and refs. Skip phases with status `approved` or `completed`.

**Per-phase dispatch sequence:**

1. **Anti-phase-jump check** — if any prerequisite phase is not `approved`/`completed`, halt and report the blocker (mirrors orchestrator rule).
2. **Gather refs** — call `forge ref <slug> <prev_phase> --json` for the carry_forward pointer. Pass to worker.
3. **Dispatch worker** — launch a fresh `qc-readonly` sub-agent with: skill name, `forge slice` JSON, ref pointer(s), `feature_dir`, `config_path`, and output path. Worker loads its own SKILL.md and returns only its ref/summary.
4. **Poll** for output file at `.forge/features/<slug>/.phase-<N>-output.json` (~30 min timeout). On timeout: mark phase failed, report, halt.
5. **Post-phase sequence** (call each verb in order):
   ```
   forge merge <slug> <phase> <output-json>
   forge mark-complete <slug> <phase> completed --summary "<carry_forward>"
   forge commit-phase <slug> <phase> completed --log-line "<agent log line>" --carry "<summary>"
   forge ghost-snapshot <slug>
   ```
6. **Cascade check** — if output artifacts non-empty: `forge invalidate-downstream <slug> <phase>`. If phases invalidated, report affected stages.
7. **Review gate** (if phase ∈ REVIEW_STAGES = [3,5,7,9,11]):
   - Read gate from `forge ref <slug> <phase> --print`.
   - `PASS` → call `forge mark-complete <slug> <phase> approved`, continue.
   - `FAIL` + fix_cycle_count < 2 → run fix cycle (see **Fix Cycle** below), increment counter.
   - `FAIL` + fix_cycle_count ≥ 2 → escalate to user with findings, halt.
8. **Approve non-review phase** — `forge mark-complete <slug> <phase> approved`.

After all 12 phases approved: `forge mark-complete <slug> 12 completed` (feature_complete op), output completion message.

---

## Lite Lane Autopilot — 4-Stage Loop Policy

See [forge/SKILL.md § Scope-Adaptive Lite Lane](../forge/SKILL.md) for the canonical stage table.

Before the loop, call `forge slice --json`: `max_stage = 4`, `REVIEW_STAGES = [4]` (L4 gate: `ok-to-merge` | `needs-fix`), `stage_word = "Stage"`.

**Per-stage dispatch sequence:** identical to Standard (steps 1–6 above) with `max_stage = 4` and stage labels L1–L4.

**Lite gate policy:**

- **L3 Test** — read `verify.any_fail` from phase ref. If any check fails:
  - fix_cycles < 2 → reset L2 + L3 (`forge mark-complete <slug> 2 pending`, same for 3), restart loop from L2 with failing-check notes injected into worker prompt. Increment fix_cycles.
  - fix_cycles ≥ 2 → escalate, halt.
- **L4 Review** — gate = `ok-to-merge` | `needs-fix`.
  - `ok-to-merge` → approve all stages, feature complete.
  - `needs-fix` + fix_cycles < 2 → reset L2/L3/L4 to pending, re-dispatch L2 with issue list (caveman-ultra `[file:line] [problem] [fix]`), then L3, then L4. Increment fix_cycles.
  - `needs-fix` + fix_cycles ≥ 2 → escalate, halt.

After L4 `ok-to-merge`: `forge mark-complete <slug> 4 approved` + feature_complete, output "Lite feature complete — ok-to-merge (L1→L4 approved)."

---

## Fix Cycle Policy (Standard Track)

On review gate FAIL (fix_cycle_count < 2):

1. Read CRITICAL/MAJOR findings from `forge ref <slug> <review_phase> --print`.
2. Re-dispatch the **artifact phase** (review_phase − 1) as a fresh worker, injecting the findings as "Fix Cycle Feedback" in the worker prompt.
3. Re-dispatch the **review phase** as a fresh worker.
4. Run post-phase sequence for both (merge → mark-complete → commit-phase → ghost-snapshot).
5. Re-read gate from `forge ref`. If PASS → approve and continue. If FAIL → increment counter; if now ≥ 2, escalate.

---

## Resumability

On re-invocation after interruption:

1. Call `forge slice --json` to read current phase statuses.
2. Skip all phases with status `approved` or `completed`.
3. Resume from first `pending` or `invalidated` phase.
4. If a phase is `in_progress`, restart from its beginning (workers are idempotent).
5. If a phase is `failed`, halt and ask user to retry or fix.

If index seems inconsistent: `forge repair`.

---

## Escalation Conditions

Autopilot halts and reports to user on:

1. **Gate failure after 2 fix cycles** — include phase, findings, artifact path, suggested action.
2. **Task agent timeout** (>30 min) — mark phase failed, show path to output file.
3. **State corruption** — `forge repair`, then offer recovery from last forge git commit.
4. **Cascade invalidation** — report affected phases; nudge `forge cascade-fix`.
5. **User intervention required** — requirements or design decisions need human input.

---

## Phase Specifications (Standard Track)

| Phase | Name | Review? | Gate |
|-------|------|---------|------|
| 1 | Requirement Analysis | — | — |
| 2 | Design Creation | — | — |
| 3 | Design Review | Yes | PASS / FAIL |
| 4 | Implementation Planning | — | — |
| 5 | Impl Plan Review | Yes | PASS / FAIL |
| 6 | Test Planning | — | — |
| 7 | Test Plan Review | Yes | PASS / FAIL |
| 8 | Code Implementation | — | — |
| 9 | Code Review | Yes | PASS / FAIL |
| 10 | Test Implementation | — | — |
| 11 | Test Review | Yes | PASS / FAIL |
| 12 | Documentation | — | — |

REVIEW_STAGES = [3, 5, 7, 9, 11]. Gate rule: `review_findings.gate == "PASS"` (0 CRITICAL, 0 MAJOR).

---

## References

- [forge/SKILL.md](../forge/SKILL.md) — orchestrator, track selection, Lite Lane canonical table, dispatch contract
- [forge/references/state-schema.md](../forge/references/state-schema.md) — state structure and ref envelope spec
- [forge/references/task-agent-prompt-template.md](../forge/references/task-agent-prompt-template.md) — worker prompt construction
- [forge/references/cascade-detector.md](../forge/references/cascade-detector.md) — downstream impact detection
