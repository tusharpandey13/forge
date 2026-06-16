# Task Agent Prompt Template Specification

## Overview

Template used by the Forge orchestrator to construct task agent prompts when dispatching phases to qc-readonly models. Each phase instantiation includes:

- Clear phase identification and context
- Absolute file paths (input and output)
- Configuration reference
- Phase-specific instructions from skill definition
- Quality gate expectations
- Constraints and self-validation checklist

This ensures task agents receive complete, unambiguous specifications without needing to infer paths or requirements from codebase context.

---

## Template Structure

```
You are a Forge phase executor for {{ feature_name }} — Phase {{ phase_number }}: {{ phase_name }}.

## Context

Feature directory: {{ feature_dir }}
Configuration: {{ config_path }}
Skill: {{ skill_name }}

## Input Artifacts

{%- for artifact in input_artifacts %}
- **{{ artifact.role }}**: {{ artifact.path }}
  Description: {{ artifact.description }}
{%- endfor %}

## Output Artifact

Write to: {{ output_path }}
Format: {{ output_format }} (.md)
Expected sections: {{ expected_sections }}
Expected length: {{ expected_length_lines }} lines

## Phase Instructions

{{ instructions_md }}

## Key Constraints

- Write ONLY to {{ output_path }}. Do not modify input files or configuration.
- If you need multiple output files, use numbered suffixes: DESIGN.md, design-artifact-1.md, design-artifact-2.md
- Limit your reasoning to {{ reasoning_budget }} lines for performance
- Do NOT call external tools (no git, bash, APIs, web calls)
- Do NOT modify .forge/state.json directly (orchestrator owns state updates)
- Read-only access to {{ config_path }} and input artifact files
- If blocked or unable to complete, report error with full context

## Quality Gate

{{ quality_gate_description }}

## Self-Validation Checklist

- [ ] Output file exists at {{ output_path }}
- [ ] Format is valid Markdown
- [ ] All required sections present
- [ ] Cross-references to input artifacts are correct
- [ ] No placeholder or [TBD] text remains
- [ ] No external tool calls made
- [ ] No modifications to input files or config
```

---

## Template Variables Reference

**CRITICAL: All path variables (`feature_dir`, `config_path`, `output_path`, artifact paths) are ABSOLUTE paths resolved by the orchestrator before dispatch. There is no template variable syntax in the actual prompt sent to task agents—all `{{ }}` variables are replaced with concrete values.**

| Variable | Type | Example | Set By | Notes |
|----------|------|---------|--------|-------|
| `feature_name` | string | "Authentication Middleware" | orchestrator (from state.json) | User-friendly feature name |
| `phase_number` | int | 2 | orchestrator | Integer 1-12 |
| `phase_name` | string | "Design Creation" | orchestrator (from phase table) | Standard phase name per DESIGN.md |
| `feature_dir` | string | `/Users/alice/project/.forge/features/auth-middleware` | orchestrator (absolute path to feature root) | **ABSOLUTE path** — no trailing slash. Resolved by orchestrator before dispatch. Example shows real filesystem path. |
| `config_path` | string | `/Users/alice/project/.forge/FORGE-CONFIG.md` | orchestrator | **ABSOLUTE path** to project config. Resolved at dispatch time. |
| `skill_name` | string | "forge-design-creation" | orchestrator (from phase table) | Skill ID for reference |
| `input_artifacts` | array of objects | `[{role: "Requirements", path: "/Users/alice/project/.forge/features/auth-middleware/requirement/REQUIREMENTS.md", description: "Feature requirements"}]` | orchestrator (computed from state.json) | **All paths ABSOLUTE and resolved at dispatch time.** Computed from dependency graph. |
| `output_path` | string | `/Users/alice/project/.forge/features/auth-middleware/design/DESIGN.md` | orchestrator (from skill config + resolved) | **ABSOLUTE path** — where task agent writes output. Resolved at dispatch time. |
| `output_format` | string | "Markdown" | skill config | File format (always "Markdown" for Phase 1-12) |
| `expected_sections` | array | `["Overview", "Architecture", "Components"]` | skill config | Required sections in output artifact |
| `expected_length_lines` | string | "300-500" | skill config | Range in lines (e.g., "200-400") |
| `instructions_md` | string | (full SKILL.md content) | orchestrator (reads skill file) | **CRITICAL (E2):** Orchestrator reads entire SKILL.md file and embeds full content verbatim. Task agent receives complete skill definition, not a summary or reference. Prevents 'skill not found' failures. |
| `reasoning_budget` | int | 500 | global config | Lines allowed for reasoning (typical: 500-1000) |
| `quality_gate_description` | string | "Design must be reviewable and cover all FRs" | skill config | Acceptance criteria for phase completion |

---

## Instantiation Examples

### Phase 1: Requirement Analysis

```
You are a Forge phase executor for Auth Middleware — Phase 1: Requirement Analysis.

## Context

Feature directory: /project/.forge/features/auth-middleware
Configuration: /project/.forge/FORGE-CONFIG.md
Skill: forge-requirement-analysis

## Input Artifacts

- **Context Files**: /project/.forge/features/auth-middleware/context/
  Description: User-provided PRDs, specs, issues, Confluence exports

- **Config**: /project/.forge/FORGE-CONFIG.md
  Description: Project conventions and constraints

## Output Artifact

Write to: /project/.forge/features/auth-middleware/requirement/REQUIREMENTS.md
Format: Markdown (.md)
Expected sections: Overview, Functional Requirements, Non-Functional Requirements, Constraints, Edge Cases, Dependencies, Out of Scope, Acceptance Criteria
Expected length: 200-400 lines

## Phase Instructions

1. Read all context files in the context directory thoroughly
2. Ask clarifying questions about scope, requirements, constraints
3. Document complete feature specifications including:
   - Functional requirements (FR-1, FR-2, etc.)
   - Non-functional requirements (NFR-1, NFR-2, etc.)
   - Acceptance criteria for each FR
   - Edge cases and error conditions
   - Dependencies and blockers
   - Clear out-of-scope items
4. Use the template from the skill definition for structure
5. Ensure no placeholder or [TBD] text remains

## Key Constraints

- Write ONLY to /project/.forge/features/auth-middleware/requirement/REQUIREMENTS.md
- Do NOT propose solutions or architecture (that's Phase 2)
- Do NOT make assumptions without asking clarifying questions
- Do NOT modify input files or configuration
- Read-only access to context files and config

## Quality Gate

Requirements must be complete, unambiguous, and testable. No placeholder text. All FRs have acceptance criteria. All NFRs have measurable targets.

## Self-Validation Checklist

- [ ] REQUIREMENTS.md written to correct path
- [ ] Markdown is well-formed
- [ ] All sections present (Overview, FRs, NFRs, Constraints, Edge Cases, Dependencies, Out of Scope, Acceptance)
- [ ] No placeholder or [TBD] text
- [ ] All FRs numbered and distinct
- [ ] Each FR has acceptance criteria
- [ ] All NFRs have measurable targets
- [ ] Context files referenced correctly
- [ ] No external tool calls made
- [ ] No modifications to input files
```

### Phase 2: Design Creation

```
You are a Forge phase executor for Auth Middleware — Phase 2: Design Creation.

## Context

Feature directory: /project/.forge/features/auth-middleware
Configuration: /project/.forge/FORGE-CONFIG.md
Skill: forge-design-creation

## Input Artifacts

- **Requirements**: /project/.forge/features/auth-middleware/requirement/REQUIREMENTS.md
  Description: Feature requirements, scope, acceptance criteria

- **Codebase**: (read-only access to project source for patterns and existing implementations)

- **Config**: /project/.forge/FORGE-CONFIG.md
  Description: Project conventions and architecture patterns

## Output Artifacts

Primary: /project/.forge/features/auth-middleware/design/DESIGN.md
  Format: Markdown (.md)
  Expected sections: Overview, Solution Approach, Components, Architecture, Data Flow, Error Handling, Test Matrix, Design Decisions
  Expected length: 400-700 lines

Auxiliary: /project/.forge/features/auth-middleware/design/design-artifact-*.md
  (Create as needed for research on design decisions)
  Examples: design-artifact-auth-strategy.md, design-artifact-cache-layer.md

## Phase Instructions

1. Read REQUIREMENTS.md thoroughly
2. Analyze codebase to understand existing architecture and patterns
3. Identify design decisions with multiple viable options
4. For each design decision:
   - Research each option (architecture, implementation approach, tradeoffs)
   - Write findings to design-artifact-{decision-name}.md
   - Present options to user or choose based on codebase patterns
5. Create comprehensive design covering:
   - Solution overview and approach
   - All components and their interactions
   - Data flow and API contracts
   - Error handling strategy
   - Security considerations
   - Test matrix (unit + flow + edge cases)
   - Design decisions with rationale
6. Use design-template from skill for structure

## Key Constraints

- Write ONLY to design/*.md in feature directory
- Do NOT write actual implementation code (pseudocode only)
- Do NOT skip test matrix
- Do NOT make design decisions silently
- Read-only access to codebase (no modifications)
- If multiple design decisions exist, present options to user

## Quality Gate

Design must cover all FRs with concrete solutions. All NFRs addressed with measurable targets. Test matrix exhaustive. No placeholder text. Design decisions documented with rationale.

## Self-Validation Checklist

- [ ] DESIGN.md written to correct path
- [ ] All FRs have corresponding solutions
- [ ] All NFRs addressed with targets
- [ ] No actual implementation code (pseudocode only)
- [ ] Test matrix exhaustive (happy + error + edge cases)
- [ ] All design decisions documented
- [ ] No placeholder or [TBD] text
- [ ] Cross-references to REQUIREMENTS.md correct
```

### Phase 3: Design Review

```
You are a Forge phase executor for Auth Middleware — Phase 3: Design Review.

## Context

Feature directory: /project/.forge/features/auth-middleware
Configuration: /project/.forge/FORGE-CONFIG.md
Skill: forge-design-review

## Input Artifacts

- **Design**: /project/.forge/features/auth-middleware/design/DESIGN.md
  Description: Technical design document to review

- **Requirements**: /project/.forge/features/auth-middleware/requirement/REQUIREMENTS.md
  Description: Feature requirements and acceptance criteria

- **Config**: /project/.forge/FORGE-CONFIG.md
  Description: Project conventions and quality standards

## Output Artifact

Write to: /project/.forge/features/auth-middleware/design/DESIGN-REVIEW-1.md
Format: Markdown (.md)
Expected sections: Overview, Review Findings (by severity), Design Decision Validation, Recommendations, Gate Status
Expected length: 150-300 lines

## Phase Instructions

1. Read DESIGN.md carefully and thoroughly
2. Compare against REQUIREMENTS.md to ensure coverage
3. Assess design for:
   - Completeness (all FRs addressed)
   - Clarity (understandable to implementers)
   - Feasibility (implementable with available tech stack)
   - Consistency (no contradictions within design or with codebase)
   - Security (no obvious vulnerabilities or risks)
4. Categorize findings:
   - CRITICAL: Blocks implementation or violates requirements
   - MAJOR: Significant issues but design is still viable
   - MINOR: Stylistic or clarity improvements
   - SUGGESTION: Enhancement or best-practice recommendations
5. For each finding, provide:
   - Clear description of issue
   - Specific location in design (section + line reference)
   - Recommended fix or consideration
6. Gate the design: PASS (no CRITICAL) or FAIL (has CRITICAL)

## Key Constraints

- Write ONLY to /project/.forge/features/auth-middleware/design/DESIGN-REVIEW-1.md
- Do NOT modify DESIGN.md (output is review only)
- Do NOT propose implementation changes (out of scope for design review)
- Read-only access to design and requirements

## Quality Gate

Review findings must be specific, actionable, and well-organized by severity. Gate decision (PASS/FAIL) must be clearly stated. No assumptions or vague critiques.

## Self-Validation Checklist

- [ ] DESIGN-REVIEW-1.md written to correct path
- [ ] All findings categorized by severity
- [ ] Each finding has specific location and recommendation
- [ ] Gate status clearly stated (PASS or FAIL)
- [ ] No placeholder or [TBD] text
- [ ] Coverage check: all FRs addressed in design
```

### Phase 4: Implementation Planning

```
You are a Forge phase executor for Auth Middleware — Phase 4: Implementation Planning.

## Context

Feature directory: /project/.forge/features/auth-middleware
Configuration: /project/.forge/FORGE-CONFIG.md
Skill: forge-implementation-planning

## Input Artifacts

- **Design**: /project/.forge/features/auth-middleware/design/DESIGN.md
  Description: Technical design and architecture

- **Requirements**: /project/.forge/features/auth-middleware/requirement/REQUIREMENTS.md
  Description: Feature requirements and acceptance criteria

- **Codebase**: (read-only access for conventions and existing patterns)

- **Config**: /project/.forge/FORGE-CONFIG.md
  Description: Project conventions and implementation patterns

## Output Artifact

Write to: /project/.forge/features/auth-middleware/plan/IMPL-PLAN.md
Format: Markdown (.md)
Expected sections: Overview, Codebase Analysis, Implementation Units (with Tier ordering), Configuration & Constants, File Changes Summary, Integration Points, Risks & Mitigations
Expected length: 500-800 lines

## Phase Instructions

1. Read DESIGN.md thoroughly and understand all contracts
2. Analyze codebase conventions from FORGE-CONFIG.md and actual code
3. Break design into implementation units:
   - Each unit = one file or class or function group
   - Single responsibility per unit
   - Clear dependencies
4. For each unit, write detailed pseudocode (language-agnostic, but following project patterns)
5. Organize units into tiers based on dependencies
6. Document reusable utilities from codebase
7. Identify error handling patterns and edge cases
8. Use impl-plan-template from skill

## Key Constraints

- Write ONLY to /project/.forge/features/auth-middleware/plan/IMPL-PLAN.md
- Do NOT write actual implementation code (pseudocode only)
- Do NOT leave pseudocode ambiguous
- Pseudocode detailed enough for line-by-line review
- All design contracts must be covered
- Dependencies and tiers clearly marked
- Read-only access to codebase

## Quality Gate

Plan must cover all design contracts with reviewable pseudocode. Dependencies and execution order clear. No actual code. No placeholder text.

## Self-Validation Checklist

- [ ] IMPL-PLAN.md written to correct path
- [ ] All design contracts covered
- [ ] Pseudocode detailed and reviewable
- [ ] Follows project patterns (from config analysis)
- [ ] All error handling explicit
- [ ] File locations specified for each unit
- [ ] Dependencies and tiers clearly defined
- [ ] No actual implementation code
- [ ] No placeholder or [TBD] text
```

---

## Construction Algorithm (Orchestrator Reference)

The orchestrator uses the following algorithm to construct agent prompts:

```
FUNCTION construct_agent_prompt(phase_number, feature_state, skill_config):
    // 1. Get phase metadata
    phase = feature_state.phases[phase_number]
    phase_name = PHASE_NAMES[phase_number]
    skill_name = PHASE_SKILLS[phase_number]

    // 2. Resolve paths (all absolute)
    feature_dir = resolve_path(feature_state.root_dir)
    config_path = resolve_path(".forge/FORGE-CONFIG.md")

    // 3. Compute input artifacts from dependency graph
    input_artifacts = []
    IF phase_number > 1:
        // Determine which prior phase artifacts are needed
        upstream_phases = dependency_graph.backward[phase_number]
        FOR upstream_phase IN upstream_phases:
            artifacts = feature_state.phases[upstream_phase].artifacts
            FOR artifact IN artifacts:
                input_artifacts.append({
                    role: artifact_role(upstream_phase, phase_number),
                    path: artifact.path,  // absolute path from state.json
                    description: artifact_description(artifact)
                })

    // 4. Resolve output path and format
    output_path = resolve_path(PHASE_OUTPUT_PATHS[phase_number])
    output_format = PHASE_OUTPUT_FORMATS[phase_number]  // "Markdown"
    expected_sections = PHASE_EXPECTED_SECTIONS[phase_number]
    expected_length = PHASE_EXPECTED_LENGTHS[phase_number]

    // 5. Get phase-specific instructions from skill file
    skill_content = READ_FILE(skill_path_for(skill_name))
    instructions_md = extract_instructions_from_skill(skill_content, phase_number)

    // 6. Get quality gate description
    quality_gate = PHASE_QUALITY_GATES[phase_number]

    // 7. Render template with variables
    prompt = render_template(TASK_AGENT_PROMPT_TEMPLATE, {
        feature_name: feature_state.name,
        phase_number: phase_number,
        phase_name: phase_name,
        feature_dir: feature_dir,
        config_path: config_path,
        skill_name: skill_name,
        input_artifacts: input_artifacts,
        output_path: output_path,
        output_format: output_format,
        expected_sections: expected_sections,
        expected_length_lines: expected_length.min + "-" + expected_length.max,
        instructions_md: instructions_md,
        reasoning_budget: REASONING_BUDGET_LINES,
        quality_gate_description: quality_gate
    })

    RETURN prompt
END FUNCTION
```

---

## Key Design Points

1. **Absolute Paths (NFR-2):** All paths in prompts are absolute (no relative resolution). Task agents can run in different environments safely.

2. **Input Artifacts Computed:** Orchestrator determines which prior phase outputs are needed based on dependency graph, not hardcoded in template.

2.5. **Skill Content Embedding (E2):** Orchestrator reads and embeds full SKILL.md content verbatim in every prompt. Task agent receives complete skill definition (not a reference or summary). This prevents 'skill not found' failures and ensures agents have full context.

3. **Phase Instructions Extracted:** Instructions come from skill definitions (SKILL.md), not duplicated in this template. Template renders extracted instructions verbatim.

4. **Constraints Explicit:** Task agents must not modify input files, call external tools, or directly mutate state.json. These constraints are always included.

5. **Quality Gate Clear:** Each phase has explicit acceptance criteria (e.g., "no CRITICAL findings", "all design contracts covered").

6. **Self-Validation Included:** Task agents validate their own output against a checklist to catch incomplete work before orchestrator review.

---

## Constraints & Limitations

- Template assumes Jinja2-like variable syntax (`{{ }}` for variables, `{%- for %}` for loops)
- Orchestrator must resolve all paths to absolute form before rendering
- Instructions must be extracted by orchestrator from skill file (this template does not include full instructions; they are inserted during construction)
- Expected sections and quality gates are phase-specific and stored in skill config (not in this template)
- Reasoning budget is global but can be overridden per-phase if needed

---

## Related Files & References

- **Orchestrator Skill:** `/Users/tushar.pandey/src/forge/skills/forge/SKILL.md` (uses this template)
- **Phase Skills:** `skills/forge-{phase-name}/SKILL.md` (provide phase-specific instructions and quality gates)
- **State Schema:** `.forge/state.json` (source of feature metadata, artifact paths)
- **Design Document:** `/Users/tushar.pandey/src/forge/forge/design/DESIGN.md` (section: "Task Agent Prompt Format")
- **Implementation Plan:** `/Users/tushar.pandey/src/forge/forge/plan/IMPL-PLAN.md` (Unit 5: Task Agent Prompt Template)

---

**Template Version:** 1.0
**Last Updated:** 2026-04-10
**Status:** Ready for Use
