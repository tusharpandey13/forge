# Test Plan: [FEATURE NAME]

## Overview

Testing strategy and comprehensive test cases for the feature.

## References

- Implementation Plan: `docs/plan/IMPL-PLAN.md`
- Design (Test Matrix): `docs/design/DESIGN.md`
- Requirements: `docs/requirement/REQUIREMENTS.md`

## Test Conventions (from Codebase Analysis)

Analyze existing test files in the codebase and document discovered conventions here. This table drives all test planning decisions.

| Aspect | Convention | Example Location |
|--------|------------|------------------|
| Framework | [jest/vitest/mocha/pytest/go test/...] | [path/to/example.test.ts] |
| File naming | [*.test.ts / *.spec.ts / *_test.go / ...] | [path/to/example] |
| Directory structure | [co-located / __tests__ / test/ / ...] | [path/to/example] |
| Test grouping | [describe/it / test() / func Test* / ...] | [example] |
| Mocking approach | [what library, what gets mocked, setup pattern] | [example] |
| Setup/teardown | [beforeEach/afterEach / setUp/tearDown / ...] | [example] |
| Assertions | [expect / assert / require / ...] | [example] |
| Fixtures/factories | [pattern if any] | [path/to/fixtures] |

## Mocking Strategy (from Codebase)

Document the mocking conventions discovered from existing tests. Do NOT invent a mocking strategy — follow what the codebase already does.

| What is Mocked | How | Library/Pattern | Example Location |
|----------------|-----|-----------------|------------------|
| [e.g., HTTP calls] | [e.g., interceptor, test server, DI] | [e.g., MSW, nock, httptest, unittest.mock] | [path/to/example] |
| [e.g., database] | [e.g., in-memory, test container, mock] | [library] | [path/to/example] |
| [e.g., time] | [e.g., fake timers, clock] | [library] | [path/to/example] |

**Mocking principle:** Only mock at the boundaries the codebase already mocks. Avoid mocking internal modules.

## Updated Test Matrix

### Original Matrix (from DESIGN.md)

| ID | Type | Test Case | Priority |
|----|------|-----------|----------|
| [from design] | UT/FT | [case] | P0/P1/P2 |

### Additions from Implementation Plan

| ID | Source | Test Case | Reason Added |
|----|--------|-----------|--------------|
| [new id] | IMPL-PLAN Unit X | [new case] | [why implementation revealed this need] |

---

## Unit Tests

### Suite: [Component/Function Name]

**File:** `[path/to/component.test.ts]`

**Target:** `[path/to/component.ts]`

#### UT-1: [Test Name - Happy Path]

**Description:** Verifies [what behavior is being tested]

**Setup:**
```
[Follow codebase setup conventions]
CREATE input = { field: "validValue", count: 5 }
MOCK [external dependency] using [codebase mocking pattern]
```

**Execution:**
```
result = CALL targetFunction(input)
```

**Assertions:**
```
EXPECT result.status TO_EQUAL "success"
EXPECT result.items TO_HAVE_LENGTH 5
EXPECT [mock] TO_HAVE_BEEN_CALLED_WITH { id: input.field }
```

**Teardown:**
```
[Follow codebase teardown conventions]
```

---

#### UT-2: [Test Name - Error Path]

**Description:** Verifies error handling when [condition]

**Setup:**
```
MOCK [external dependency] to THROW/RETURN error
CREATE input = { field: "validValue" }
```

**Execution:**
```
EXPECT CALL targetFunction(input) TO_THROW [ErrorType]
```

**Assertions:**
```
EXPECT error.message TO_CONTAIN "descriptive message"
EXPECT error.code TO_EQUAL "ERROR_CODE"
```

---

#### UT-3: [Test Name - Edge Case]

**Description:** Verifies behavior when [edge condition]

**Setup:**
```
CREATE input = { field: "", count: 0 }  // empty/zero values
```

**Execution:**
```
result = CALL targetFunction(input)
```

**Assertions:**
```
EXPECT result TO_EQUAL defaultValue
```

---

### Suite: [Component 2]

**File:** `[path/to/component2.test.ts]`

...

---

## Integration / Flow Tests

### Suite: [Feature Flow Name]

**File:** `[path/to/feature.flow.test.ts]`

#### FT-1: [Flow Name - Complete Happy Path]

**Description:** End-to-end flow for [user scenario]

**Test Dependencies:**
```
[Set up mocks/stubs following codebase conventions discovered above]
[e.g., start test server, configure interceptors, seed test database]
```

**Setup:**
```
[Follow codebase setup conventions]
CREATE client/instance with test configuration
```

**Execution:**
```
// Step 1: Perform action
result1 = CALL client.action1({ data: inputData })

// Step 2: Verify side effect
result2 = CALL client.action2(result1.id)

// Step 3: Follow-up action
result3 = CALL client.action3(result1.id, { newData })
```

**Assertions:**
```
EXPECT result1.status TO_EQUAL "created"
EXPECT result1.id TO_BE_DEFINED

EXPECT result2.status TO_EQUAL "active"

EXPECT result3.status TO_EQUAL "updated"
```

**Teardown:**
```
[Follow codebase teardown conventions]
```

---

#### FT-2: [Flow Name - Error Recovery]

**Description:** Verifies recovery when [error condition occurs]

**Test Dependencies:**
```
[Configure mocks to simulate failure then recovery]
```

**Execution:**
```
result = CALL client.actionWithRetry({ data: inputData })
```

**Assertions:**
```
EXPECT result.status TO_EQUAL "success"
[Verify retry behavior per codebase conventions]
```

---

#### FT-3: [Flow Name - Partial Failure]

**Description:** Verifies behavior when [partial operation fails]

...

---

## Edge Case Tests

### EC-1: [Edge Case Name]

**Type:** Unit / Flow

**Description:** [What edge case this tests]

**Source:** Requirements EC-X / IMPL-PLAN Unit Y

**Setup:**
```
[specific setup to create edge condition]
```

**Execution:**
```
[how to trigger edge case]
```

**Assertions:**
```
[expected behavior assertions]
```

---

## Coverage Mapping

### Requirements -> Tests

| Requirement | Test IDs | Coverage Status |
|-------------|----------|-----------------|
| FR-1 | UT-1, UT-2, FT-1 | Covered |
| FR-2 | UT-5, FT-2 | Covered |
| NFR-1 (performance) | FT-5 | Covered |
| NFR-2 (security) | UT-10, FT-3 | Covered |

### Implementation Units -> Tests

| Impl Unit | Test IDs | Coverage Status |
|-----------|----------|-----------------|
| Unit 1 | UT-1, UT-2, UT-3 | Covered |
| Unit 2 | UT-4, UT-5, UT-6 | Covered |
| Integration | FT-1, FT-2, FT-3 | Covered |

## Test Data

### Fixtures

| Name | Location | Purpose |
|------|----------|---------|
| [fixture name] | [path] | [what it provides] |

### Factories

| Name | Purpose | Example Usage |
|------|---------|---------------|
| [factory name] | [what it generates] | [usage example] |

---

**Created:** [DATE]
**Last Updated:** [DATE]
**Status:** Draft / In Review / Approved
