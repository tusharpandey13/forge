# Forge

A structured development workflow system for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Forge breaks feature development into 12 reviewable phases — from requirements through documentation — each powered by a specialized skill.

## Why Forge?

LLM-assisted coding works best with clear boundaries. Without structure, context windows bloat, reviews get skipped, and implementation drifts from requirements. Forge solves this by enforcing a phased workflow where each phase produces a concrete, reviewable artifact before the next begins.

**Key principles:**

- **Artifacts over conversation** — every phase writes a document, not just chat
- **Review gates** — no phase proceeds without explicit review
- **Fresh context** — start new conversations between major phases to avoid context degradation
- **Behavior-first testing** — blackbox tests with HTTP mocking (e.g., MSW, nock), minimal mocking elsewhere

## Installation

Copy the `skills/` directory into your Claude Code configuration:

```bash
cp -r skills/* ~/.claude/skills/
```

Claude Code automatically discovers skills in `~/.claude/skills/`. Each subdirectory with a `SKILL.md` file becomes an available skill.

## Getting Started

### 1. Prepare your project

Create the expected directory structure in your project root:

```
project/
├── docs/
│   ├── context/           # Drop PRDs, specs, Confluence exports here
│   ├── requirement/       # Phase 1 output
│   ├── design/            # Phase 2 output
│   ├── plan/              # Phase 4 + 6 output
│   └── misc/              # Supporting docs
└── src/
```

### 2. Add context

Place any external context (PRDs, specs, issue descriptions) as markdown files in `docs/context/`.

### 3. Run the workflow

Invoke the main skill to see the full workflow:

```
/forge
```

Or jump directly to a specific phase:

```
"Analyze requirements from docs/context/"
"Create design from REQUIREMENTS.md"
"Create implementation plan from DESIGN.md"
```

## Workflow

Forge follows a 12-phase loop. Each phase produces a specific artifact, and review phases gate progression.

```
 Phase    Action                   Output
 ─────    ──────                   ──────
  1       Requirement Analysis     docs/requirement/REQUIREMENTS.md
  2       Design Creation          docs/design/DESIGN.md
  3       Design Review            Feedback → iterate on DESIGN.md
  4       Implementation Planning  docs/plan/IMPL-PLAN.md
  5       Impl Plan Review         Feedback → iterate on IMPL-PLAN.md
  6       Test Planning            docs/plan/TEST-PLAN.md
  7       Test Plan Review         Feedback → iterate on TEST-PLAN.md
  8       Code Implementation      Source code + quality gate
  9       Code Review              Feedback → iterate on code
 10       Test Implementation      Test code + quality gate
 11       Test Review              Feedback → iterate on tests
 12       Documentation            Docs, docstrings, CONTEXT.md
```

### Context management

Start a **new conversation** between major phases to keep context windows focused:

| After Phase | Start New Conversation For |
|-------------|---------------------------|
| 1 (Requirements) | Phase 2 (Design) |
| 2-3 (Design + Review) | Phase 4 (Impl Planning) |
| 6-7 (Test Plan + Review) | Phase 8 (Code Implementation) |
| 10-11 (Tests + Review) | Phase 12 (Documentation) |

### Quality gate

Run after implementation phases (8 and 10):

```bash
# Adapt to your project's toolchain, e.g.:
npm test && npm run build && npm run lint
# or: pnpm run test:coverage && pnpm run prepack && pnpm run lint:fix
```

## Skills Reference

### Core Workflow Skills

| Skill | Phases | Purpose |
|-------|--------|---------|
| `forge` | All | Orchestrator — displays the full workflow and guides phase transitions |
| `forge-requirement-analysis` | 1 | Extracts complete feature specs from `docs/context/` files. Focuses on *what*, not *how*. Produces `REQUIREMENTS.md` |
| `forge-design-creation` | 2 | Creates technical design with public contracts, wire formats, sequence diagrams, and test matrix from requirements |
| `forge-implementation-planning` | 4 | Converts design into implementation units with detailed pseudocode. Analyzes codebase conventions first. No real code |
| `forge-test-planning` | 6 | Builds exhaustive test plan from impl plan. Unit tests + flow tests (pseudo-E2E with HTTP mocking). No real test code |
| `forge-code-review` | 3, 5, 7, 9, 11 | Systematic review with severity-ranked findings (Critical/Major/Minor/Suggestion). Works on any artifact type |
| `forge-documentation` | 12 | Creates docstrings, examples, README updates, and a `[FEATURE]-CONTEXT.md` for future reference |

### Bonus Skill

| Skill | Purpose |
|-------|---------|
| `quorum` | Multi-expert panel simulation for critical analysis. Assembles 3 domain experts + an adversarial auditor for structured debate and synthesis |

## Templates

Each planning skill includes a template for its output artifact:

| Template | Location | Used By |
|----------|----------|---------|
| `REQUIREMENTS-template.md` | `skills/forge-requirement-analysis/` | Requirement Analysis |
| `DESIGN-template.md` | `skills/forge-design-creation/` | Design Creation |
| `IMPL-PLAN-template.md` | `skills/forge-implementation-planning/` | Implementation Planning |
| `TEST-PLAN-template.md` | `skills/forge-test-planning/` | Test Planning |
| `review-checklist.md` | `skills/forge-code-review/` | Code Review (all review phases) |

Templates are picked up automatically by the skills. They define the expected structure for each artifact.

## Phase Commands Quick Reference

| Phase | Command |
|-------|---------|
| 1 | `"Analyze requirements from docs/context/"` |
| 2 | `"Create design from REQUIREMENTS.md"` |
| 3 | `"Review docs/design/DESIGN.md"` |
| 4 | `"Create implementation plan from DESIGN.md"` |
| 5 | `"Review docs/plan/IMPL-PLAN.md"` |
| 6 | `"Create test plan from IMPL-PLAN.md"` |
| 7 | `"Review docs/plan/TEST-PLAN.md"` |
| 8 | `"Implement IMPL-PLAN.md, then run quality gate"` |
| 9 | `"Review implementation changes"` |
| 10 | `"Implement TEST-PLAN.md, then run quality gate"` |
| 11 | `"Review test changes"` |
| 12 | `"Document the feature"` |

## License

MIT
