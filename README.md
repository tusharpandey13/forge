# Forge

A structured development workflow system for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Forge breaks feature development into 12 reviewable phases — from requirements through documentation — each powered by a specialized skill.

## Why Forge?

LLM-assisted coding works best with clear boundaries. Without structure, context windows bloat, reviews get skipped, and implementation drifts from requirements. Forge solves this by enforcing a phased workflow where each phase produces a concrete, reviewable artifact before the next begins.

**Key principles:**

- **Artifacts over conversation** — every phase writes a document, not just chat
- **Review gates** — no phase proceeds without explicit review
- **State tracking** — FORGE-LOGS.md provides full context across conversations
- **Convention-first** — analyzes your codebase and adapts to existing patterns
- **Behavior-first testing** — blackbox tests following codebase conventions, minimal mocking

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
- Create `.forge/` directory for internal state (config, logs, git tracking)
- Detect your codebase conventions (language, framework, naming patterns, test setup)
- Ask for your input on anything it's unsure about
- Create a `forge/` directory for artifacts (or adapt to your existing docs directory)

### 2. Add context

Place any external context (PRDs, specs, issue descriptions) as markdown files in `forge/context/`.

### 3. Run the workflow

Say "analyze requirements" to start, or just `/forge` to see what's next at any point.

## Workspace Structure

```
project/
├── .forge/                  # Internals (auto-managed)
│   ├── .git/                # Forge git repo (tracks forge artifacts)
│   ├── FORGE-CONFIG.md      # Detected conventions + user config
│   └── FORGE-LOGS.md        # State, phase history, artifact registry
├── forge/                   # Artifacts (user-visible, customizable path)
│   ├── context/             # User-provided PRDs, specs, issues
│   ├── requirement/         # Phase 1 output
│   ├── design/              # Phase 2 output + design decision research
│   ├── plan/                # Phase 4 + 6 output
│   └── review/              # Phase 9 + 11 output
└── src/                     # Your source code (untouched by forge git)
```

The artifact directory path is configurable — forge adapts to your project's existing conventions.

## Workflow

```
 Phase    Action                   Skill                          Output
 -----    ------                   -----                          ------
  1       Requirement Analysis     forge-requirement-analysis     REQUIREMENTS.md
  2       Design Creation          forge-design-creation          DESIGN.md + research artifacts
  3       Design Review            forge-review                   DESIGN-REVIEW-1.md
  4       Implementation Planning  forge-implementation-planning  IMPL-PLAN.md
  5       Impl Plan Review         forge-review                   IMPL-PLAN-REVIEW-1.md
  6       Test Planning            forge-test-planning            TEST-PLAN.md
  7       Test Plan Review         forge-review                   TEST-PLAN-REVIEW-1.md
  8       Code Implementation      forge-implement                Source code
  9       Code Review              forge-review                   CODE-REVIEW-1.md
 10       Test Implementation      forge-implement-tests          Test code
 11       Test Review              forge-review                   TEST-REVIEW-1.md
 12       Documentation            forge-documentation            Docs + CONTEXT.md
```

### State Tracking

FORGE-LOGS.md tracks everything:
- Current phase and status
- All artifacts with paths and git SHAs
- Key decisions made at each phase
- Review rounds and findings

Run `/forge` at any point to see where you are and what to do next.

### Context Management

Start a **new conversation** between major phases to keep context focused. FORGE-LOGS.md provides full continuity.

Suggested conversation boundaries:
- After Phase 1 → new conversation for Phase 2
- After Phase 3 → new conversation for Phase 4
- After Phase 7 → new conversation for Phase 8
- After Phase 11 → new conversation for Phase 12

### Quality Gate

Defined in FORGE-CONFIG.md during setup. Runs automatically after implementation phases (8 and 10).

## Skills Reference

### Core Skills

- **forge** — Active orchestrator. Initializes workspace, detects state, nudges to next step.
- **forge-requirement-analysis** — Phase 1. Extracts specs from context files. Focuses on *what*, not *how*.
- **forge-design-creation** — Phase 2. Creates technical design with interactive design decision research.
- **forge-review** — Phases 3, 5, 7, 9, 11. Systematic review with severity-ranked findings. Produces numbered review artifacts.
- **forge-implementation-planning** — Phase 4. Converts design to implementation units with pseudocode and parallelism tiers.
- **forge-test-planning** — Phase 6. Builds test plan from impl plan. Discovers and follows codebase test conventions.
- **forge-implement** — Phase 8. Translates plan to code. Auto-decides parallelism from dependency graph.
- **forge-implement-tests** — Phase 10. Translates test plan to test code following codebase conventions.
- **forge-documentation** — Phase 12. Docstrings, examples, README updates, and CONTEXT.md.

### Automation

- **forge-autopilot** — Runs the full forge pipeline with subagents. Minimal human interaction. Gate-based progression with automatic fix cycles.

## Templates

Each planning skill includes a template for its output artifact:

- `REQUIREMENTS-template.md` in `forge-requirement-analysis/`
- `DESIGN-template.md` in `forge-design-creation/`
- `IMPL-PLAN-template.md` in `forge-implementation-planning/`
- `TEST-PLAN-template.md` in `forge-test-planning/`
- `review-checklist.md` in `forge-review/`

## License

MIT
