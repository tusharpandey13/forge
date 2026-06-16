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

- `.forge/state.json` — feature metadata, prior review_findings, phase status
- `.forge/FORGE-CONFIG.md` — conventions, paths
- `.forge/features/<feature-slug>/` — feature directory with all phase artifacts
  - **Example:** `/Users/alice/project/.forge/features/auth-middleware/`
- The artifact being reviewed
- Upstream artifacts (requirements for design, design for plan, etc.)

**NOTE:** All artifact paths are absolute paths resolved by the orchestrator at dispatch time.

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

Read `.forge/state.json` to find prior review rounds on this phase.
Access `state.json.features[0].phases[PHASE_NUM].review_findings` to determine the review number (N). First review = 1.

If this is a re-review (N > 1):
- Read prior review artifact(s) from feature directory
- Verify previously reported CRITICAL/MAJOR findings are addressed
- Start the new review with a resolution check

### 3. Execute Review

Apply the relevant checklist from [review-checklist.md](./references/review-checklist.md).

For re-reviews, structure output as:

```markdown
## Resolution of Round [N-1] Findings
- [CRITICAL] [Title] — Fixed / Not fixed / Partially fixed
- [MAJOR] [Title] — Fixed / Not fixed / Partially fixed

## New Findings
(findings from this round)
```

### 4. Write Review Artifact

**File naming:** `{ARTIFACT}-REVIEW-{N}.md` under feature directory.

Examples (with new path structure and concrete absolute paths):
- `/Users/alice/project/.forge/features/auth-middleware/design/DESIGN-REVIEW-1.md`
- `/Users/alice/project/.forge/features/auth-middleware/design/DESIGN-REVIEW-2.md`
- `/Users/alice/project/.forge/features/auth-middleware/plan/IMPL-PLAN-REVIEW-1.md`
- `/Users/alice/project/.forge/features/auth-middleware/plan/TEST-PLAN-REVIEW-1.md`
- `/Users/alice/project/.forge/features/auth-middleware/review/CODE-REVIEW-1.md`
- `/Users/alice/project/.forge/features/auth-middleware/review/TEST-REVIEW-1.md`

**(All paths are absolute, provided by orchestrator at dispatch time)**

### 5. Generate Phase Output

Write `.phase-{{ PHASE_NUM }}-output.json` with review_findings for orchestrator integration:

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

**IMPORTANT:**
- Orchestrator reads this file and updates `state.json.phases[N].review_findings`
- Do NOT update FORGE-LOGS.md or commit changes — orchestrator handles state updates and commits
- Save output to absolute path provided by task agent (e.g., `/absolute/path/.phase-3-output.json`)

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

## Error Handling

### Before Starting

1. **State.json Missing or Invalid:**
   - If `.forge/state.json` cannot be found or is corrupted
   - **Action:** ERROR: "state.json missing or corrupted. Run /forge to reinitialize."
   - **Recovery:** Do not proceed; return error

2. **Artifact to Review Not Found:**
   - If the target artifact file does not exist at expected path
   - **Action:** ERROR: "Artifact not found at {{ artifact_path }}"
   - **Recovery:** Return error; escalate to orchestrator

3. **Upstream Artifact Missing:**
   - If prerequisite artifacts (e.g., REQUIREMENTS.md for design review) not found
   - **Action:** ERROR: "Cannot review {{ artifact_type }}: upstream artifact {{ upstream_artifact }} missing"
   - **Recovery:** Return error; do not proceed without context

4. **Config Not Found:**
   - If `.forge/FORGE-CONFIG.md` missing
   - **Action:** WARN: "FORGE-CONFIG.md not found. Using standard quality gates only."
   - **Recovery:** Continue with default review standards

### During Execution

5. **Prior Review Not Found (Re-review):**
   - If state.json indicates this is a re-review but prior review artifact missing
   - **Action:** WARN: "Prior review round not found. Starting fresh review."
   - **Recovery:** Continue with new review; skip resolution check

6. **Ambiguous or Unresolved Issues:**
   - If artifact contains unresolved dependencies or unclear requirements
   - **Action:** FLAG: "Issues identified that may be upstream: {{ list }}. Note for user/orchestrator."
   - **Recovery:** Include in findings; flag for cascade consideration

### Before Completing

7. **Output Path Not Writable:**
   - If review artifact output path not writable
   - **Action:** ERROR: "Cannot write review to {{ output_path }}: {{ reason }}"
   - **Recovery:** Return error; do not complete review

8. **Phase Output File Not Writable:**
   - If `.phase-N-output.json` cannot be written
   - **Action:** ERROR: "Cannot write phase output to {{ output_path }}: {{ reason }}"
   - **Recovery:** Return error; escalate to orchestrator

## Anti-Patterns

- Do NOT approve artifacts with unresolved CRITICAL or MAJOR findings
- Do NOT review without reading upstream artifacts for context
- Do NOT invent requirements during review — flag missing coverage as findings
- Do NOT conflate severity levels — be precise about impact
- Do NOT silently fail — report all errors with full context
