---
name: forge-design-creation
description: Create technical design from requirements. Use when creating design docs, solution architecture, or working with REQUIREMENTS.md.
license: Proprietary
metadata:
  author: Auth0 SDKs Team <sdks@auth0.com>
---

# Design Creation

Solution architect creating technical design from requirements. Produces the blueprint for implementation, with interactive design decision research.

## When to Use

- User asks to create a design or design doc
- User references REQUIREMENTS.md
- Moving from requirements phase to solutioning

## Context Sources

- `.forge/FORGE-CONFIG.md` — conventions, paths
- `.forge/state.json` — current state
- `{feature_dir}/requirement/REQUIREMENTS.md` — primary input (absolute path from orchestrator)
  - **Example:** `/Users/alice/project/.forge/features/auth-middleware/requirement/REQUIREMENTS.md`
- `{feature_dir}/requirement/*.md` — supporting requirement docs
- `{context-dir}/*.md` — original context if needed
- Codebase architecture patterns and existing implementations

**NOTE:** The `{feature_dir}` variable is resolved by the orchestrator to an absolute path before dispatch. Examples show both variable and concrete forms.

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: DESIGN CREATION
```

### 1. Verify Prerequisites

Read .forge/state.json. Confirm Phase 1 (Requirements) status is "completed" or "approved".
Read FORGE-CONFIG.md for conventions and paths.

**Capability check.** Phase 1 (requirement analysis) runs a capability preflight; design adds the design-specific checks. Detect what is available before designing, and state what you can and cannot verify:
- `gh` CLI present and authed (`gh auth status`)? Needed to verify SDK/method names against live repos.
  - **Private/internal repo not accessible?** Auth0 SDK repos are often org-internal. If `gh auth status` lists a work account (username/email contains `_atko` or `@okta`), `gh auth switch` to it and retry. If only a personal account is logged in, ask the user to `gh auth login` the work account rather than guessing names blind.
- Required source/context docs readable at their paths?
- If something is missing, consult the **Degradation Table** below, state the impact, annotate gaps visibly in the design, and proceed in degraded mode rather than failing.

**Degradation Table** — annotate gaps; never fill them with guesses:

| Missing | Fallback | Mark in DESIGN.md |
|---------|----------|-------------------|
| `gh` CLI / live-repo access | Use codebase + convention docs only | "names unverified against live repos" |
| Private/internal repo access | `gh auth switch` to `_atko`/`@okta` work account; if absent, ask user to `gh auth login` | — |
| A linked source/context doc | Ask the user to paste it; proceed offline | mark the dependent section "source unavailable, proposed" |
| Codebase unreadable | Design from requirements + architectural guidelines | "design not validated against existing code" |

### 2. Review Requirements

Understand every FR and NFR in REQUIREMENTS.md.

**Multi-source reconcile (mini-gate).** When the inputs include more than one source (REQUIREMENTS.md plus supporting requirement docs, original context docs, PRD/RFD/spec, or a PoC), the sources **will** disagree. Before designing:
- List every cross-doc contradiction (contract/endpoint naming, error codes/format, parameter naming, defaults/required-ness, scope, behavioral semantics).
- **Flag every conflict; never silently pick a winner.** For each: the value per source (name the doc), and a recommended resolution with reasoning.
- Present the conflict list + open questions and stop for the user to resolve or defer.
- Single consistent source → skip; note "single source, no reconciliation needed."

### 3. Analyze Codebase

Study existing architecture, patterns, and similar implementations.

**Verify names against live code.** Existing-codebase conventions drift; a convention doc or prior memory is a starting point, not truth. Every method/type/parameter name you reuse or extend must be verified against the actual current source (read the file, or `gh`-search the live repo for SDK work). Do not trust a remembered or documented signature without confirming it exists as written.

### 4. Identify Design Decisions

As you design the solution, identify decisions where:
- Multiple viable approaches exist
- The choice significantly affects architecture
- Confidence in the best approach is low

### 5. Research Design Decisions

For each design decision with multiple viable options:

1. Spawn a research subagent per option (parallel when possible)
2. Each subagent investigates:
   - How the approach works
   - Implementation strategy
   - Optimization potential
   - Tradeoffs and risks
   - Real-world precedent
3. Each subagent writes findings to: `{feature_dir}/design/design-artifact-{decision-name}.md`
4. Synthesize findings into a comparison

### 6. Present Design Decisions to User

Present all independent DDs simultaneously:

```
FORGE :: DESIGN DECISIONS

DD-1: Authentication Strategy
  Option A: Middleware approach
    - Matches existing codebase pattern
    - Low implementation complexity
    - Details: /Users/alice/project/.forge/features/auth-middleware/design/design-artifact-auth-middleware.md
  Option B: Decorator pattern
    - More flexible for per-route config
    - Medium implementation complexity
    - Details: /Users/alice/project/.forge/features/auth-middleware/design/design-artifact-auth-decorator.md
  Recommendation: Option A

DD-2: Cache Layer
  Option A: Redis with TTL
    - Details: /Users/alice/project/.forge/features/auth-middleware/design/design-artifact-cache-redis.md
  Option B: In-memory LRU
    - Details: /Users/alice/project/.forge/features/auth-middleware/design/design-artifact-cache-inmemory.md
  Recommendation: Option A

Choose for each, or say "go with recommendations."
```

**(All paths are absolute, resolved by orchestrator at dispatch time)**

For dependent DDs (DD-3 depends on DD-1 choice): present after the dependency is resolved.

### 7. Create Design

DESIGN.md is a **stakeholder-facing reference document** read by SEs, PMs, and EMs. It must read as a clean, externally-shareable spec, not an internal work product. Apply all the authoring standards in **§ Authoring Standards** below.

With user's DD choices, create the full design:

1. Define public contracts (every reused/extended name **verified against live code** per step 3, not from memory):
   - Types and interfaces (real target-language code, e.g. TypeScript)
   - Methods and functions (signatures, behavior, errors)
   - Error types (codes, conditions, recovery)
   - Constants and configuration options
2. Specify the **Implementation** (component behavior + real code changes; focus on what changes and why, not on reproducing every line)
3. Document wire formats for all network calls
4. Create test matrix (unit + flow + edge cases) as **tables only**: case ID, scenario, expectation. No code.
5. Document design decisions, **ordered by impact** (highest first), with rationale and the chosen approach
6. Create sequence diagrams (mermaid) for every multi-component interaction

Output: `{feature_dir}/design/DESIGN.md` using [design-template.md](./references/design-template.md)
- **Variable form:** `{feature_dir}/design/DESIGN.md`
- **Concrete example:** `/Users/alice/project/.forge/features/auth-middleware/design/DESIGN.md`

### 8. Self-Validate

Re-read the artifact and silently fix any issues. Verify:
- No `[placeholder]` or `TBD` text remains
- All requirements have corresponding solutions
- Cross-reference IDs resolve to defined items
- Every authoring standard in the section below is satisfied (run the leak scan)

The self-validation is a process step only. **Do NOT write a self-validation checklist, status footer, or any "validated against" metadata into DESIGN.md itself.**

## Authoring Standards (MANDATORY for DESIGN.md)

DESIGN.md is shared with other engineers, PMs, and EMs. It must be clean, confident, and free of internal scaffolding. Apply every rule:

**Audience and tone**
- Write for SEs/PMs/EMs reading for understanding. Focus on **approach and what is changing**, not on code volume.
- Prose explaining changes is **purely technical**, not marketing. The opening overview may be lightly framed for readers, but body sections stay factual.
- Use confident, decided language. **Never imply ambiguity or indecision**: no "maybe", "possibly", "to be decided", "we might", "could potentially", "it is unclear".

**Strip internal scaffolding**
- Remove all internal references from prose AND code: no `.forge/` paths, `state.json`, `REQUIREMENTS.md`/`PRD`/artifact filenames, Jira/ticket IDs (e.g. `ROAD-####`, `SDK-####`, `SDKREQ-###`), internal initiative names, internal tooling names, individual people's names, or product codenames.
- Remove internal status markers: no `(LOCKED)`, `(deferred)`, `(approved)`, requirement/decision tags like `FR-1`/`NFR-2`/`OQ-7` in prose. Stakeholders do not need them. Use plain language ("the SDK requires...", not "per FR-1c").
- Replace internal references in code comments/identifiers with neutral placeholders (e.g. `CLIENT_ID`, "the prior authentication client").

**Structure (every major section)**
- Every major section opens with a **table enumerating its contents** (e.g. the Public Contracts section lists each contract change as a row; the Implementation section lists each component).
- Each content row carries a short **ID** (e.g. `C1`, `W1`, `I1`, `T1`, `D1`, `S1`). **Do NOT add a separate "Section" column** that duplicates the ID; instead embed the ID in the subsection heading: `### 3.C1 Error classes`, `### 5.I1 ...`. The `{section-number}.{ID}` form is the reference key.
- The only table that keeps a plain `Section` column is the top-level **Section Index** at the document start (numbered 1, 2, 3...).
- Sections that enumerate nothing (e.g. a short Architecture overview) may use plain `N.1` numbering without IDs.

**Every subsection format (in order)**
1. Heading (numbered)
2. Short description (max 2 lines)
3. Code changes (real code)
4. Further detail: descriptions, tables, lists, prose

**Code**
- Use **real target-language code** (TypeScript for these SDKs), not pseudocode.
- Code explanation language is purely technical. Lead with what changed; use tables and progressive disclosure for detail.

**Diagrams**
- Use **mermaid for all diagrams**. No ASCII line art. Keep diagrams clean and uncluttered (prefer several focused diagrams over one dense one).

**Test matrix**
- Tables only. Columns: case ID, scenario, expectation. **No test code.**

**Design decisions**
- Order by impact/importance (highest first). A summary table lists each decision with an impact rating; optional per-decision subsections provide context below the table.

**Formatting hygiene (remove AI-smell)**
- Replace every em dash (`—`) with a colon (`:`) or restructure the sentence.
- Avoid formulaic AI patterns ("In conclusion", "It's worth noting", "Let's dive in", overuse of bold, triadic "X, Y, and Z" filler).
- **No document footer** (no "Created/Status/Next Phase" trailer, no horizontal-rule sign-off block).

**Leak scan (run during self-validate):** grep the artifact for `—`, `.forge`, `state.json`, requirement/decision tags (`FR-`, `NFR-`, `OQ-`, `DD-` used as inline tags), `LOCKED`, ticket IDs, and internal names. Resolve every hit before finishing.

### 9. Update State

Write output artifacts:
- `{feature_dir}/design/DESIGN.md`
- `{feature_dir}/design/design-artifact-*.md` (one per design decision researched)

Write `.phase-2-output.json` sidecar in `{feature_dir}/`:
```json
{
  "phase": 2,
  "status": "completed",
  "artifacts": [
    {
      "path": "{feature_dir}/design/DESIGN.md",
      "sha": "[git SHA]",
      "size_bytes": [size]
    },
    {
      "path": "{feature_dir}/design/design-artifact-auth-middleware.md",
      "sha": "[git SHA]",
      "size_bytes": [size]
    }
  ],
  "decisions": [
    "DD-1: Middleware pattern (matches codebase)",
    "DD-2: JWT with RS256 (per security requirements)"
  ],
  "execution_details": {
    "model": "qc-readonly",
    "reasoning_lines": [count],
    "context_usage_percent": [%],
    "elapsed_seconds": [duration]
  }
}
```

**Orchestrator updates state.json** (skill does NOT write to state.json directly)
- Orchestrator reads .phase-2-output.json
- Orchestrator updates state.json with artifacts and decisions
- Orchestrator commits to .forge git

## Quality Checks

- Every FR has a corresponding solution
- NFRs addressed with measurable targets
- Test matrix is exhaustive (happy + error + edge)
- Design decisions documented with rationale
- Contracts use real target-language code (per Authoring Standards); not full implementations — focus on what changes
- Wire formats complete for all network calls
- Error types and handling strategy defined
- Breaking changes identified with migration paths

## Error Handling

### Before Starting

1. **State.json Missing or Invalid:**
   - If `.forge/state.json` cannot be found or is corrupted
   - **Action:** ERROR: "state.json missing or corrupted. Run /forge to reinitialize."
   - **Recovery:** Do not proceed; return error

2. **Prerequisite Phase Not Complete:**
   - If Phase 1 (Requirements) status is not "completed" or "approved"
   - **Action:** ERROR: "Phase 1 (Requirements) must be completed first. Current status: {{ phase_1.status }}"
   - **Recovery:** Return error; do not start design

3. **REQUIREMENTS.md Missing:**
   - If input requirements file does not exist at expected path
   - **Action:** ERROR: "REQUIREMENTS.md not found at {{ expected_path }}"
   - **Recovery:** Return error; escalate to orchestrator

4. **Config Not Found:**
   - If `.forge/FORGE-CONFIG.md` missing
   - **Action:** WARN: "FORGE-CONFIG.md not found. Using best-effort codebase analysis."
   - **Recovery:** Continue with codebase patterns only

### During Execution

5. **Codebase Unreadable:**
   - If codebase cannot be analyzed (permissions, encoding)
   - **Action:** WARN: "Could not fully analyze codebase. Proceeding with architectural guidelines only."
   - **Recovery:** Continue with design best practices

6. **Design Complexity High:**
   - If design decisions too numerous to present at once (>10 independent decisions)
   - **Action:** WARN: "Many design decisions identified ({{ count }}). Grouping dependent ones."
   - **Recovery:** Cluster decisions; present in batches

### Before Completing

7. **Output Path Not Writable:**
   - If `.forge/features/<slug>/design/` cannot be created or written to
   - **Action:** ERROR: "Cannot write to {{ output_path }}: {{ reason }}"
   - **Recovery:** Return error; do not complete phase

8. **Placeholder Text or Ambiguity:**
   - If DESIGN.md contains `[TBD]`, unresolved design decisions, or unclear contracts
   - **Action:** WARN: "Unresolved items in design: {{ list }}. Escalating for user clarification."
   - **Recovery:** List specific locations; ask for guidance before finalizing

## Common Mistakes

- **Writing full implementations.** Contracts use real target-language code, but show the *surface* (signatures, types, what changes) — not every line of the implementation.
- **Trusting remembered/documented names.** Verify every reused method/type/parameter name against live code (`gh`-search for SDK work). Conventions drift.
- **Silently resolving a source conflict.** When inputs disagree, surface every conflict at the reconcile mini-gate; let the user decide.
- **Inventing content for a missing source.** Degrade and annotate per the Degradation Table; never guess.
- **Skipping the test matrix.**
- **Making design decisions silently.** Present options when multiple viable approaches exist.
- **Silent failure.** Report all errors with clear context.
- **Leaking internal scaffolding.** Run the leak scan (Authoring Standards) before finishing.

## Handoff

**Output:** `{feature_dir}/design/DESIGN.md` + `design-artifact-*.md` files + `.phase-2-output.json`

**Next Phase:** forge-review (design review)
