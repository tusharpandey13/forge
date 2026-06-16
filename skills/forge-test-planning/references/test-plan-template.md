# Test Plan: [FEATURE NAME]

## Overview

Testing strategy and comprehensive test cases.

## References

- Implementation Plan: `[path]/IMPL-PLAN.md`
- Design (Test Matrix): `[path]/DESIGN.md`
- Requirements: `[path]/REQUIREMENTS.md`

## Test Conventions (from Codebase)

Discovered from existing test files. This drives all test planning.

- Framework: [framework] (e.g., `[path/to/example]`)
- File naming: [pattern] (e.g., `[path/to/example]`)
- Directory structure: [co-located / __tests__ / test/] (e.g., `[path]`)
- Test grouping: [describe/it / test() / func Test*] (e.g., `[example]`)
- Mocking approach: [library, what gets mocked, setup pattern] (e.g., `[path]`)
- Setup/teardown: [pattern] (e.g., `[path]`)
- Assertions: [library/style] (e.g., `[example]`)
- Fixtures/factories: [pattern if any] (e.g., `[path]`)

## Mocking Strategy (from Codebase)

Only mock at boundaries the codebase already mocks. Do NOT invent a mocking strategy.

- [what is mocked]: [how] using [library] (e.g., `[path/to/example]`)
- [what is mocked]: [how] using [library] (e.g., `[path/to/example]`)

## Updated Test Matrix

### From DESIGN.md (baseline)

- [ID] ([UT/FT]): [case] (P0/P1/P2)
- [ID] ([UT/FT]): [case] (P0/P1/P2)

### Additions from IMPL-PLAN.md

- [ID] (from Unit X): [case] — [why implementation revealed this]
- [ID] (from Unit X): [case] — [why implementation revealed this]

---

## Unit Tests

### Suite: [Component/Function Name]

**File:** `[path/to/component.test.*]`
**Target:** `[path/to/component.*]`

#### UT-1: [Test Name — Happy Path]

**Description:** Verifies [behavior]

**Setup:**
```
[Follow codebase setup conventions]
CREATE input = { field: "validValue", count: 5 }
MOCK [dependency] using [codebase pattern]
```

**Execute:**
```
result = CALL targetFunction(input)
```

**Assert:**
```
EXPECT result.status EQUALS "success"
EXPECT result.items HAS_LENGTH 5
EXPECT [mock] CALLED_WITH { id: input.field }
```

---

#### UT-2: [Test Name — Error Path]

**Description:** Verifies error when [condition]

**Setup:**
```
MOCK [dependency] to THROW error
CREATE input = { field: "validValue" }
```

**Execute:**
```
EXPECT CALL targetFunction(input) THROWS [ErrorType]
```

**Assert:**
```
EXPECT error.message CONTAINS "descriptive message"
EXPECT error.code EQUALS "ERROR_CODE"
```

---

### Suite: [Component 2]

**File:** `[path/to/component2.test.*]`

...

---

## Flow Tests

### Suite: [Feature Flow Name]

**File:** `[path/to/feature.flow.test.*]`

#### FT-1: [Complete Happy Path]

**Description:** End-to-end flow for [scenario]

**Dependencies:**
```
[Set up mocks/stubs per codebase conventions]
```

**Setup:**
```
CREATE client/instance with test configuration
```

**Execute:**
```
// Step 1
result1 = CALL client.action1({ data: inputData })
// Step 2
result2 = CALL client.action2(result1.id)
// Step 3
result3 = CALL client.action3(result1.id, { newData })
```

**Assert:**
```
EXPECT result1.status EQUALS "created"
EXPECT result1.id IS_DEFINED
EXPECT result2.status EQUALS "active"
EXPECT result3.status EQUALS "updated"
```

---

#### FT-2: [Error Recovery Flow]

**Description:** Verifies recovery when [condition]

...

---

## Edge Case Tests

### EC-1: [Edge Case Name]

**Type:** Unit / Flow
**Source:** Requirements EC-X / IMPL-PLAN Unit Y

**Setup:**
```
[specific setup for edge condition]
```

**Execute:**
```
[trigger edge case]
```

**Assert:**
```
[expected behavior]
```

---

## Coverage Mapping

### Requirements -> Tests

- FR-1: UT-1, UT-2, FT-1 [covered]
- FR-2: UT-5, FT-2 [covered]
- NFR-1 (performance): FT-5 [covered]
- NFR-2 (security): UT-10, FT-3 [covered]

### Implementation Units -> Tests

- Unit 1: UT-1, UT-2, UT-3 [covered]
- Unit 2: UT-4, UT-5, UT-6 [covered]
- Integration: FT-1, FT-2, FT-3 [covered]

## Test Data

### Fixtures

- [name] (`[path]`): [what it provides]

### Factories

- [name]: [what it generates] — usage: [example]

---

**Created:** [DATE]
**Last Updated:** [DATE]
**Status:** Draft / In Review / Approved
