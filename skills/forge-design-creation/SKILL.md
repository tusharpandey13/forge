---
name: forge-design-creation
description: Create technical design from requirements. Use when creating design docs, solution architecture, or working with REQUIREMENTS.md.
license: Proprietary
metadata:
  author: Auth0 SDKs Team <sdks@auth0.com>
---

# Design Creation

Solution architect creating technical design from requirements. Produces implementation blueprint with interactive design decision research.

## When to Use

- User asks to create a design or design doc
- User references REQUIREMENTS.md
- Moving from requirements to solutioning

## Context Sources

- `.forge/FORGE-CONFIG.md` — conventions, paths
- `.forge/state.json` — current state
- `{feature_dir}/requirement/REQUIREMENTS.md` — primary input
  - Example: `/Users/alice/project/.forge/features/auth-middleware/requirement/REQUIREMENTS.md`
- `{feature_dir}/requirement/*.md` — supporting requirement docs
- `{context-dir}/*.md` — original context if needed
- Codebase architecture patterns and existing implementations

See references/shared-phase-spec.md § feature-dir-note

## Process

See references/shared-phase-spec.md § mandatory-first-output — emit `FORGE :: DESIGN CREATION`

### 1. Verify Prerequisites

Via `forge slice` / `forge ref <feat> <artifact>` — confirm Phase 1 (Requirements) status is "completed" or "approved". Read FORGE-CONFIG.md for conventions and paths.

**Capability check.** Detect what is available; state what you can/cannot verify:
- `gh` CLI present and authed (`gh auth status`)? Needed to verify SDK/method names against live repos.
  - Private/internal repo inaccessible? If `gh auth status` lists a work account (`_atko`/`@okta`), `gh auth switch` to it and retry. If only personal account → ask user to `gh auth login` work account.
- Required source/context docs readable at paths?
- If missing → consult Degradation Table, annotate gaps, proceed in degraded mode.

**Degradation Table** — annotate gaps; never fill with guesses:

| Missing | Fallback | Mark in DESIGN.md |
|---------|----------|-------------------|
| `gh` CLI / live-repo access | Codebase + convention docs only | "names unverified against live repos" |
| Private/internal repo access | `gh auth switch` to `_atko`/`@okta`; if absent, ask user | — |
| Linked source/context doc | Ask user to paste; proceed offline | "source unavailable, proposed" |
| Codebase unreadable | Requirements + architectural guidelines | "design not validated against existing code" |

### 2. Review Requirements

Understand every FR and NFR in REQUIREMENTS.md.

**Multi-source reconcile (mini-gate).** When inputs include multiple sources (REQUIREMENTS.md + supporting docs, original context, PRD/RFD/spec, PoC) — they will disagree. Before designing:
- List every cross-doc contradiction (contract/endpoint naming, error codes, parameter naming, defaults, scope, behavioral semantics)
- Flag every conflict; never silently pick a winner. Per conflict: value per source (name the doc) + recommended resolution with reasoning
- Present conflict list + open questions → stop for user to resolve or defer
- Single consistent source → skip; note "single source, no reconciliation needed"

### 3. Analyze Codebase

Study existing architecture, patterns, similar implementations.

**Verify names against live code.** Convention docs and prior memory are starting points, not truth. Every method/type/parameter name you reuse or extend must be verified against actual current source (read file, or `gh`-search live repo for SDK work). Never trust a remembered or documented signature without confirming it exists as written.

### 4. Identify Design Decisions

Identify decisions where:
- Multiple viable approaches exist
- Choice significantly affects architecture
- Confidence in best approach is low

### 5. Research Design Decisions

Per decision with multiple viable options:

1. Spawn research subagent per option (parallel when possible)
2. Each subagent investigates: approach mechanics, implementation strategy, optimization potential, tradeoffs/risks, real-world precedent
3. Each subagent writes findings to: `{feature_dir}/design/design-artifact-{decision-name}.md`
4. Synthesize into comparison

### 6. Present Design Decisions to User

Present all independent DDs simultaneously:

```
FORGE :: DESIGN DECISIONS

DD-1: Authentication Strategy
  Option A: Middleware approach
    - Matches existing codebase pattern; low impl complexity
    - Details: /Users/alice/project/.forge/features/auth-middleware/design/design-artifact-auth-middleware.md
  Option B: Decorator pattern
    - More flexible for per-route config; medium impl complexity
    - Details: /Users/alice/project/.forge/features/auth-middleware/design/design-artifact-auth-decorator.md
  Recommendation: Option A

Choose for each, or say "go with recommendations."
```

Dependent DDs (DD-3 depends on DD-1) → present after dependency resolved.

### 7. Create Design

DESIGN.md is a **stakeholder-facing reference document** read by SEs, PMs, EMs. Clean, externally-shareable spec — not an internal work product. Apply all Authoring Standards below.

With user's DD choices, create the full design:

1. Define public contracts (every reused/extended name **verified against live code**, not from memory):
   - Types and interfaces (real target-language code, e.g. TypeScript)
   - Methods and functions (signatures, behavior, errors)
   - Error types (codes, conditions, recovery)
   - Constants and configuration options
2. Specify the **Implementation** (component behavior + real code changes; focus on what changes and why)
3. Document wire formats for all network calls
4. Create test matrix (unit + flow + edge cases) as **tables only**: case ID, scenario, expectation. No code.
5. Document design decisions, **ordered by impact** (highest first), with rationale and chosen approach
6. Create sequence diagrams (mermaid) for every multi-component interaction

Output: `{feature_dir}/design/DESIGN.md` using [design-template.md](./references/design-template.md)

### 8. Self-Validate

See references/shared-phase-spec.md § self-validate. Also run **leak scan** (see Authoring Standards). Do NOT write self-validation checklist, status footer, or "validated against" metadata into DESIGN.md.

## Authoring Standards (MANDATORY for DESIGN.md)

DESIGN.md is shared with engineers, PMs, EMs. Clean, confident, free of internal scaffolding.

**Audience and tone**
- Write for SEs/PMs/EMs reading for understanding. Focus on approach and what is changing.
- Prose is purely technical. Opening overview may be lightly framed; body stays factual.
- Confident, decided language. Never imply ambiguity: no "maybe", "possibly", "to be decided", "we might", "could potentially", "it is unclear".

**Strip internal scaffolding**
- No internal references in prose or code: no `.forge/` paths, `state.json`, `REQUIREMENTS.md`/`PRD`/artifact filenames, internal initiative names, internal tooling names, individual names, product codenames.
- No internal status markers: no `(LOCKED)`, `(deferred)`, `(approved)`, FR-1/NFR-2/OQ-7 tags in prose. Use plain language ("the SDK requires...", not "per FR-1c").
- Replace internal references in code comments/identifiers with neutral placeholders (e.g. `CLIENT_ID`).

**Structure (every major section)**
- Every major section opens with a table enumerating its contents
- Each content row has a short ID (C1, W1, I1, T1, D1, S1). Do NOT add a "Section" column duplicating the ID; embed ID in subsection heading: `### 3.C1 Error classes`. The `{section-number}.{ID}` form is the reference key.
- Top-level Section Index keeps plain `Section` column (numbered 1, 2, 3…)
- Sections enumerating nothing may use plain `N.1` numbering without IDs

**Every subsection format (in order)**
1. Heading (numbered)
2. Short description (max 2 lines)
3. Code changes (real code)
4. Further detail: descriptions, tables, lists, prose

**Code** — real target-language code (TypeScript for these SDKs), not pseudocode. Lead with what changed; use tables and progressive disclosure.

**Diagrams** — mermaid only. No ASCII line art. Prefer several focused diagrams over one dense one.

**Test matrix** — tables only. Columns: case ID, scenario, expectation. No test code.

**Design decisions** — ordered by impact. Summary table with impact rating; optional per-decision subsections below.

**Formatting hygiene (remove AI-smell)**
- Replace every em dash (`—`) with colon (`:`) or restructure sentence
- Avoid: "In conclusion", "It's worth noting", "Let's dive in", overuse of bold, triadic "X, Y, and Z" filler
- No document footer (no "Created/Status/Next Phase" trailer, no horizontal-rule sign-off)

**Leak scan (run during self-validate):** grep artifact for `—`, `.forge`, `state.json`, `FR-`/`NFR-`/`OQ-`/`DD-` inline tags, `LOCKED`, ticket IDs, internal names. Resolve every hit.

### 9. Update State

Write `.phase-2-output.json` sidecar (schema: see references/shared-phase-spec.md § sidecar-schema).
Phase-specific: include all design-artifact files in artifacts[]; decisions[] = DD choices with rationale.

See references/shared-phase-spec.md § orchestrator-note

## Quality Checks

- Every FR has a corresponding solution
- NFRs addressed with measurable targets
- Test matrix exhaustive (happy + error + edge)
- Design decisions documented with rationale
- Contracts use real target-language code (surface only, not full impl)
- Wire formats complete for all network calls
- Error types and handling defined
- Breaking changes identified with migration paths

## Error Handling

### Before Starting

See references/shared-phase-spec.md § error-cases (cases 1–4).

- Case 2 for this phase: Phase 1 (Requirements) must be "completed" or "approved"
- Case 3 (Config not found) → WARN: "FORGE-CONFIG.md not found. Using best-effort codebase analysis." Continue.

### During Execution

- **Codebase unreadable** → WARN: "Could not fully analyze codebase. Proceeding with architectural guidelines only."
- **Design complexity high** (>10 independent decisions) → WARN: "Many design decisions ({{ count }}). Grouping dependent ones." Cluster; present in batches.

### Before Completing

- **Output not writable** → see § error-cases case 4
- **Placeholder or unresolved decisions** → WARN: "Unresolved items: {{ list }}. Escalating for user clarification."

## Common Mistakes

- Writing full implementations — show surface (signatures, types, what changes), not every line
- Trusting remembered/documented names — verify every reused name against live code
- Silently resolving source conflicts — surface every conflict at reconcile mini-gate
- Inventing content for missing source — degrade and annotate per Degradation Table
- Skipping the test matrix
- Making design decisions silently
- Silent failure
- Leaking internal scaffolding — run leak scan before finishing

## Handoff

**Output:** `{feature_dir}/design/DESIGN.md` + `design-artifact-*.md` + `.phase-2-output.json`
**Next Phase:** forge-review (design review)
