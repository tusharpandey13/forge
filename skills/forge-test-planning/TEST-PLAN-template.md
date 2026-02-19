# Test Plan: [FEATURE NAME]

## Overview

Testing strategy and comprehensive test cases for the feature.

## References

- Implementation Plan: `docs/plan/IMPL-PLAN.md`
- Design (Test Matrix): `docs/design/DESIGN.md`
- Requirements: `docs/requirement/REQUIREMENTS.md`

## Test Conventions (from Codebase)

| Aspect | Convention | Example |
|--------|------------|---------|
| Framework | [jest/vitest/mocha] | [path/to/example.test.ts] |
| File naming | [*.test.ts / *.spec.ts] | [path/to/example] |
| Describe blocks | [pattern] | [example] |
| Mocking approach | [pattern] | [example] |
| Setup/teardown | [beforeEach/afterEach pattern] | [example] |
| Assertions | [expect style] | [example] |

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
MOCK externalDependency to return { success: true, data: mockData }
CREATE input = { field: "validValue", count: 5 }
```

**Execution:**
```
result = CALL targetFunction(input)
```

**Assertions:**
```
EXPECT result.status TO_EQUAL "success"
EXPECT result.items TO_HAVE_LENGTH 5
EXPECT externalDependency TO_HAVE_BEEN_CALLED_WITH { id: input.field }
```

**Teardown:**
```
RESTORE all mocks
```

---

#### UT-2: [Test Name - Error Path]

**Description:** Verifies error handling when [condition]

**Setup:**
```
MOCK externalDependency to THROW new Error("Service unavailable")
CREATE input = { field: "validValue" }
```

**Execution:**
```
EXPECT CALL targetFunction(input) TO_THROW ExternalServiceError
```

**Assertions:**
```
EXPECT error.message TO_CONTAIN "Service unavailable"
EXPECT error.code TO_EQUAL "EXTERNAL_SERVICE_ERROR"
EXPECT externalDependency TO_HAVE_BEEN_CALLED_TIMES 3  // retries
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

## Flow Tests (Pseudo-E2E)

### Suite: [Feature Flow Name]

**File:** `[path/to/feature.flow.test.ts]`

#### FT-1: [Flow Name - Complete Happy Path]

**Description:** End-to-end flow for [user scenario]

**HTTP Mock Handlers:**
```
HANDLER POST /api/resource:
    IF request.body.action == "create":
        RESPOND 201 {
            id: "generated-id",
            status: "created",
            data: request.body.data
        }
    ELSE:
        RESPOND 400 { error: "invalid_action" }

HANDLER GET /api/resource/:id:
    RESPOND 200 {
        id: params.id,
        status: "active",
        details: { ... }
    }

HANDLER PUT /api/resource/:id:
    RESPOND 200 {
        id: params.id,
        status: "updated"
    }
```

**Setup:**
```
START mock server with handlers
CREATE client = new FeatureClient(config)
```

**Execution:**
```
// Step 1: Create resource
createResult = CALL client.create({ data: inputData })

// Step 2: Verify creation
getResult = CALL client.get(createResult.id)

// Step 3: Update resource
updateResult = CALL client.update(createResult.id, { newData })

// Step 4: Final verification
finalResult = CALL client.get(createResult.id)
```

**Assertions:**
```
EXPECT createResult.status TO_EQUAL "created"
EXPECT createResult.id TO_BE_DEFINED

EXPECT getResult.status TO_EQUAL "active"

EXPECT updateResult.status TO_EQUAL "updated"

EXPECT finalResult.details TO_MATCH { newData properties }

EXPECT mock POST /api/resource TO_HAVE_BEEN_CALLED_TIMES 1
EXPECT mock GET /api/resource/:id TO_HAVE_BEEN_CALLED_TIMES 2
EXPECT mock PUT /api/resource/:id TO_HAVE_BEEN_CALLED_TIMES 1
```

---

#### FT-2: [Flow Name - Error Recovery]

**Description:** Verifies recovery when [error condition occurs]

**HTTP Mock Handlers:**
```
LET callCount = 0

HANDLER POST /api/resource:
    callCount++
    IF callCount < 3:
        RESPOND 500 { error: "server_error" }
    ELSE:
        RESPOND 201 { id: "recovered-id", status: "created" }
```

**Execution:**
```
result = CALL client.createWithRetry({ data: inputData })
```

**Assertions:**
```
EXPECT result.status TO_EQUAL "created"
EXPECT mock POST /api/resource TO_HAVE_BEEN_CALLED_TIMES 3
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

### Requirements → Tests

| Requirement | Test IDs | Coverage Status |
|-------------|----------|-----------------|
| FR-1 | UT-1, UT-2, FT-1 | Covered |
| FR-2 | UT-5, FT-2 | Covered |
| NFR-1 (performance) | FT-5 | Covered |
| NFR-2 (security) | UT-10, FT-3 | Covered |

### Implementation Units → Tests

| Impl Unit | Test IDs | Coverage Status |
|-----------|----------|-----------------|
| Unit 1 | UT-1, UT-2, UT-3 | Covered |
| Unit 2 | UT-4, UT-5, UT-6 | Covered |
| Integration | FT-1, FT-2, FT-3 | Covered |

## Test Data

### Fixtures

| Name | Location | Purpose |
|------|----------|---------|
| validUserFixture | `__fixtures__/user.ts` | Standard valid user object |
| errorResponseFixture | `__fixtures__/errors.ts` | API error response shapes |

### Factories

| Name | Purpose | Example Usage |
|------|---------|---------------|
| createUser | Generate user with overrides | `createUser({ name: "Test" })` |
| createApiResponse | Generate API response shape | `createApiResponse({ status: 200 })` |

## Mocking Strategy

| Dependency | Mock Type | Reason |
|------------|-----------|--------|
| HTTP APIs | HTTP mocking library (e.g., MSW, nock) | Standard for network isolation |
| Date/Time | jest.useFakeTimers | Deterministic time-based tests |
| Random | jest.spyOn | Deterministic random values |

**Note:** Avoid mocking internal modules. Only mock external boundaries.

---

**Created:** [DATE]
**Last Updated:** [DATE]
**Status:** Draft / In Review / Approved
