# Forge

A dispatcher-based development workflow system for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Forge decomposes feature development into 12 reviewable phases — from requirements through documentation — with structured state management, background task agents, and cascade-aware change detection.

## Why Forge?

LLM-assisted coding works best with clear boundaries and persistent state. Without structure, context windows bloat, reviews get skipped, decisions go undocumented, and implementation drifts from requirements. Forge solves this by enforcing a phased workflow with:

**Key principles:**

- **Stateful orchestration** — `.forge/state.json` as source of truth; task agents run in background via `qc-readonly`
- **Artifact boundary enforcement** — all forge outputs under `.forge/features/<feature-slug>/` with feature-scoped isolation
- **Hardened git operations** — dedicated `.forge/.git` with defensive config (no GPG, no hooks, no user identity leak)
- **Cascade detection** — bidirectional dependency graph detects when changes invalidate downstream phases
- **Central context hub** — FORGE-LOGS.md auto-generated from state.json; full feature history preserved across sessions
- **Review gates** — phases 3, 5, 7, 9, 11 are reviews; critical/major findings block progression
- **Parallel execution** — independent phases run concurrently; orchestrator merges state updates atomically

## Installation

Copy the `skills/` directory into your Claude Code configuration:

```bash
cp -r skills/* ~/.claude/skills/
```

Claude Code automatically discovers skills in `~/.claude/skills/`. Each subdirectory with a `SKILL.md` file becomes an available skill.

## Getting Started

### 1. Initialize

Run the forge orchestrator in Claude Code:

```
/forge
```

Forge will:
- Create `.forge/` directory for internal state (config, git, state machine)
- Create `.forge/features/` for feature isolation
- Detect your codebase conventions (language, framework, naming patterns, test setup)
- Create `.forge/FORGE-CONFIG.md` with detected conventions
- Initialize `.forge/.git` with defensive config (idempotent, safe to re-run)

### 2. Add context

Place any external context (PRDs, specs, issue descriptions) as markdown files in `.forge/features/<feature-slug>/context/`.

### 3. Run the workflow

Say "analyze requirements" to start Phase 1, or just `/forge` to see current status and next step at any point.

## Workspace Structure

```
project/
├── .forge/                          # Internals (auto-managed, gitignored)
│   ├── .git/                        # Forge internal git repo (defensive config)
│   ├── state.json                   # Machine-readable source of truth
│   ├── operations.jsonl             # Append-only operation audit trail
│   ├── FORGE-CONFIG.md              # Detected conventions + user config
│   ├── FORGE-LOGS.md                # Auto-generated human-readable view
│   └── features/
│       └── <feature-slug>/
│           ├── requirement/REQUIREMENTS.md
│           ├── design/DESIGN.md
│           ├── design/DESIGN-REVIEW-*.md
│           ├── plan/IMPL-PLAN.md, TEST-PLAN.md
│           ├── plan/*-REVIEW-*.md
│           ├── review/CODE-REVIEW-*.md, TEST-REVIEW-*.md
│           └── context/              # User-provided context files
└── src/                             # Your source code (untouched by forge)
```

**New in DX Overhaul:**
- `.forge/state.json` — Machine-readable state: phases, artifacts, decisions, dependency graph, execution metadata
- `.forge/operations.jsonl` — Append-only log of all state mutations (audit trail + rollback recovery)
- `.forge/features/<slug>/` — Feature-scoped directories replace flat `forge/requirement/`, `forge/design/` structure
- All paths absolute in state.json and agent prompts (no relative path ambiguity)

## Workflow

```
 Phase    Action                    Skill                           Output
 -----    ------                    -----                           ------
  1       Requirement Analysis      forge-requirement-analysis      REQUIREMENTS.md
  2       Design Creation           forge-design-creation           DESIGN.md + research
  3       Design Review             forge-review                    DESIGN-REVIEW-1.md (gate)
  4       Implementation Planning   forge-implementation-planning   IMPL-PLAN.md
  5       Impl Plan Review          forge-review                    IMPL-PLAN-REVIEW-1.md (gate)
  6       Test Planning             forge-test-planning             TEST-PLAN.md
  7       Test Plan Review          forge-review                    TEST-PLAN-REVIEW-1.md (gate)
  8       Code Implementation       forge-implement                 Source code
  9       Code Review               forge-review                    CODE-REVIEW-1.md (gate)
 10       Test Implementation       forge-implement-tests           Test code
 11       Test Review               forge-review                    TEST-REVIEW-1.md (gate)
 12       Documentation             forge-documentation             Docs + CONTEXT.md
```

Phases 1, 2, 4, 6, 8, 10, 12 dispatch to `qc-readonly` task agents (background execution). Phases 3, 5, 7, 9, 11 are review gates; results surface immediately to orchestrator.

### State Management

`.forge/state.json` is the source of truth:

```json
{
  "version": "1.0",
  "features": [{
    "id": "feature-slug",
    "name": "Feature Name",
    "status": "in_progress",
    "phases": {
      "1": {
        "status": "approved",
        "artifacts": [{path, sha, size}],
        "decisions": ["DD-1: ...", "DD-2: ..."]
      },
      "2": {...},
      "3": {
        "status": "approved",
        "review_findings": {"critical": 0, "major": 0, "minor": 2},
        "gate": "PASS"
      }
    },
    "dependency_graph": {
      "forward": {"design-path": ["plan-path", "test-plan-path"]},
      "backward": {"design-path": ["requirement-path"]}
    }
  }],
  "latest_commit": {"sha": "...", "message": "..."}
}
```

**Key features:**
- Single JSON source of truth (no manual editing required)
- Dependency graph enables cascade detection (bidirectional edges)
- Execution metadata for observability (reasoning lines, context usage)
- Artifact index with SHAs (git tracking + rollback support)

### Context Management

Start a **new conversation** between major phases to keep context focused. FORGE-LOGS.md + state.json provide full continuity.

Suggested conversation boundaries:
- After Phase 1 → new conversation for Phase 2
- After Phase 3 → new conversation for Phase 4
- After Phase 7 → new conversation for Phase 8
- After Phase 11 → new conversation for Phase 12

Run `/forge` at any point to see full status dashboard + next step.

### Commands

**`/forge`** — Display orchestrator status (always first output)
- Shows: current phase, started date, phase timeline (all 12 phases + status icons), latest commit
- Nudges: next action based on current phase

**`forge status`** — Phase timeline (concise)

**`forge report`** — All review findings aggregated by phase (critical/major/minor/suggestion counts)

**`forge affected <artifact-path>`** — Impact analysis via cascade detector
- Shows: downstream phases invalidated by this artifact change
- Shows: upstream phases this artifact depends on

**`forge cascade-fix`** — Automatically re-run all invalidated phases in dependency order

## Skills Reference

### Core Skills (18 total)

**Orchestration:**
- **forge** — Main dispatcher. Loads state, displays status, dispatches phases to task agents, polls for completion, handles cascade detection.
- **forge-migrate** — Migrates existing forge projects from old structure to new state.json model with feature namespacing.

**Phases 1-12:**
- **forge-requirement-analysis** (Phase 1) — Extracts specs from context. Outputs: REQUIREMENTS.md
- **forge-design-creation** (Phase 2) — Creates technical design with decision research. Outputs: DESIGN.md + artifacts
- **forge-review** (Phase 3, 5, 7, 9, 11) — Systematic review with severity ranking. Outputs: REVIEW-N.md (gate check)
- **forge-implementation-planning** (Phase 4) — Converts design to implementation units. Outputs: IMPL-PLAN.md
- **forge-test-planning** (Phase 6) — Builds test plan from impl plan. Outputs: TEST-PLAN.md
- **forge-implement** (Phase 8) — Translates plan to code following conventions. Outputs: Source code
- **forge-implement-tests** (Phase 10) — Translates test plan to test code. Outputs: Test code
- **forge-documentation** (Phase 12) — Adds docstrings, updates README, creates CONTEXT.md. Outputs: Docs + CONTEXT.md

**Automation:**
- **forge-autopilot** — Orchestrates full pipeline with coordinated sub-agents (optional; use when comfortable with end-to-end automation)

**Support:**
- **quorum** — Multi-agent consensus for complex decisions

All skills are stored in `skills/*/SKILL.md` files. See individual skill files for detailed instructions.

## Performance & Parallelism

- **Status check:** <500ms (reads state.json only)
- **Phase dispatch:** <1s (construct prompt, spawn task agent)
- **Report generation:** <2s (read state.json + review artifacts)
- **Parallel execution:** Independent phases (4 & 6, 8 & 10) run concurrently; orchestrator atomically merges state updates

Phases with dependencies are automatically ordered (e.g., Phase 3 review must complete before Phase 4 plan starts).

## Cascade Detection & Invalidation

When an artifact changes (e.g., design approved, then requirements re-opened):

1. **Detect affected phases** — Cascade detector traverses dependency graph (forward + backward edges)
2. **Invalidate downstream** — All phases depending on changed artifact marked `invalidated` in state.json
3. **Mark upstream for review** — Phases the changed artifact depends on may need re-validation
4. **Re-run on demand** — User can run `forge affected <path>` to see impact, then `forge cascade-fix` to re-execute all invalidated phases in dependency order

Example: Design change → invalidates Plan, Test Plan, Code, Tests

## Git Operations

Forge maintains a dedicated `.forge/.git` repository:

- **Defensive initialization** — No GPG signing, no hooks, isolated identity (`forge@local`)
- **Idempotent init** — Safe to run `/forge` multiple times; existing config persists
- **Atomic commits** — After each phase, orchestrator commits artifacts with SHA recorded in state.json
- **Rollback support** — Git history enables recovery to any prior phase (with state consistency)
- **Separate from project git** — Never interferes with user's global config or project repository

## Migration from Old Structure

If you have an existing forge project with artifacts in `forge/requirement/`, `forge/design/`, etc.:

```
/forge-migrate --feature <slug>
```

This command:
1. Reads old FORGE-LOGS.md and artifacts
2. Generates state.json with feature namespacing
3. Moves artifacts to `.forge/features/<slug>/`
4. Commits migration with full audit trail in operations.jsonl
5. Archives or deletes old structure (user confirms)

## Known Limitations & Future Work

- **Single active feature** — One feature per state.json; future: `forge switch <feature>` for multi-feature support
- **Manual migration** — Old projects require explicit `forge migrate` command (safe, transparent)
- **Lock-based concurrency** — Supports single-user workflows; multi-user simultaneously editing state.json not supported

For details on architecture decisions, edge cases, and extension points, see `forge/FORGE-DX-OVERHAUL-CONTEXT.md`.

## License

MIT
