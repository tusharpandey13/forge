---
name: forge-autopilot
description: Automated multi-agent orchestration for the full forge workflow. Use when you want to run the complete forge pipeline with minimal human interaction.
---

# Forge Autopilot

Orchestrates the complete forge workflow using subagents. Runs design, review, planning, implementation, and documentation phases automatically with gate-based progression.

## When to Use

- User wants to run the full forge pipeline end-to-end
- User says "autopilot", "run forge automatically", or "forge auto"
- User wants minimal interaction during the workflow

## Prerequisites

- `.forge/FORGE-CONFIG.md` must exist (run `/forge` first to initialize)
- `forge/context/` must contain at least one context file
- User has reviewed and approved the config

## Core Principles

### P1: Artifact-Based Handoff
- Subagents write output to files (forge/, .forge/)
- Next subagent reads only the files it needs
- Orchestrator tracks phase status and file paths — never reads full artifact content
- Exception: orchestrator reads review output to decide pass/fail

### P2: Minimal Context Per Agent
- Each subagent gets a focused prompt:
  1. Task description (what to produce)
  2. Input file paths (what to read)
  3. Output file path (where to write)
  4. FORGE-CONFIG.md path (conventions to follow)
  5. Template/format reference
- Target: <30% of context window per agent

### P3: Phase Gates
- Each review phase produces PROBLEMS/RECOMMENDATIONS
- Gate rule: 0 CRITICAL, 0 MAJOR → pass
- Fail → fix cycle: same agent resumes with review feedback (max 2 iterations)
- After 2 failed fix cycles → escalate to user

### P4: Parallelism
- Design/Plan + Review: always sequential (review needs the artifact)
- Implementation units within a tier: parallel if independent (auto-decided from IMPL-PLAN.md)
- Test suites: parallel if independent
- State updates: sequential (FORGE-LOGS.md must be consistent)

### P5: Escalation
- Fix cycle exceeds 2 iterations → HALT, surface to user with summary
- Agent exceeds 60% context usage → split into sub-tasks
- Review produces >5 CRITICAL issues → likely design flaw, escalate to user
- Implementation hits a major deviation → escalate to user

## Workflow

```
Phase 1:  REQUIREMENT ANALYSIS  → forge/requirement/REQUIREMENTS.md
Phase 2:  DESIGN CREATION       → forge/design/DESIGN.md
Phase 3:  DESIGN REVIEW         → forge/design/DESIGN-REVIEW-1.md (gate)
Phase 4:  IMPL PLAN             → forge/plan/IMPL-PLAN.md
Phase 5:  PLAN REVIEW           → forge/plan/IMPL-PLAN-REVIEW-1.md (gate)
Phase 6:  TEST PLAN             → forge/plan/TEST-PLAN.md
Phase 7:  TEST PLAN REVIEW      → forge/plan/TEST-PLAN-REVIEW-1.md (gate)
Phase 8:  IMPLEMENT CODE        → source code changes (gate: quality)
Phase 9:  CODE REVIEW           → forge/review/CODE-REVIEW-1.md (gate)
Phase 10: IMPLEMENT TESTS       → test code changes (gate: quality)
Phase 11: TEST REVIEW           → forge/review/TEST-REVIEW-1.md (gate)
Phase 12: DOCUMENTATION         → docs + context file
```

## Agent Dispatch

### Requirement Agent
- **Model:** opus
- **Input:** forge/context/*.md, FORGE-CONFIG.md, codebase structure
- **Output:** forge/requirement/REQUIREMENTS.md
- **Skill:** forge-requirement-analysis

### Design Agent
- **Model:** opus (design requires deep reasoning)
- **Input:** REQUIREMENTS.md, codebase architecture, FORGE-CONFIG.md
- **Output:** DESIGN.md + design-artifact-*.md
- **Skill:** forge-design-creation
- **Note:** Design agent spawns research subagents for design decisions

### Review Agent
- **Model:** opus (review requires deep analysis)
- **Input:** artifact being reviewed + upstream artifacts
- **Output:** {ARTIFACT}-REVIEW-{N}.md
- **Skill:** forge-review

### Plan Agent
- **Model:** opus
- **Input:** DESIGN.md, REQUIREMENTS.md, codebase, FORGE-CONFIG.md
- **Output:** IMPL-PLAN.md
- **Skill:** forge-implementation-planning

### Test Plan Agent
- **Model:** opus
- **Input:** IMPL-PLAN.md, DESIGN.md, existing tests, FORGE-CONFIG.md
- **Output:** TEST-PLAN.md
- **Skill:** forge-test-planning

### Implementation Agent
- **Model:** opus (first pass), sonnet (fix cycles)
- **Input:** IMPL-PLAN.md, source files, FORGE-CONFIG.md
- **Output:** modified source files
- **Skill:** forge-implement
- **Note:** May spawn parallel subagents for independent units

### Test Implementation Agent
- **Model:** opus (first pass), sonnet (fix cycles)
- **Input:** TEST-PLAN.md, source files, existing tests, FORGE-CONFIG.md
- **Output:** test files
- **Skill:** forge-implement-tests

### Documentation Agent
- **Model:** sonnet (documentation is straightforward)
- **Input:** all artifacts, source files, FORGE-CONFIG.md
- **Output:** docstrings, CONTEXT.md, README updates
- **Skill:** forge-documentation

## Gate Evaluation

After each review phase, the orchestrator:

1. Read the review artifact
2. Count CRITICAL and MAJOR findings
3. Decision:
   ```
   0 CRITICAL + 0 MAJOR → PASS → proceed to next phase
   Any CRITICAL or MAJOR → FAIL → enter fix cycle
   ```

### Fix Cycle

1. Resume the original agent (designer, planner, implementer) with:
   - Path to the review file
   - Instruction: "Fix all CRITICAL and MAJOR findings"
2. After fixes → re-review (dispatch review agent again)
3. New review artifact: `{ARTIFACT}-REVIEW-{N+1}.md`
4. Re-evaluate gate
5. Max 2 fix cycles per phase. After that → escalate to user:
   ```
   FORGE :: ESCALATION
     Phase [N] failed gate after 2 fix cycles
     Review: forge/design/DESIGN-REVIEW-3.md
     Remaining issues:
     - [CRITICAL] ...
     - [MAJOR] ...
     Action required: User must resolve or adjust scope
   ```

## Context Budget

| Agent | Est. Input | Est. Output | Budget |
|-------|-----------|-------------|--------|
| Requirements | ~30k tokens | ~10k | 20% |
| Design | ~50k tokens | ~15k | 33% |
| Review | ~30k tokens | ~5k | 18% |
| Plan | ~40k tokens | ~10k | 25% |
| Test Plan | ~40k tokens | ~10k | 25% |
| Implement | ~30k tokens/unit | ~10k/unit | 20% |
| Tests | ~30k tokens/suite | ~10k/suite | 20% |
| Docs | ~20k tokens | ~5k | 13% |

If an agent exceeds 60% → split task into smaller sub-tasks.

## Checkpoint Strategy

Forge git commits after each phase:

- Phase 1 complete: `forge: requirements — [feature summary]`
- Phase 2 approved: `forge: design — [approach summary]`
- Phase 4 approved: `forge: plan — [unit count] implementation units`
- Phase 6 approved: `forge: test plan — [suite count] test suites`
- Phase 8 complete: `forge: implement — [unit summary]`
- Phase 10 complete: `forge: tests — [coverage]% coverage`
- Phase 12 complete: `forge: docs — feature complete`

Each gate pass triggers a commit. SHAs recorded in FORGE-LOGS.md.

## User Interaction Points

Even in autopilot mode, the orchestrator pauses for user input at:

1. **Config initialization** — user confirms conventions and custom instructions
2. **Requirement clarification** — if the requirement agent has questions
3. **Design decisions** — low-confidence DDs presented for user choice
4. **Escalations** — failed gates, major deviations, context overflow
5. **Final review** — before marking feature complete

All other transitions are automatic.

## Resumability

If autopilot is interrupted (context limit, error, user pause):
1. FORGE-LOGS.md has full state
2. Restart autopilot → reads logs → resumes from last completed phase
3. In-progress phases restart from the beginning of that phase (artifacts are idempotent)
