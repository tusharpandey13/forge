# Implementation Plan: [FEATURE NAME]

## Overview

Brief description of implementation approach.

## References

- Design: `[path]/DESIGN.md`
- Requirements: `[path]/REQUIREMENTS.md`

## Codebase Analysis

### Conventions

- File naming: [pattern] (e.g., `[path/to/example]`)
- Class naming: [pattern] (e.g., `[path/to/example]`)
- Function naming: [pattern] (e.g., `[path/to/example]`)
- Error handling: [pattern] (e.g., `[path/to/example]`)
- Logging: [pattern] (e.g., `[path/to/example]`)

### Reusable Utilities

- [utility name] (`[path]`): [what it does, how to use]
- [utility name] (`[path]`): [what it does, how to use]

## Implementation Units

### Execution Order

Tier 1 (independent, parallelizable):
- Unit 1: [Name]
- Unit 2: [Name]

Tier 2 (depends on Tier 1):
- Unit 3: [Name] (depends on Unit 1)

Tier 3 (depends on Tier 2):
- Unit 4: [Name] (depends on Unit 2, Unit 3)

---

## Unit 1: [Name]

**File:** `[path/to/file]`
**Type:** New / Modify
**Tier:** 1 (independent)
**Depends on:** none

### Purpose

What this unit does and why it exists.

### Pseudocode

```
FUNCTION functionName(param1: Type, param2: Type) -> ReturnType:
    // Validate inputs
    IF param1 is null or undefined:
        THROW InvalidArgumentError("param1 is required")

    // Perform main operation
    intermediateResult = CALL helperFunction(param1)

    // Handle edge cases
    IF intermediateResult is empty:
        RETURN defaultValue

    RETURN intermediateResult
END FUNCTION
```

### Error Handling

- param1 missing → InvalidArgumentError ("param1 is required") — caller provides param
- External API fails → ExternalServiceError ("Service unavailable") — retry with backoff

### Dependencies

Imports:
- `utility` from `[path]`
- `ExternalClient` from `[library]`

Internal:
- Uses Unit X for [purpose]

---

## Unit 2: [Name]

**File:** `[path/to/file]`
**Type:** New / Modify
**Tier:** 1 (independent)
**Depends on:** none

### Purpose

What this unit does.

### Pseudocode

```
CLASS ClassName:
    PRIVATE field1: Type
    PRIVATE field2: Type

    CONSTRUCTOR(config: ConfigType):
        VALIDATE config has required fields
        SET this.field1 = config.value1
        SET this.field2 = config.value2 OR defaultValue

    PUBLIC METHOD methodName(input: InputType) -> OutputType:
        intermediate = PROCESS input using this.field1
        result = TRANSFORM intermediate
        RETURN result

    PRIVATE METHOD helperMethod(data: DataType) -> ResultType:
        processed = APPLY transformation to data
        RETURN processed
END CLASS
```

### Error Handling

- [condition] → [ErrorType] ("[message]") — [recovery]

---

## Configuration & Constants

### New Constants

- MAX_RETRY_COUNT = 3 (`[path]`): Maximum API retry attempts
- DEFAULT_TIMEOUT = 5000 (`[path]`): Default timeout in ms

### New Configuration Options

- configKey (Type, default: "value", validation: non-empty): [purpose]

## File Changes Summary

- `[path/new-file]` (New): [what this file contains]
- `[path/existing]` (Modify): [what changes]

## Integration Points

- [component]: [how it connects] — [special considerations]

## Risks & Mitigations

- [risk] (impact: [H/M/L], likelihood: [H/M/L]): mitigation — [how]

---

**Created:** [DATE]
**Last Updated:** [DATE]
**Status:** Draft / In Review / Approved
