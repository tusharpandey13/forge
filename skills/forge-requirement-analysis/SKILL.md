---
name: forge-requirement-analysis
description: Extract feature specs from context files. Use when analyzing requirements, gathering requirements, or working with context files.
---

# Requirement Analysis

Domain expert for extracting complete feature specifications from initial context. The USER is the domain expert with access to Confluence, Slack, and tribal knowledge.

## When to Use

- User asks to analyze or gather requirements
- User references context files
- Starting a new feature that needs requirement documentation

## Context Sources

- `.forge/FORGE-CONFIG.md` — paths, conventions (if exists)
- `.forge/FORGE-LOGS.md` — current state (if exists)
- `{context-dir}/*.md` — user-provided external context (PRDs, Confluence exports, issues)
- Codebase structure and existing patterns
- Any symlinked directories in the workspace

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: REQUIREMENT ANALYSIS
```

### 0. Check Config

If `.forge/FORGE-CONFIG.md` does not exist, run the config initialization flow (see forge orchestrator skill) before proceeding. This ensures paths and conventions are established.

Read FORGE-CONFIG.md for:
- Context directory path
- Artifact output paths
- Project conventions (for understanding constraints)

### 1. Parse Context

Read all files in the context directory thoroughly.

### 2. Analyze Codebase

Identify related patterns, existing implementations, and conventions.

### 3. Identify Gaps

Find missing constraints, unclear scope, undefined behaviors, edge cases.

### 4. Ask Clarifying Questions

Generate 5-10 specific questions for the user. They have Confluence/Slack access and domain knowledge.

### 5. Iterate

Continue asking questions until requirements are complete and unambiguous.

### 6. Document

Create formal requirements document using the [REQUIREMENTS-template.md](./REQUIREMENTS-template.md).

Output: `{requirements-dir}/REQUIREMENTS.md`

### 7. Self-Validate

Re-read the artifact. Verify:
- No `[placeholder]` or `TBD` text remains
- All sections have content
- Cross-reference IDs (FR-X, NFR-X) are consistent
Fix any issues silently.

### 8. Update State

Update FORGE-LOGS.md:
```markdown
### Phase 1: Requirement Analysis — completed
- Started: [timestamp]
- Completed: [timestamp]
- Artifact: [path]/REQUIREMENTS.md
- Decisions: [key scope decisions]
- Questions resolved: [summary of clarifications]
- Commit: [SHA]
```

Commit:
```bash
git -C .forge add -A && git -C .forge commit -m "forge: phase 1 — requirements complete"
```

## Quality Checks

- All template sections complete
- No placeholder text remains
- Constraints are explicit (performance, security, compatibility, data)
- Edge cases identified with expected behaviors
- Acceptance criteria defined for each FR
- Out of scope items clearly listed
- Dependencies identified with status

## Anti-Patterns

- Do NOT propose solutions or architecture
- Do NOT include implementation details
- Do NOT make assumptions without asking clarifying questions

## Handoff

**Output:** `{requirements-dir}/REQUIREMENTS.md`

**Next Phase:** forge-design-creation
