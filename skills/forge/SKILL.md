---
name: forge
description: Complete development workflow system. Use when starting new features, asking about development process, or needing guidance on any phase of feature development.
---

# Forge — Orchestrator

Active orchestrator for the forge development workflow. Detects project state and guides the user to the next step.

## When to Use

- User types `/forge` or says "forge"
- User is starting a new feature
- User asks about workflow phases or status
- User needs development process guidance

## On Trigger

### Step 1: Check Workspace

Check if `.forge/` directory exists at project root.

**If not found — Initialize:**

1. Create directories:
   ```
   .forge/          # Internals (config, logs, git)
   forge/           # Default artifact directory (user-visible)
   forge/context/   # User drops PRDs, specs, issues here
   ```
2. Initialize forge git repository (tracks .forge/ and forge/ only):
   ```bash
   mkdir -p .forge forge/context
   git init .forge
   git -C .forge config core.worktree "$(pwd)"
   # Exclude everything except forge-managed files
   cat > .forge/.git/info/exclude << 'EXCLUDE'
   /*
   !/.forge/
   .forge/.git
   !/forge/
   EXCLUDE
   ```
3. Run config detection flow (see Config Initialization below)
4. Write `.forge/FORGE-CONFIG.md` and `.forge/FORGE-LOGS.md`
5. Initial commit:
   ```bash
   git -C .forge add -A && git -C .forge commit -m "forge: init workspace"
   ```
6. Output:
   ```
   FORGE :: INIT
     Workspace created
     Config: .forge/FORGE-CONFIG.md
     Artifacts: forge/

     Next: Drop context files into forge/context/ and say "analyze requirements"
   ```

**If found — Read State:**
1. Read `.forge/FORGE-CONFIG.md`
2. Read `.forge/FORGE-LOGS.md`
3. Go to Step 2

### Step 2: Determine Current Phase

Parse FORGE-LOGS.md `## Current` section. Match status to determine next action.

### Step 3: Display Status + Nudge

**MANDATORY FIRST OUTPUT (when state exists):**

```
FORGE :: [Feature Name]
  Phase: [N] of 12 — [Phase Name] ([status])
  Last: [description] ([date])
  Next: [suggested action]
```

If user asks for detailed status:

```
FORGE :: [Feature Name]
  Phase 1 — Requirement Analysis [approved]
    forge/requirement/REQUIREMENTS.md
  Phase 2 — Design Creation [approved]
    forge/design/DESIGN.md
  Phase 3 — Design Review [completed]
    forge/design/DESIGN-REVIEW-1.md
  Phase 4 — Implementation Planning [in_progress]
    (working...)
  Phase 5-12 — pending

  Next: Complete implementation plan
```

### Phase-to-Action Nudges

- No FORGE-LOGS.md → "Start with: describe your feature or drop context into forge/context/"
- Phase 1 complete → "Next: Create design from REQUIREMENTS.md"
- Phase 2 complete → "Next: Review forge/design/DESIGN.md"
- Phase 3 approved → "Next: Create implementation plan (consider new conversation)"
- Phase 4 complete → "Next: Review forge/plan/IMPL-PLAN.md"
- Phase 5 approved → "Next: Create test plan from IMPL-PLAN.md"
- Phase 6 complete → "Next: Review forge/plan/TEST-PLAN.md"
- Phase 7 approved → "Next: Implement code (consider new conversation)"
- Phase 8 complete → "Next: Review implementation"
- Phase 9 approved → "Next: Implement tests"
- Phase 10 complete → "Next: Review tests"
- Phase 11 approved → "Next: Document the feature (consider new conversation)"
- Phase 12 complete → "Feature complete."

Review failed → "Review found issues. Fix [artifact], then re-review."

### Fresh Context Guidance

On transitions that benefit from a new conversation, append:
```
  Tip: Consider starting a new conversation for the next phase.
       FORGE-LOGS.md provides full context for continuity.
```

Transitions: after Phase 1, after Phase 3, after Phase 7, after Phase 11.

## Config Initialization

Run when `.forge/FORGE-CONFIG.md` does not exist.

**Process:**

1. Scan codebase:
   - Language(s), framework(s), package manager
   - File/class/function naming patterns (sample 10+ files)
   - Error handling patterns
   - Logging patterns
   - Test framework, test file patterns, mocking approach
   - Directory structure
   - Quality gate commands (package.json scripts, Makefile targets, etc.)

2. Compute confidence per convention:
   - High (>80% files follow pattern) → auto-accept
   - Low (<80% or ambiguous) → ask user

3. Check if user has an existing docs directory (docs/, documentation/, etc.)
   - If found → ask if they want to use it as the artifact root instead of `forge/`
   - If not → use `forge/` (create it)

4. Present to user:
   ```
   FORGE :: CONFIG
     Detected conventions:
     - Language: TypeScript
     - Framework: Express + React
     - Package manager: pnpm
     - File naming: kebab-case (e.g., user-service.ts)
     - Test framework: vitest, co-located *.test.ts
     - Error handling: typed errors extending AppError
     - Quality gate: pnpm test && pnpm build && pnpm lint

     Need your input:
     - Mocking approach unclear — found both vi.mock and msw usage. Which is primary for new tests?
     - Any custom instructions for this project?
   ```

5. Write `.forge/FORGE-CONFIG.md`

## FORGE-LOGS.md Format

```markdown
# Forge Logs

## Feature
[Feature name/description]
Started: [date]

## Current
Phase [N]: [Name] — [status]

## Artifacts
- .forge/FORGE-CONFIG.md (SHA: abc123)
- forge/requirement/REQUIREMENTS.md [approved] (SHA: def456)
- forge/design/DESIGN.md [approved] (SHA: ghi789)
- forge/design/DESIGN-REVIEW-1.md (SHA: ghi789)

## Log

### Phase 1: Requirement Analysis — approved
- Started: [timestamp]
- Completed: [timestamp]
- Artifact: forge/requirement/REQUIREMENTS.md
- Commit: abc123
- Decisions:
  - Scoped to API layer only
  - Deferred UI changes to separate feature
- Questions resolved:
  - Auth flow confirmed as OAuth2 PKCE (per user)

### Phase 2: Design Creation — approved
- Started: [timestamp]
- Completed: [timestamp]
- Artifact: forge/design/DESIGN.md
- Review: forge/design/DESIGN-REVIEW-1.md
- Design research:
  - forge/design/design-artifact-cache-strategy.md
  - forge/design/design-artifact-error-propagation.md
- Commit: def456
- Decisions:
  - DD-1: Middleware over decorator (matches existing pattern)
  - DD-2: Redis cache with 5min TTL (user chose)
- Review rounds: 1 (2 MAJOR fixed)
```

## FORGE-CONFIG.md Format

```markdown
# Forge Configuration

## Project
- Name: [project-name]
- Language: [detected]
- Framework: [detected]
- Package manager: [detected]
- Source root: [detected]

## Conventions
- File naming: [pattern]
- Class naming: [pattern]
- Function naming: [pattern]
- Error handling: [pattern, example location]
- Logging: [pattern, example location]
- Test framework: [framework]
- Test file pattern: [pattern]
- Test location: [co-located / separate]
- Mocking approach: [library + pattern]
- Assertions: [library]

## Paths
- Context: forge/context/
- Artifacts: forge/
- Requirements: forge/requirement/
- Design: forge/design/
- Plans: forge/plan/
- Reviews: forge/review/

## Quality Gate
[command, e.g.: pnpm test && pnpm build && pnpm lint]

## Custom Instructions
[user-provided, freeform]

## Detection
- Date: [date]
- Files sampled: [count]
- Auto-detected: [N]/[total]
- User-provided: [N]/[total]
```

## Forge Git Operations

All skills use forge git for tracking artifacts:

```bash
# Commit after producing/updating artifacts
git -C .forge add -A && git -C .forge commit -m "forge: [phase description]"

# Get SHA for FORGE-LOGS.md
git -C .forge rev-parse --short HEAD
```

Skills record the SHA in FORGE-LOGS.md after each commit.

## Rollback

When a review finds design-level issues or user requests rollback:

1. Read FORGE-LOGS.md → find target phase commit SHA
2. Show diff: `git -C .forge diff [SHA]..HEAD`
3. Mark all downstream phases as `invalidated` in FORGE-LOGS.md
4. User decides: full revert (`git -C .forge checkout [SHA] -- forge/`) or targeted edit
5. Re-enter workflow at the rolled-back phase

## Workflow Phases

| Phase | Action | Skill |
|-------|--------|-------|
| 1 | Requirement Analysis | forge-requirement-analysis |
| 2 | Design Creation | forge-design-creation |
| 3 | Design Review | forge-review |
| 4 | Implementation Planning | forge-implementation-planning |
| 5 | Impl Plan Review | forge-review |
| 6 | Test Planning | forge-test-planning |
| 7 | Test Plan Review | forge-review |
| 8 | Code Implementation | forge-implement |
| 9 | Code Review | forge-review |
| 10 | Test Implementation | forge-implement-tests |
| 11 | Test Review | forge-review |
| 12 | Documentation | forge-documentation |
