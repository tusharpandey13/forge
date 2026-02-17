---
name: forge-requirement-analysis
description: Extract feature specs from context files. Use when analyzing requirements, gathering requirements, or working with docs/context/ files.
---

# Requirement Analysis

Domain expert for extracting complete feature specifications from initial context. The USER is the domain expert with access to Confluence, Slack, and tribal knowledge.

## When to Use

- User asks to analyze requirements or gather requirements
- User references `docs/context/` files
- Starting a new feature that needs requirement documentation

## Context Sources

- `docs/context/*.md` - User-provided external context (PRDs, Confluence exports, issue descriptions)
- Codebase structure and existing patterns
- Any symlinked directories in the workspace

## Process

**MANDATORY FIRST OUTPUT:**
```
FORGE :: REQUIREMENT ANALYSIS
```

1. **Parse Context:** Read all files in `docs/context/` thoroughly
2. **Analyze Codebase:** Identify related patterns, existing implementations, and conventions
3. **Identify Gaps:** Find missing constraints, unclear scope, undefined behaviors, edge cases
4. **Ask Clarifying Questions:** Generate 5-10 specific questions for the user (they have Confluence/Slack access)
5. **Iterate:** Continue until requirements are complete and unambiguous
6. **Document:** Create formal requirements document

**Important:** This phase focuses on WHAT is needed, NOT on solutions or implementation.

## Deliverables

- `docs/requirement/REQUIREMENTS.md` - Use template at [REQUIREMENTS-template.md](./REQUIREMENTS-template.md)
- Additional supporting docs in `docs/requirement/` if needed

## Quality Checks

- [ ] All template sections are complete
- [ ] No "TBD" or placeholder text remains
- [ ] External references documented with URLs
- [ ] Constraints are explicit (performance, security, compatibility, data)
- [ ] Edge cases are identified with expected behaviors
- [ ] Acceptance criteria defined for each FR
- [ ] Out of scope items clearly listed
- [ ] Dependencies identified with status

## Anti-Patterns

- Do NOT propose solutions or architecture
- Do NOT include implementation details
- Do NOT make assumptions without asking clarifying questions

## Handoff

**Output:** `docs/requirement/REQUIREMENTS.md` + supporting docs

**Next Phase:** forge-design-creation skill
