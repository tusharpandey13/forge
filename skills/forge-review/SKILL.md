---
name: forge-review
description: Systematic review of design docs, plans, or code. Use when reviewing, doing code review, or asking for feedback on artifacts.
license: Proprietary
metadata:
  author: Auth0 SDKs Team <sdks@auth0.com>
---

# Review

Systematic review of design docs, implementation plans, test plans, or code changes. Produces a numbered review artifact.

## When to Use

- User asks to review any forge artifact
- User mentions "review" or asks for feedback
- Phases 3, 5, 7, 9, 11 of the forge workflow

## Context Sources

- `.forge/state.json` — feature metadata, prior review_findings, phase status (via `forge slice`)
- `.forge/FORGE-CONFIG.md` — conventions, paths
- `.forge/features/<feature-slug>/` — feature dir with all phase artifacts
- The artifact being reviewed
- Upstream artifacts (requirements for design, design for plan, etc.)

See references/shared-phase-spec.md § feature-dir-note

## Process

See references/shared-phase-spec.md § mandatory-first-output — emit `FORGE :: REVIEW`

### 1. Identify Review Type

Determine from context or user input:
- **Design Review** (Phase 3): target DESIGN.md, context REQUIREMENTS.md
- **Impl Plan Review** (Phase 5): target IMPL-PLAN.md, context DESIGN.md + REQUIREMENTS.md
- **Test Plan Review** (Phase 7): target TEST-PLAN.md, context IMPL-PLAN.md + DESIGN.md
- **Code Review** (Phase 9): target changed source files, context IMPL-PLAN.md
- **Test Review** (Phase 11): target changed test files, context TEST-PLAN.md

### 2. Check for Prior Reviews

Use `forge slice` to get active feature state, then `forge ref <feat> <artifact>` to access prior review data. Determine review round N (first = 1).

If re-review (N > 1):
- Read prior review artifact(s) from feature dir
- Verify previously reported CRITICAL/MAJOR findings are addressed
- Start new review with resolution check

### 3. Execute Review

Apply relevant checklist from [review-checklist.md](./references/review-checklist.md).

**For Code Review (Phase 9) and Test Review (Phase 11):**
- **Before marking CRITICAL or MAJOR:** Apply Surface-Aware Finding Verification (see ../forge/references/verification-protocol.md#protocol-c):
  - Classify code location: PUBLIC, INTERNAL, or TEST surface
  - If INTERNAL or TEST: reproduce finding against PUBLIC surface; if not reproducible → downgrade to MINOR
  - Cite reproduction evidence in finding documentation
- **For Test Review (Phase 11):** Apply Tautology Heuristic (see ../forge/references/verification-protocol.md#protocol-b):
  - [ ] Tests have real assertions (not zero)
  - [ ] Assertions are meaningful (not bare constants)
  - [ ] Tests don't assert only on mock configuration
  - [ ] Snapshot-only tests also have behavioral assertions
  - Tests failing heuristic → flag as MAJOR if in scope

For re-reviews, structure output:
```markdown
## Resolution of Round [N-1] Findings
- [CRITICAL] [Title] — Fixed / Not fixed / Partially fixed
- [MAJOR] [Title] — Fixed / Not fixed / Partially fixed

## New Findings
(findings from this round)
```

### 4. Write Review Artifact

Naming: `{ARTIFACT}-REVIEW-{N}.md` under feature dir.

Examples:
- `/Users/alice/project/.forge/features/auth-middleware/design/DESIGN-REVIEW-1.md`
- `/Users/alice/project/.forge/features/auth-middleware/plan/IMPL-PLAN-REVIEW-1.md`
- `/Users/alice/project/.forge/features/auth-middleware/review/CODE-REVIEW-1.md`

### 5. Generate Phase Output

Write `.phase-{{ PHASE_NUM }}-output.json` with review_findings (schema: see references/shared-phase-spec.md § sidecar-schema):

```json
{
  "review_findings": {
    "round": 1,
    "critical": 0,
    "major": 2,
    "minor": 1,
    "suggestion": 3,
    "gate": "FAIL"
  }
}
```

See references/shared-phase-spec.md § orchestrator-note — do NOT update FORGE-LOGS.md or commit; orchestrator handles state updates.

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
- Surface: [PUBLIC/INTERNAL/TEST]
- Reproduction: [how to reproduce on public API surface]
- Impact: [what breaks if not fixed]
- Fix: [specific action]

### [MAJOR] Issue Title
- Location: [file/section reference]
- Impact: [what is affected]
- Fix: [specific action]

### [MINOR] Issue Title
- Location: [file/section reference]
- Fix: [specific action]

## Recommendations

### [SUGGESTION] Recommendation Title
- Location: [file/section reference]
- Benefit: [why this improves the artifact]

## Questions

### [QUESTION] What needs clarification
- Context: [why this matters]
```

## Severity Definitions

- **CRITICAL** — Blocks progress, causes failures, security issue. Must fix before proceeding.
- **MAJOR** — Significant quality or correctness issue. Should fix before approval.
- **MINOR** — Style, convention, minor improvement. Fix if time permits.
- **SUGGESTION** — Optional enhancement.

## Gate Rule

```
0 CRITICAL + 0 MAJOR → PASS (phase approved)
Any CRITICAL or MAJOR → FAIL (fix cycle required)
```

## Cascade Awareness

If review reveals issues affecting earlier phases → note: "This finding may require changes to [upstream artifact]". Orchestrator or user decides whether to trigger rollback.

## Error Handling

### Before Starting

See references/shared-phase-spec.md § error-cases (cases 1, 3, 4).

- **Artifact to review not found** → ERROR: "Artifact not found at {{ artifact_path }}" Return error; escalate.
- **Upstream artifact missing** → ERROR: "Cannot review {{ artifact_type }}: upstream artifact {{ upstream }} missing" Do not proceed without context.
- Case 3 (Config not found) → WARN: "FORGE-CONFIG.md not found. Using standard quality gates only." Continue.

### During Execution

- **Prior review missing (re-review)** → WARN: "Prior review round not found. Starting fresh review." Skip resolution check.
- **Ambiguous/unresolved issues** → FLAG: "Issues may be upstream: {{ list }}." Include in findings; flag for cascade.

### Before Completing

- **Output not writable** → see § error-cases case 4
- **Phase output not writable** → ERROR: "Cannot write phase output to {{ output_path }}: {{ reason }}" Escalate.

## Anti-Patterns

- Do NOT approve artifacts with unresolved CRITICAL or MAJOR findings
- Do NOT review without reading upstream artifacts
- Do NOT invent requirements during review — flag missing coverage as findings
- Do NOT conflate severity levels
- Do NOT silently fail
