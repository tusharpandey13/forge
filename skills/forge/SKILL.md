---
name: forge
description: Complete development workflow system. Use when starting new features, asking about development process, or needing guidance on any phase of feature development.
---

# Forge

Complete development workflow system with 6 specialized skills for end-to-end feature development.

Guide through the complete 12-phase development workflow. Start a new conversation between major phases to get fresh context.

## When to Use

- User is starting a new feature
- User asks about workflow phases
- User needs development process guidance

**MANDATORY FIRST OUTPUT:**
```
FORGE :: WORKFLOW
```

## Workflow Overview

```
┌──────────────────────┐
│ 1. REQUIREMENTS      │ → docs/requirement/REQUIREMENTS.md
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 2. DESIGN            │ → docs/design/DESIGN.md
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 3. REVIEW (Design)   │ → Feedback → Updates
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 4. IMPL PLAN         │ → docs/plan/IMPL-PLAN.md
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 5. REVIEW (Impl)     │ → Feedback → Updates
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 6. TEST PLAN         │ → docs/plan/TEST-PLAN.md
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 7. REVIEW (Tests)    │ → Feedback → Updates
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 8. IMPLEMENT CODE    │ → Source code + Quality Gate
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 9. REVIEW (Code)     │ → Feedback → Updates
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 10. IMPLEMENT TESTS  │ → Test code + Quality Gate
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 11. REVIEW (Tests)   │ → Feedback → Updates
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 12. DOCUMENTATION    │ → Docs + Context file
└──────────────────────┘
```

## Phase Commands

| Phase | Command | Output |
|-------|---------|--------|
| 1 | "Analyze requirements from docs/context/" | REQUIREMENTS.md |
| 2 | "Create design from REQUIREMENTS.md" | DESIGN.md |
| 3 | "Review docs/design/DESIGN.md" | Review feedback |
| 4 | "Create implementation plan from DESIGN.md" | IMPL-PLAN.md |
| 5 | "Review docs/plan/IMPL-PLAN.md" | Review feedback |
| 6 | "Create test plan from IMPL-PLAN.md" | TEST-PLAN.md |
| 7 | "Review docs/plan/TEST-PLAN.md" | Review feedback |
| 8 | "Implement IMPL-PLAN.md, then run quality gate" | Source code |
| 9 | "Review implementation changes" | Review feedback |
| 10 | "Implement TEST-PLAN.md, then run quality gate" | Test code |
| 11 | "Review test changes" | Review feedback |
| 12 | "Document the feature" | Documentation |

## Directory Structure

Before starting, ensure this structure exists:

```
project/
├── docs/
│   ├── context/           # External context files (PRDs, specs)
│   ├── requirement/       # Phase 1 output
│   ├── design/            # Phase 2 output
│   ├── plan/              # Phase 4, 6 output
│   ├── misc/              # Other docs
│   └── [FEATURE]-CONTEXT.md  # Phase 12 output
└── [source code]
```

## Fresh Context Per Phase

Start a **new conversation** between major phases to avoid context window bloat:

- After Phase 1 → New conversation for Phase 2
- After Phase 2-3 → New conversation for Phase 4
- After Phase 6-7 → New conversation for Phase 8
- After Phase 10-11 → New conversation for Phase 12

## Quality Gate

Run after implementation phases (8 and 10):

```bash
pnpm run test:coverage && pnpm run prepack && pnpm run lint:fix
```

## Forge Skills

| Phase | Skill |
|-------|-------|
| 1 | forge-requirement-analysis |
| 2 | forge-design-creation |
| 3, 5, 7, 9, 11 | forge-code-review |
| 4 | forge-implementation-planning |
| 6 | forge-test-planning |
| 12 | forge-documentation |

All skills are prefixed with `forge-` for logical grouping.
