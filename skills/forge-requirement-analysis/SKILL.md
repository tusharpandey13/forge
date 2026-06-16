---
name: forge-requirement-analysis
description: Extract feature specs from context files. Use when analyzing requirements, gathering requirements, or working with context files.
license: Proprietary
metadata:
  author: Auth0 SDKs Team <sdks@auth0.com>
---

# Requirement Analysis

Domain expert for extracting complete feature specifications from initial context. The USER is the domain expert with access to Confluence, Slack, and tribal knowledge.

## When to Use

- User asks to analyze or gather requirements
- User references context files
- Starting a new feature that needs requirement documentation

## Context Sources

- `.forge/FORGE-CONFIG.md` — paths, conventions (if exists)
- `.forge/state.json` — current state (if exists)
- `{context-dir}/*.md` — user-provided external context (PRDs, Confluence exports, issues)
  - **Example:** `/Users/alice/project/.forge/features/auth-middleware/context/PRD.md`
- Codebase structure and existing patterns
- Any symlinked directories in the workspace

**NOTE:** The `{feature_dir}` variable is resolved by the orchestrator to an absolute path before dispatch. Examples throughout this skill show both the variable form and concrete paths.

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

Create formal requirements document using the [requirements-template.md](./references/requirements-template.md).

Output: `{feature_dir}/requirement/REQUIREMENTS.md`
- **Variable form (from orchestrator):** `{feature_dir}/requirement/REQUIREMENTS.md`
- **Concrete example:** `/Users/alice/project/.forge/features/auth-middleware/requirement/REQUIREMENTS.md`

### 7. Self-Validate

Re-read the artifact. Verify:
- No `[placeholder]` or `TBD` text remains
- All sections have content
- Cross-reference IDs (FR-X, NFR-X) are consistent
Fix any issues silently.

### 8. Update State

Write output artifact: `{feature_dir}/requirement/REQUIREMENTS.md`

Write `.phase-1-output.json` sidecar (full absolute path provided by orchestrator):
```json
{
  "phase": 1,
  "status": "completed",
  "artifacts": [
    {
      "path": "/Users/alice/project/.forge/features/auth-middleware/requirement/REQUIREMENTS.md",
      "sha": "[git SHA of artifact]",
      "size_bytes": [file size]
    }
  ],
  "decisions": [
    "FR-1 scope clarified",
    "Key constraints identified"
  ],
  "execution_details": {
    "model": "qc-readonly",
    "reasoning_lines": [count],
    "context_usage_percent": [%],
    "elapsed_seconds": [duration]
  }
}
```

**Note:** The orchestrator provides the full output path for `.phase-1-output.json` in the task agent prompt. Example: `/Users/alice/project/.forge/features/auth-middleware/.phase-1-output.json`

**Orchestrator updates state.json** (skill does NOT write to state.json directly)
- Orchestrator reads .phase-1-output.json
- Orchestrator updates state.json with artifacts, decisions, and execution details
- Orchestrator commits to .forge git

## Quality Checks

- All template sections complete
- No placeholder text remains
- Constraints are explicit (performance, security, compatibility, data)
- Edge cases identified with expected behaviors
- Acceptance criteria defined for each FR
- Out of scope items clearly listed
- Dependencies identified with status

## Error Handling

### Before Starting

1. **State.json Missing:**
   - If `.forge/state.json` cannot be found or is invalid JSON
   - **Action:** ERROR: "state.json missing or corrupted. Run /forge to initialize workspace first."
   - **Recovery:** Do not proceed; return error to orchestrator

2. **State.json Invalid:**
   - If `.forge/state.json` parses but has missing required fields
   - **Action:** ERROR: "state.json is malformed (missing required fields: {{ missing_fields }})"
   - **Recovery:** Return error to orchestrator for rollback

3. **Active Feature Not Found:**
   - If state.json exists but no feature has `is_active: true`
   - **Action:** ERROR: "No active feature in state.json. Start a new feature or select one."
   - **Recovery:** Return error; do not generate requirements

4. **Config Not Found:**
   - If `.forge/FORGE-CONFIG.md` is missing
   - **Action:** Note in output: "FORGE-CONFIG.md not found; will attempt config detection"
   - **Recovery:** Run config initialization flow; continue with best-effort detection

### During Execution

5. **Context Directory Not Found:**
   - If specified context directory (from config) does not exist
   - **Action:** WARN: "Context directory not found. Proceeding without external context."
   - **Recovery:** Continue with codebase analysis only

6. **Context Files Unreadable:**
   - If files in context directory cannot be read (permissions, encoding)
   - **Action:** WARN: "Could not read some context files: {{ list }}. Continuing with readable files."
   - **Recovery:** Continue with available context

### Before Completing

7. **Output Path Not Writable:**
   - If `.forge/features/<slug>/requirement/` directory cannot be created or written to
   - **Action:** ERROR: "Cannot write to {{ output_path }}: {{ reason }}"
   - **Recovery:** Return error; do not generate .phase-1-output.json

8. **Placeholder Text Remains:**
   - If REQUIREMENTS.md contains `[TBD]`, `[placeholder]`, or similar markers
   - **Action:** WARN: "Placeholder text found in requirements. Replacing with structured TODOs or escalating."
   - **Recovery:** Either resolve manually or escalate to user with specific locations

## Anti-Patterns

- Do NOT propose solutions or architecture
- Do NOT include implementation details
- Do NOT make assumptions without asking clarifying questions
- Do NOT silently fail — report all errors with clear context

## Handoff

**Output:** `{feature_dir}/requirement/REQUIREMENTS.md` + `.phase-1-output.json`

**Next Phase:** forge-design-creation
