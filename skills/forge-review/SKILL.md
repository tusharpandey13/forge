---
name: forge-review
description: Systematic review of design docs, plans, or code. Use when reviewing, doing code review, or asking for feedback on artifacts.
---

# Review

Systematic review of design docs, implementation plans, test plans, or code changes. Produces a numbered review artifact.

## When to Use

- User asks to review any forge artifact
- User mentions "review" or asks for feedback
- Phases 3, 5, 7, 9, 11 of the forge workflow

## Context Sources

- `.forge/FORGE-CONFIG.md` — conventions, paths
- `.forge/FORGE-LOGS.md` — current state, prior reviews
- The artifact being reviewed
- Upstream artifacts (requirements for design, design for plan, etc.)

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: REVIEW
```

### 1. Identify Review Type

Determine from context or user input:
- **Design Review** (Phase 3): target DESIGN.md, context REQUIREMENTS.md
- **Impl Plan Review** (Phase 5): target IMPL-PLAN.md, context DESIGN.md + REQUIREMENTS.md
- **Test Plan Review** (Phase 7): target TEST-PLAN.md, context IMPL-PLAN.md + DESIGN.md
- **Code Review** (Phase 9): target changed source files, context IMPL-PLAN.md
- **Test Review** (Phase 11): target changed test files, context TEST-PLAN.md

### 2. Check for Prior Reviews

Read FORGE-LOGS.md for prior review rounds on this artifact.
Determine the review number (N). First review = 1.

If this is a re-review (N > 1):
- Read prior review artifact(s)
- Verify previously reported CRITICAL/MAJOR findings are addressed
- Start the new review with a resolution check

### 3. Execute Review

Apply the relevant checklist from [review-checklist.md](./review-checklist.md).

For re-reviews, structure output as:

```markdown
## Resolution of Round [N-1] Findings
- [CRITICAL] [Title] — Fixed / Not fixed / Partially fixed
- [MAJOR] [Title] — Fixed / Not fixed / Partially fixed

## New Findings
(findings from this round)
```

### 4. Write Review Artifact

**File naming:** `{ARTIFACT}-REVIEW-{N}.md`

Examples:
- `forge/design/DESIGN-REVIEW-1.md`
- `forge/design/DESIGN-REVIEW-2.md`
- `forge/plan/IMPL-PLAN-REVIEW-1.md`
- `forge/plan/TEST-PLAN-REVIEW-1.md`
- `forge/review/CODE-REVIEW-1.md`
- `forge/review/TEST-REVIEW-1.md`

### 5. Update State

Update FORGE-LOGS.md:
```markdown
### Phase [N]: [Type] Review — [approved/needs-fixes]
- Completed: [timestamp]
- Artifact: [review file path]
- Round: [N]
- Findings: [X] CRITICAL, [Y] MAJOR, [Z] MINOR, [W] SUGGESTION
- Gate: [PASS/FAIL]
- Commit: [SHA]
```

Commit:
```bash
git -C .forge add -A && git -C .forge commit -m "forge: phase [N] — [type] review round [R]"
```

## Output Format

```markdown
# [Type] Review — Round [N]

## Summary
- Target: [artifact path]
- Reviewed against: [upstream artifact paths]
- Findings: [X] CRITICAL, [Y] MAJOR, [Z] MINOR, [W] SUGGESTION
- Gate: PASS / FAIL

## Problems

### [CRITICAL] Issue Title
- Location: [file/section reference]
- Impact: [what breaks if not fixed]
- Fix: [specific action to resolve]

### [MAJOR] Issue Title
- Location: [file/section reference]
- Impact: [what is affected]
- Fix: [specific action to resolve]

### [MINOR] Issue Title
- Location: [file/section reference]
- Fix: [specific action to resolve]

## Recommendations

### [SUGGESTION] Recommendation Title
- Location: [file/section reference]
- Benefit: [why this improves the artifact]

## Questions

### [QUESTION] What needs clarification
- Context: [why this matters for the review]
```

## Severity Definitions

- **CRITICAL** — Blocks progress, causes failures, security issue. Must fix before proceeding.
- **MAJOR** — Significant quality or correctness issue. Should fix before approval.
- **MINOR** — Style, convention, minor improvement. Fix if time permits.
- **SUGGESTION** — Optional enhancement. Consider for future.

## Gate Rule

```
0 CRITICAL + 0 MAJOR → PASS (phase approved)
Any CRITICAL or MAJOR → FAIL (fix cycle required)
```

## Cascade Awareness

If review reveals issues that affect earlier phases, note in the review:
- "This finding may require changes to [upstream artifact]"
- The orchestrator or user decides whether to trigger a rollback

## Anti-Patterns

- Do NOT approve artifacts with unresolved CRITICAL or MAJOR findings
- Do NOT review without reading upstream artifacts for context
- Do NOT invent requirements during review — flag missing coverage as findings
- Do NOT conflate severity levels — be precise about impact
