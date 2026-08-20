# Forge × Superpowers — Augment Plan

Goal: keep forge spine (state.json, cascade, operations.jsonl, autopilot, per-repo FORGE-CONFIG, artifact tree). Graft superpowers execution-quality discipline into forge phases. Forge loses nothing; gains TDD enforcement, per-task subagent quality, debugging, design gate rigor, worktree isolation.

Strategy: **vendor superpowers techniques, do not depend on the repo.** Copy patterns into forge skills (proprietary, self-contained). No runtime dependency on obra/superpowers. Pin a reference commit for provenance.

---

## Mapping table — which SP skill → which forge phase

| SP source | Forge target | Action | Priority |
|---|---|---|---|
| `test-driven-development` (Iron Law, RED-GREEN, verify-fail) + `testing-anti-patterns` | forge-implement (P8), forge-implement-tests (P10), forge-test-planning (P6) | Embed RED-GREEN enforcement + anti-pattern checklist | **P0** |
| `subagent-driven-development` implementer-prompt (per-task subagent, ask-first, model-tier, self-review, BLOCKED/NEEDS_CONTEXT escalation) | forge-implement (P8) + task-agent-prompt-template.md | Replace flat qc-readonly dispatch w/ per-unit implementer + task-reviewer loop | **P0** |
| `systematic-debugging` (4-phase, root-cause-first, multi-component instrumentation) | NEW skill `forge-debug` | Import wholesale; wire as escalation target on gate/test failure | **P1** |
| `brainstorming` HARD-GATE (no code until design approved) + 2-3 approach compare | forge-design-creation (P2), forge-requirement-analysis (P1) | Add HARD-GATE marker; P2 already has DD research — strengthen approval gate | **P1** |
| `using-git-worktrees` | forge orchestrator (feature start) | Wrap feature init in optional worktree for isolation | **P2** |
| `finishing-a-development-branch` (verify tests → env detect → merge/PR/cleanup) | NEW phase-12.5 or forge-documentation (P12) tail | Add structured branch-completion after docs | **P2** |
| `verification-before-completion` | forge-review (all gates) | Cross-check forge verification-protocol.md vs SP; merge missing checks | **P2** |
| `writing-skills` meta | forge skill maintenance (dev-only) | Use when authoring/editing forge skills | **P3** |

---

## P0 — TDD enforcement (highest leverage, your tests are planned but not RED-GREEN-enforced)

### Edit: `skills/forge-implement/SKILL.md`
Current §4 "Implement Each Unit" runs build+lint only, tests deferred to P10. Problem: code written before test = SP Iron Law violation, and forge bakes test-after as the default.

Add to §4, per unit:
- If unit has corresponding test case in TEST-PLAN.md → enforce RED first:
  1. Write failing test (from TEST-PLAN case).
  2. Run focused test, **capture failure output** as proof (work_count>0).
  3. Implement minimal code.
  4. Run focused test → green.
  5. Record `tdd_evidence: {red_output_sha, green_output_sha}` in `.phase-8-output.json`.
- Add Anti-Pattern: "Do NOT write production code before its failing test (TDD Iron Law). If code precedes test, delete and restart from test."

Note: this partially merges P10 into P8 per-unit. Keep P10 for integration/coverage-gap tests. Document the split.

### Edit: `skills/forge-test-planning/SKILL.md`
Add testing-anti-patterns checklist to TEST-PLAN.md template:
- No test that asserts nothing.
- No test of mock behavior instead of real code (SP `<Bad>` example).
- One behavior per test, clear name, real code over mocks unless unavoidable.

### Edit: `skills/forge/references/task-agent-prompt-template.md`
Inject TDD clause into implement-phase prompt block.

---

## P0 — Per-unit implementer subagent (upgrade dispatch quality)

### Edit: `skills/forge-implement/SKILL.md` §"Parallelism Notes" + autopilot
Current: tier units dispatched to qc-readonly with pseudocode+config+source. Upgrade each unit dispatch to SP implementer-prompt contract:
- **Ask-first:** subagent raises requirement/approach/dependency questions before coding.
- **Explicit model tier** (SP Model Selection): mechanical unit → cheap/fast model; integration/judgment → standard; never inherit session default silently. Add `model` field per unit in IMPL-PLAN tiers.
- **Self-review** before report.
- **Escalation states:** BLOCKED / NEEDS_CONTEXT / DONE_WITH_CONCERNS → forge maps to existing "blocked unit" handling + escalation.

### Edit: `skills/forge-autopilot/SKILL.md` §"Fix Cycles"
After each unit, dispatch a **task-reviewer** subagent (SP per-task review) on the unit diff — spec compliance + quality — before marking unit done. Critical/Important findings → fix subagent. This is finer-grained than forge's current phase-9-only review gate. Keep phase-9 as broad whole-feature review.

---

## P1 — forge-debug (new skill, fills total gap)

Create `skills/forge-debug/SKILL.md` from SP `systematic-debugging`:
- 4 phases: root-cause investigation → hypothesis → minimal fix → verify.
- Iron Law: NO FIXES WITHOUT ROOT CAUSE.
- Multi-component instrumentation (log at each boundary) — directly relevant to Auth0 SDK CI→build→sign chains.
- Copy refs: `root-cause-tracing.md`, `defense-in-depth.md`, `find-polluter.sh`, `condition-based-waiting.md`.
- Wire: forge-implement / autopilot gate failure or repeated test failure → invoke forge-debug instead of blind retry (current forge does max-2 blind fix attempts; replace 2nd attempt with root-cause path).

Add to autopilot escalation: on 1st gate FAIL → forge-debug root-cause; only then fix cycle.

---

## P1 — Design HARD-GATE

### Edit: `skills/forge-design-creation/SKILL.md`
Add explicit HARD-GATE block (SP brainstorming pattern) after §6 DD presentation:
> Do NOT proceed to §7 Create Design / any downstream phase until user approves DD choices. No silent "go with recommendations" unless user explicitly says so.

forge already presents DDs + waits; formalize as gate marker so autopilot pauses correctly. P1 (requirement-analysis) already does Q&A — add same gate.

---

## P2 — Worktree isolation

### Edit: `skills/forge/SKILL.md` Step 1 init
Optional: on feature start, offer `git worktree add` (SP using-git-worktrees) so feature work isolates from main checkout. forge's `.forge/.git` is separate already, but source edits happen in main tree — worktree isolates source too. Make opt-in via FORGE-CONFIG flag.

---

## P2 — Branch completion

### Edit: `skills/forge-documentation/SKILL.md` (P12 tail) OR new step
After docs, run SP finishing-a-development-branch: verify tests pass → detect env (worktree vs repo) → present merge/PR/cleanup options. Closes the loop forge currently leaves open (forge ends at docs, no integration step).

---

## P2 — Verification cross-merge

Compare `skills/forge/references/verification-protocol.md` (Proof-of-Work, work_count>0) against SP `verification-before-completion`. Merge any SP checks forge lacks. Forge's work_count proof is already strong; likely additive only.

---

## What stays forge-only (do NOT replace — your daily value)
- `state.json` machine enum + cross-session resume.
- `operations.jsonl` audit trail.
- Cascade detector (bidirectional dep graph) — SP has nothing.
- Per-repo `FORGE-CONFIG.md` convention auto-detect.
- 12-phase artifact tree + namespacing.
- Stateful autopilot + escalation.

---

## Effort estimate
- P0 (TDD + implementer subagent): edit 3 skills + 1 ref template. ~1 day.
- P1 (forge-debug + design gate): 1 new skill + copy 4 refs + edit 2 skills. ~1 day.
- P2 (worktree, finishing, verification): edit 3 skills. ~0.5 day.
- Total: ~2.5 days. No external runtime dep. All vendored.

## Provenance
Pin reference: obra/superpowers @ <commit-sha-at-vendor-time>. Note in each augmented skill: "TDD/debug/implementer patterns adapted from superpowers (vendored, not a dependency)." License check: superpowers LICENSE before copying ref files verbatim.
