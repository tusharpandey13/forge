---
name: forge-requirement-analysis
description: Extract feature specs from context files. Use when analyzing requirements, gathering requirements, or working with context files.
license: Proprietary
metadata:
  author: Auth0 SDKs Team <sdks@auth0.com>
---

# Requirement Analysis

Domain expert for extracting complete feature specs from initial context. USER is the domain expert with Confluence/Slack/tribal knowledge access.

## When to Use

- User asks to analyze or gather requirements
- User references context files
- Starting new feature needing requirement documentation

## Context Sources

- `.forge/FORGE-CONFIG.md` — paths, conventions (if exists)
- `.forge/state.json` — current state (if exists)
- `{context-dir}/*.md` — user-provided external context (PRDs, Confluence exports, issues)
- Codebase structure and existing patterns
- Symlinked directories in workspace

See references/shared-phase-spec.md § feature-dir-note

## Process

See references/shared-phase-spec.md § mandatory-first-output — emit `FORGE :: REQUIREMENT ANALYSIS`

### 0. Check Config

If `.forge/FORGE-CONFIG.md` absent → run config init flow (see forge orchestrator). Read for:
- Context dir path, artifact output paths, project conventions

### 1. Parse Context

Read all context dir files thoroughly.

### 2. Analyze Codebase

Identify related patterns, existing implementations, conventions.

### 3. Identify Gaps

Find: missing constraints, unclear scope, undefined behaviors, edge cases.

### 4. Ask Clarifying Questions

Generate 5–10 specific questions. User has Confluence/Slack + domain knowledge.

### 5. Iterate

Continue until requirements are complete and unambiguous.

### 5a. GATE 1: Capability Preflight

Before documenting requirements, enumerate every action the feature needs that the agent cannot perform directly. Emit exact copy-paste manual commands/handoffs up front for:

- Interactive SSH/terminals
- External writes (CLI tenant config, cloud provider tenants, third-party SaaS)
- Network mutations (POST/PUT to external APIs, config writes)
- MCP servers that may be disconnected or unavailable
- Cloud/SaaS APIs requiring manual setup (auth, permissions, credentials)
- Privileged ops (sudo, elevated access)

Checklist:
- [ ] All external APIs/services identified
- [ ] Each blocked action has exact manual command or handoff step
- [ ] Commands include error recovery guidance
- [ ] User can copy/paste each command without modification
- [ ] Capability scan recorded in requirements output

Surface blockers at start → plan clean manual handoff → never stall mid-task.

### 5b. GATE 2: Verify-Before-Claim Preflight

Before asserting any negative about environment/state ("repo missing", "X not supported", "file absent", "tool unavailable") → verify obvious cause first, cite command output.

Checklist:
- [ ] No unverified claims about repo state, tool availability, or file absence
- [ ] Negative assertion → check active git/gh account (`git config user.email`, `gh auth status`)
- [ ] Env state → verify env vars (`echo $ENV_VAR`)
- [ ] File/path claims → verify actual path and permissions (`ls -la`, `find`)
- [ ] Tool unavailability → confirm installed and in PATH (`which`, `<tool> --version`)
- [ ] Migration targets, abbreviations, conventions → verify against config or codebase; if unknown, ask
- [ ] Every negative claim includes command output

Unverified assumptions → mid-task stalls and false negatives. Verify first, claim second.

### 6. Document

Create formal requirements using [requirements-template.md](./references/requirements-template.md).

Output: `{feature_dir}/requirement/REQUIREMENTS.md`
- Example: `/Users/alice/project/.forge/features/auth-middleware/requirement/REQUIREMENTS.md`

### 7. Self-Validate

See references/shared-phase-spec.md § self-validate. Also check: FR-X/NFR-X IDs consistent.

### 7a. Capability-Scan Output (Gate 1)

If Gate 1 finds blocked actions → add **Capability Constraints** section to REQUIREMENTS.md:

```
## Capability Constraints

The following actions are required but cannot be performed by the agent directly:

| Action | Constraint | Manual Command / Handoff |
|--------|-----------|-------------------------|
| (action) | (external system / blocked reason) | (exact copy-paste command) |

**Recovery:** User runs listed commands before feature handoff resumes.
```

### 8. Update State

Write `.phase-1-output.json` sidecar (schema: see references/shared-phase-spec.md § sidecar-schema).
Phase-specific decisions[] examples: "FR-1 scope clarified", "Key constraints identified"

See references/shared-phase-spec.md § orchestrator-note

## Quality Checks

- All template sections complete; no placeholder text
- Constraints explicit (performance, security, compatibility, data)
- Edge cases identified with expected behaviors
- Acceptance criteria per FR
- Out-of-scope items listed
- Dependencies identified with status

## Error Handling

### Before Starting

See references/shared-phase-spec.md § error-cases (cases 1–3, 4/output).

Additional:
- **Active Feature Not Found** — no `is_active: true` in state.json → ERROR: "No active feature in state.json. Start a new feature or select one." Do not generate requirements.
- **Config Not Found** (case 3 for this phase) → note "FORGE-CONFIG.md not found; will attempt config detection"; run config init flow; continue best-effort.

### During Execution

- **Context dir not found** → WARN: "Context directory not found. Proceeding without external context." Continue codebase-only.
- **Context files unreadable** → WARN: "Could not read some context files: {{ list }}." Continue with readable files.

### Before Completing

- **Output not writable** → see § error-cases case 4
- **Placeholder text remains** → WARN: "Placeholder text found. Replacing with structured TODOs or escalating."

## Anti-Patterns

- Do NOT propose solutions or architecture
- Do NOT include implementation details
- Do NOT assume without asking clarifying questions
- Do NOT silently fail
- Do NOT skip Gate 1 — enumerate external actions up front
- Do NOT skip Gate 2 — never assert negative claims without verifying first

## Handoff

**Output:** `{feature_dir}/requirement/REQUIREMENTS.md` + `.phase-1-output.json`
**Next Phase:** forge-design-creation
