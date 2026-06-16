# Review Checklists

## Design Review

### Completeness
- [ ] All functional requirements from REQUIREMENTS.md addressed
- [ ] All non-functional requirements have explicit solutions
- [ ] Test matrix covers happy path, error paths, and edge cases
- [ ] Wire formats documented for all network calls

### Clarity
- [ ] No ambiguous descriptions in contracts
- [ ] Public contracts fully specified (types, methods, errors)
- [ ] Design decisions documented with rationale
- [ ] Sequence diagrams for multi-component flows

### Correctness
- [ ] Solution actually solves the stated requirements
- [ ] Error handling strategy is complete
- [ ] Breaking changes identified with migration paths

## Implementation Plan Review

### Alignment
- [ ] All design contracts covered
- [ ] Follows codebase conventions (verified by codebase analysis)
- [ ] Uses identified reusable utilities
- [ ] Implementation order respects dependencies

### Quality
- [ ] Pseudocode detailed enough for line-by-line review
- [ ] No DRY violations across units
- [ ] Single responsibility per unit
- [ ] Error handling explicit for every failure path

### Completeness
- [ ] All units have defined file locations
- [ ] Configuration and constants specified
- [ ] Edge cases from requirements handled
- [ ] Parallelism: independent units clearly marked

## Test Plan Review

### Coverage
- [ ] All implementation units have corresponding tests
- [ ] All functional requirements verified by tests
- [ ] All error paths tested
- [ ] All edge cases covered

### Quality
- [ ] Tests are behavior-focused (blackbox)
- [ ] Assertions have precise expected values
- [ ] Mocking follows codebase conventions (not invented)
- [ ] Test patterns match codebase (framework, naming, structure)

### Completeness
- [ ] Coverage mapping shows all requirements tested
- [ ] Fixtures and factories documented

## Code Review

### Correctness
- [ ] Implementation matches IMPL-PLAN pseudocode (deviations documented)
- [ ] Quality gate passes (tests, build, lint)
- [ ] No regressions in existing tests

### Quality
- [ ] Code coverage meets project minimum
- [ ] Clean, readable, maintainable code
- [ ] Consistent error handling
- [ ] Follows project conventions from FORGE-CONFIG.md

### Security & Performance
- [ ] No security vulnerabilities introduced
- [ ] No obvious performance bottlenecks
- [ ] Sensitive data handled appropriately

## Test Review

### Correctness
- [ ] Tests match TEST-PLAN pseudocode
- [ ] All tests pass
- [ ] Coverage target met

### Quality
- [ ] Tests are behavior-focused, not implementation-focused
- [ ] Mocking is minimal (boundaries only)
- [ ] Follows codebase test conventions exactly
- [ ] No flaky patterns (timeouts, race conditions, order dependency)
