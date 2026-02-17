# Implementation Plan: [FEATURE NAME]

## Overview

Brief description of implementation approach.

## References

- Design Doc: `docs/design/DESIGN.md`
- Requirements: `docs/requirement/REQUIREMENTS.md`

## Codebase Analysis

### Conventions Identified

| Aspect | Convention | Example Location |
|--------|------------|------------------|
| File naming | [pattern, e.g., kebab-case] | [path/to/example] |
| Class naming | [pattern, e.g., PascalCase] | [path/to/example] |
| Function naming | [pattern, e.g., camelCase] | [path/to/example] |
| Error handling | [pattern, e.g., throw typed errors] | [path/to/example] |
| Logging | [pattern, e.g., structured logging] | [path/to/example] |
| Testing | [pattern, e.g., describe/it blocks] | [path/to/example] |

### Reusable Utilities

| Utility | Location | Purpose |
|---------|----------|---------|
| [utility name] | [path] | [what it does, how to use] |

## Implementation Units

### Order of Implementation

1. **[Unit 1 Name]** - Foundation, no dependencies
2. **[Unit 2 Name]** - Depends on Unit 1
3. **[Unit 3 Name]** - Depends on Unit 1, 2
4. ...

---

## Unit 1: [Name]

**File:** `[path/to/file.ts]`

**Type:** New File / Modify Existing

**Depends On:** None / [list units]

### Purpose

What this unit does and why it exists.

### Pseudocode

```
FUNCTION functionName(param1: Type, param2: Type) -> ReturnType:
    // Step 1: Validate inputs
    IF param1 is null or undefined:
        THROW InvalidArgumentError("param1 is required")

    IF param2 fails validation:
        THROW ValidationError("param2 must be...")

    // Step 2: Perform main operation
    intermediateResult = CALL helperFunction(param1)

    // Step 3: Transform result
    transformedResult = MAP intermediateResult THROUGH transformation

    // Step 4: Handle edge cases
    IF transformedResult is empty:
        RETURN defaultValue

    // Step 5: Return
    RETURN transformedResult
END FUNCTION
```

### Error Handling

| Error Condition | Error Type | Message | Recovery |
|-----------------|------------|---------|----------|
| param1 missing | InvalidArgumentError | "param1 is required" | Caller provides param |
| External API fails | ExternalServiceError | "Service unavailable" | Retry with backoff |

### Dependencies

**Imports:**
- `import { utility } from './utils'`
- `import { ExternalClient } from 'external-lib'`

**Internal:**
- Uses Unit X for [purpose]

---

## Unit 2: [Name]

**File:** `[path/to/file.ts]`

**Type:** New File / Modify Existing

**Depends On:** Unit 1

### Purpose

What this unit does.

### Pseudocode

```
CLASS ClassName:
    PRIVATE field1: Type
    PRIVATE field2: Type

    CONSTRUCTOR(config: ConfigType):
        // Validate configuration
        VALIDATE config has required fields

        // Initialize fields
        SET this.field1 = config.value1
        SET this.field2 = config.value2 OR defaultValue

    PUBLIC METHOD methodName(input: InputType) -> OutputType:
        // Step 1: Description of step
        intermediate = PROCESS input using this.field1

        // Step 2: Description of step
        result = TRANSFORM intermediate

        RETURN result

    PRIVATE METHOD helperMethod(data: DataType) -> ResultType:
        // Internal helper logic
        processed = APPLY transformation to data
        RETURN processed
END CLASS
```

### Error Handling

| Error Condition | Error Type | Message | Recovery |
|-----------------|------------|---------|----------|
| [condition] | [type] | [message] | [recovery action] |

---

## Unit N: [Name]

...

---

## Configuration & Constants

### New Constants

| Name | Value | Location | Purpose |
|------|-------|----------|---------|
| MAX_RETRY_COUNT | 3 | `src/constants.ts` | Maximum API retry attempts |
| DEFAULT_TIMEOUT | 5000 | `src/constants.ts` | Default timeout in ms |

### New Configuration Options

| Key | Type | Default | Validation | Purpose |
|-----|------|---------|------------|---------|
| configKey | string | "default" | non-empty string | Description |

## File Changes Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `src/new-file.ts` | New | [what this file contains] |
| `src/existing.ts` | Modify | [what changes] |

## Integration Points

| Component | Integration Method | Notes |
|-----------|-------------------|-------|
| [component] | [how it connects] | [any special considerations] |

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| [risk description] | High/Medium/Low | High/Medium/Low | [how to mitigate] |

---

**Created:** [DATE]
**Last Updated:** [DATE]
**Status:** Draft / In Review / Approved
