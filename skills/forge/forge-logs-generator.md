# FORGE-LOGS Generator Specification

## Overview

FORGE-LOGS.md is generated from state.json. Unlike old prose journals (where manual edits were lost), new FORGE-LOGS.md is always auto-generated from structured state. No manual sections. Can be regenerated at any time idempotently.

**Purpose:** Serve as a central human-readable context hub for:
1. Users: Quick reference for feature status and progress
2. Agents: Rapid context on current phase, decisions, blockers, and dependencies
3. Orchestrator: Source for human-readable status display

---

## Generation Algorithm: `generate_forge_logs(state)`

### Input

- `state` (dict): Parsed `.forge/state.json`
- **Implicit:** Active feature is identified via `.features[].is_active == true`

### Output

- `markdown` (string): Complete FORGE-LOGS.md content, ready to write to file

### Algorithm Pseudocode

```
FUNCTION generate_forge_logs(state):
    // Find active feature
    feature = state.features | filter .is_active == true | first
    IF feature NOT found:
        RETURN "No active feature"
    END IF

    output = []

    // 1. Header Section
    output.append("# Forge Logs — " + feature.name)
    output.append("")
    output.append("## Feature")
    output.append("Name: " + feature.name)
    output.append("Started: " + format_iso_date(feature.created))
    output.append("Status: " + feature.status)
    output.append("")

    // 2. Current Phase Section
    current_phase_num = find_current_phase(feature)
    current_phase = feature.phases[str(current_phase_num)]
    output.append("## Current Phase")
    output.append("Phase " + current_phase_num + ": " + current_phase.name)
    output.append("Status: " + format_phase_status_label(current_phase.status))
    IF current_phase.status == "in_progress":
        output.append("Elapsed: " + format_duration(now - current_phase.started))
    END IF
    IF current_phase.review_findings EXISTS AND current_phase.review_findings NOT NULL:
        output.append("Review Findings: " + format_review_summary(current_phase.review_findings))
    END IF
    output.append("")

    // 3. Timeline Section (all 12 phases)
    output.append("## Timeline")
    FOR phase_num = 1 TO 12:
        phase = feature.phases[str(phase_num)]
        output.append("")
        output.append(format_phase_entry(phase_num, phase))

    // 4. Artifacts Section (grouped by phase)
    output.append("")
    output.append("## Artifacts")
    has_artifacts = false
    FOR phase_num = 1 TO 12:
        phase = feature.phases[str(phase_num)]
        IF phase.artifacts LENGTH > 0:
            has_artifacts = true
            output.append("")
            output.append("### Phase " + phase_num + ": " + phase.name)
            FOR artifact IN phase.artifacts:
                // Display relative path from project root
                rel_path = artifact.path
                size_str = format_file_size(artifact.size_bytes)
                output.append("- " + rel_path + " [" + size_str + ", sha: " + artifact.sha + "]")

    IF NOT has_artifacts:
        output.append("(No artifacts yet)")

    // 5. Review Findings Section (only for review phases)
    output.append("")
    output.append("## Review Findings")
    review_phases = [3, 5, 7, 9, 11]
    has_findings = false
    FOR phase_num IN review_phases:
        phase = feature.phases[str(phase_num)]
        IF phase.review_findings EXISTS AND phase.review_findings NOT NULL:
            has_findings = true
            output.append("")
            output.append(format_review_section(phase_num, phase))

    IF NOT has_findings:
        output.append("(No review phases completed yet)")

    // 6. Decision Log Section
    output.append("")
    output.append("## Decision Log")
    has_decisions = false
    FOR phase_num = 1 TO 12:
        phase = feature.phases[str(phase_num)]
        IF phase.decisions LENGTH > 0:
            has_decisions = true
            FOR decision IN phase.decisions:
                output.append("- [Phase " + phase_num + "] " + decision)

    IF NOT has_decisions:
        output.append("(No decisions logged yet)")

    // 7. Dependency Graph Section (ASCII representation)
    output.append("")
    output.append("## Dependency Graph")
    output.append(generate_ascii_dependency_graph(feature.dependency_graph))

    // 8. Latest Commit Section
    output.append("")
    output.append("## Latest Commit")
    IF state.latest_commit EXISTS:
        output.append("SHA: " + state.latest_commit.sha)
        output.append("Message: " + state.latest_commit.message)
        output.append("Timestamp: " + format_iso_date(state.latest_commit.timestamp))
    ELSE:
        output.append("(No commits yet)")

    RETURN join(output, "\n")
END FUNCTION
```

---

## Format Helper Functions

### `format_phase_entry(phase_num, phase)`

Generates markdown for a single phase entry with status and details.

```
FUNCTION format_phase_entry(phase_num, phase):
    icon = phase_status_icon(phase.status)
    name = phase.name
    header = "**Phase " + phase_num + ": " + name + "** [" + icon + "]"

    entry = [header]

    SWITCH phase.status:
        CASE "pending":
            entry.append("Not yet started")

        CASE "in_progress":
            entry.append("Started: " + format_iso_date(phase.started))
            elapsed = format_duration(now - phase.started)
            entry.append("Elapsed: " + elapsed)

        CASE "completed":
        CASE "approved":
            entry.append("Started: " + format_iso_date(phase.started))
            entry.append("Completed: " + format_iso_date(phase.completed))
            duration = phase.completed - phase.started
            entry.append("Elapsed: " + format_duration(duration))

            // Include decisions if present
            IF phase.decisions LENGTH > 0:
                entry.append("Decisions:")
                FOR decision IN phase.decisions:
                    entry.append("  - " + decision)

        CASE "failed":
            entry.append("Status: FAILED")
            entry.append("Started: " + format_iso_date(phase.started))
            IF phase.review_findings EXISTS:
                critical_count = phase.review_findings.critical
                major_count = phase.review_findings.major
                entry.append("Blocker: " + critical_count + " CRITICAL, " + major_count + " MAJOR findings")

        CASE "invalidated":
            entry.append("Status: INVALIDATED (due to upstream change)")

        DEFAULT:
            entry.append("Status: " + phase.status)
    END SWITCH

    RETURN join(entry, "\n")
END FUNCTION
```

### `format_review_section(phase_num, phase)`

Generates markdown for a review phase with findings summary.

```
FUNCTION format_review_section(phase_num, phase):
    output = []
    findings = phase.review_findings

    output.append("### Phase " + phase_num + ": " + phase.name)
    output.append("Round: " + findings.round)
    output.append("Gate: " + findings.gate)
    output.append("")
    output.append("Findings:")
    output.append("- Critical: " + findings.critical)
    output.append("- Major: " + findings.major)
    output.append("- Minor: " + findings.minor)
    output.append("- Suggestion: " + findings.suggestion)

    RETURN join(output, "\n")
END FUNCTION
```

### `phase_status_icon(status)`

Maps phase status to emoji icon.

```
FUNCTION phase_status_icon(status):
    SWITCH status:
        CASE "approved":      RETURN "✓"
        CASE "completed":     RETURN "✓"
        CASE "in_progress":   RETURN "⏳"
        CASE "pending":       RETURN "⊘"
        CASE "failed":        RETURN "✗"
        CASE "invalidated":   RETURN "↻"
        DEFAULT:              RETURN "?"
    END SWITCH
END FUNCTION
```

### `format_phase_status_label(status)`

Returns human-readable status label.

```
FUNCTION format_phase_status_label(status):
    SWITCH status:
        CASE "pending":       RETURN "Pending"
        CASE "in_progress":   RETURN "In Progress"
        CASE "completed":     RETURN "Completed"
        CASE "approved":      RETURN "Approved"
        CASE "failed":        RETURN "Failed"
        CASE "invalidated":   RETURN "Invalidated"
        DEFAULT:              RETURN status
    END SWITCH
END FUNCTION
```

### `format_review_summary(findings)`

Returns brief summary of review findings.

```
FUNCTION format_review_summary(findings):
    result = findings.gate
    IF findings.critical > 0:
        result = result + " (" + findings.critical + " CRITICAL"
    ELSE IF findings.major > 0:
        result = result + " (" + findings.major + " MAJOR"
    ELSE IF findings.minor > 0:
        result = result + " (" + findings.minor + " MINOR"
    ELSE:
        result = result + " (0 issues"
    result = result + ")"
    RETURN result
END FUNCTION
```

### `format_iso_date(timestamp_string)`

Formats ISO 8601 timestamp for readability.

```
FUNCTION format_iso_date(timestamp_string):
    // Input: "2026-04-10T10:00:00Z"
    // Output: "2026-04-10 10:00 UTC"
    IF timestamp_string IS NULL OR EMPTY:
        RETURN "(not set)"
    END IF

    parts = timestamp_string.split("T")
    date_part = parts[0]
    time_part = parts[1].split(".")[0]  // Remove milliseconds if present

    RETURN date_part + " " + time_part + " UTC"
END FUNCTION
```

### `format_duration(seconds)`

Formats elapsed seconds as human-readable duration.

```
FUNCTION format_duration(seconds):
    IF seconds < 60:
        RETURN seconds + "s"
    ELSE IF seconds < 3600:
        minutes = seconds / 60
        RETURN round(minutes) + "m"
    ELSE IF seconds < 86400:
        hours = seconds / 3600
        RETURN round(hours) + "h"
    ELSE:
        days = seconds / 86400
        RETURN round(days) + "d"
    END IF
END FUNCTION
```

### `format_file_size(bytes)`

Formats file size in bytes as human-readable string.

```
FUNCTION format_file_size(bytes):
    IF bytes < 1024:
        RETURN bytes + "B"
    ELSE IF bytes < 1024 * 1024:
        kb = bytes / 1024
        RETURN round_to_1_decimal(kb) + "KB"
    ELSE IF bytes < 1024 * 1024 * 1024:
        mb = bytes / (1024 * 1024)
        RETURN round_to_1_decimal(mb) + "MB"
    ELSE:
        gb = bytes / (1024 * 1024 * 1024)
        RETURN round_to_1_decimal(gb) + "GB"
    END IF
END FUNCTION
```

### `find_current_phase(feature)`

Identifies the current phase number (lowest phase not yet approved).

```
FUNCTION find_current_phase(feature):
    FOR phase_num = 1 TO 12:
        phase = feature.phases[str(phase_num)]
        IF phase.status NOT IN ["approved", "completed"]:
            RETURN phase_num
        END IF
    END FOR

    // All phases approved/completed
    RETURN 12
END FUNCTION
```

### `generate_ascii_dependency_graph(dependency_graph)`

Generates ASCII representation of phase dependencies.

```
FUNCTION generate_ascii_dependency_graph(dependency_graph):
    output = []
    output.append("```")
    output.append("PHASE DEPENDENCIES")
    output.append("")

    // Static phase dependency tree (standard forge workflow)
    output.append("Phase 1: Requirements")
    output.append("  ├─> Phase 2: Design")
    output.append("  │    ├─> Phase 3: Design Review")
    output.append("  │    ├─> Phase 4: Impl Planning")
    output.append("  │    │    └─> Phase 5: Plan Review")
    output.append("  │    ├─> Phase 6: Test Planning")
    output.append("  │    │    └─> Phase 7: Test Plan Review")
    output.append("  │    ├─> Phase 8: Code Implementation")
    output.append("  │    │    └─> Phase 9: Code Review")
    output.append("  │    └─> Phase 10: Test Implementation")
    output.append("  │         └─> Phase 11: Test Review")
    output.append("  └─> Phase 12: Documentation")
    output.append("```")

    RETURN join(output, "\n")
END FUNCTION
```

---

## Regeneration Command

### `regenerate_forge_logs()`

Main entry point to regenerate FORGE-LOGS.md from state.json.

```
FUNCTION regenerate_forge_logs():
    // Step 1: Load state.json
    state_path = ".forge/state.json"
    IF NOT file_exists(state_path):
        LOG_ERROR("state.json not found at " + state_path)
        RETURN {success: false, error: "state.json not found"}
    END IF

    state = read_json(state_path)

    // Step 2: Generate markdown
    logs_content = generate_forge_logs(state)

    // Step 3: Write to FORGE-LOGS.md
    logs_path = ".forge/FORGE-LOGS.md"
    write_file(logs_path, logs_content)

    // Step 4: Optionally commit
    // (Orchestrator owns git commits; this function just generates the file)

    LOG_INFO("FORGE-LOGS.md regenerated")
    RETURN {success: true, path: logs_path}
END FUNCTION
```

---

## Idempotency & Regeneration

**Key Property:** Running `regenerate_forge_logs()` multiple times with the same `state.json` produces **identical output**.

- All timestamps are taken from state.json (not computed at generation time)
- All duration calculations are based on state.json timestamps
- Sorting order is deterministic (phases 1-12 in order, review phases 3,5,7,9,11 in order)
- No random elements or external dependencies

**Consequence:** Safe to regenerate after every phase completion or on-demand without risk of inconsistency.

---

## Data Mapping Rules

### State.json → FORGE-LOGS.md Mapping

| State.json Field | FORGE-LOGS.md Section | Mapping Rule |
|------------------|----------------------|-------------|
| `features[].name` | "# Forge Logs — {name}" + "## Feature / Name:" | Direct insertion |
| `features[].created` | "## Feature / Started:" | Format as ISO date |
| `features[].status` | "## Feature / Status:" | Direct insertion |
| `phases[N].name` | "## Timeline / Phase N:" | Direct insertion |
| `phases[N].status` | Status icon + label | Via `phase_status_icon()` + `format_phase_status_label()` |
| `phases[N].started` | Timeline entry | Format as ISO date |
| `phases[N].completed` | Timeline entry | Format as ISO date, compute duration |
| `phases[N].artifacts[]` | "## Artifacts / Phase N" | List with size + SHA |
| `phases[N].decisions[]` | Timeline entry + "## Decision Log" | Display under phase, list in log |
| `phases[N].review_findings` | "## Review Findings / Phase N" | Count summary + gate status |
| `dependency_graph` | "## Dependency Graph" | ASCII tree representation |
| `latest_commit` | "## Latest Commit" | SHA, message, timestamp |

### Null/Empty Handling

| Condition | Behavior |
|-----------|----------|
| No artifacts in phase | Omit phase from Artifacts section; total: "(No artifacts yet)" |
| No review findings any phase | Display: "(No review phases completed yet)" |
| No decisions in any phase | Display: "(No decisions logged yet)" |
| Missing `latest_commit` | Display: "(No commits yet)" |
| No active feature | Return: "No active feature" |

---

## Example Output

### Input: state.json for auth-middleware feature at Phase 4

```json
{
  "features": [{
    "id": "auth-middleware",
    "name": "Authentication Middleware",
    "status": "in_progress",
    "created": "2026-04-10T10:00:00Z",
    "is_active": true,
    "phases": {
      "1": {
        "name": "Requirement Analysis",
        "status": "approved",
        "started": "2026-04-10T10:00:00Z",
        "completed": "2026-04-10T10:30:00Z",
        "artifacts": [{"path": ".forge/features/auth-middleware/requirement/REQUIREMENTS.md", "sha": "abc123", "size_bytes": 12500}],
        "decisions": ["Scoped to API layer only", "Deferred UI to v2"]
      },
      "2": {
        "name": "Design Creation",
        "status": "approved",
        "started": "2026-04-10T10:35:00Z",
        "completed": "2026-04-10T11:15:00Z",
        "artifacts": [{"path": ".forge/features/auth-middleware/design/DESIGN.md", "sha": "def456", "size_bytes": 18200}],
        "decisions": ["DD-1: Middleware pattern (matches codebase)", "DD-2: JWT with RS256"]
      },
      "3": {
        "name": "Design Review",
        "status": "approved",
        "started": "2026-04-10T11:20:00Z",
        "completed": "2026-04-10T11:35:00Z",
        "review_findings": {"round": 1, "critical": 0, "major": 0, "minor": 2, "suggestion": 1, "gate": "PASS"},
        "artifacts": [{"path": ".forge/features/auth-middleware/design/DESIGN-REVIEW-1.md", "sha": "jkl012", "size_bytes": 3200}]
      },
      "4": {
        "name": "Implementation Planning",
        "status": "in_progress",
        "started": "2026-04-10T11:40:00Z",
        "completed": null,
        "artifacts": []
      },
      "5": { "name": "Impl Plan Review", "status": "pending", "started": null, "completed": null, "artifacts": [] },
      "6": { "name": "Test Planning", "status": "pending", "started": null, "completed": null, "artifacts": [] },
      "7": { "name": "Test Plan Review", "status": "pending", "started": null, "completed": null, "artifacts": [] },
      "8": { "name": "Code Implementation", "status": "pending", "started": null, "completed": null, "artifacts": [] },
      "9": { "name": "Code Review", "status": "pending", "started": null, "completed": null, "artifacts": [] },
      "10": { "name": "Test Implementation", "status": "pending", "started": null, "completed": null, "artifacts": [] },
      "11": { "name": "Test Review", "status": "pending", "started": null, "completed": null, "artifacts": [] },
      "12": { "name": "Documentation", "status": "pending", "started": null, "completed": null, "artifacts": [] }
    }
  }],
  "latest_commit": {
    "sha": "mno345pqr678",
    "message": "forge: phase 3 — design review round 1",
    "timestamp": "2026-04-10T11:35:00Z"
  }
}
```

### Output: FORGE-LOGS.md

```markdown
# Forge Logs — Authentication Middleware

## Feature
Name: Authentication Middleware
Started: 2026-04-10 10:00 UTC
Status: in_progress

## Current Phase
Phase 4: Implementation Planning
Status: In Progress
Elapsed: 2h

## Timeline

**Phase 1: Requirement Analysis** [✓]
Started: 2026-04-10 10:00 UTC
Completed: 2026-04-10 10:30 UTC
Elapsed: 30m

Decisions:
  - Scoped to API layer only
  - Deferred UI to v2

**Phase 2: Design Creation** [✓]
Started: 2026-04-10 10:35 UTC
Completed: 2026-04-10 11:15 UTC
Elapsed: 40m

Decisions:
  - DD-1: Middleware pattern (matches codebase)
  - DD-2: JWT with RS256

**Phase 3: Design Review** [✓]
Started: 2026-04-10 11:20 UTC
Completed: 2026-04-10 11:35 UTC
Elapsed: 15m

**Phase 4: Implementation Planning** [⏳]
Started: 2026-04-10 11:40 UTC
Elapsed: 2h

**Phase 5: Impl Plan Review** [⊘]
Not yet started

**Phase 6: Test Planning** [⊘]
Not yet started

**Phase 7: Test Plan Review** [⊘]
Not yet started

**Phase 8: Code Implementation** [⊘]
Not yet started

**Phase 9: Code Review** [⊘]
Not yet started

**Phase 10: Test Implementation** [⊘]
Not yet started

**Phase 11: Test Review** [⊘]
Not yet started

**Phase 12: Documentation** [⊘]
Not yet started

## Artifacts

### Phase 1: Requirement Analysis
- .forge/features/auth-middleware/requirement/REQUIREMENTS.md [12.5KB, sha: abc123]

### Phase 2: Design Creation
- .forge/features/auth-middleware/design/DESIGN.md [18.2KB, sha: def456]

### Phase 3: Design Review
- .forge/features/auth-middleware/design/DESIGN-REVIEW-1.md [3.2KB, sha: jkl012]

## Review Findings

### Phase 3: Design Review
Round: 1
Gate: PASS

Findings:
- Critical: 0
- Major: 0
- Minor: 2
- Suggestion: 1

## Decision Log

- [Phase 1] Scoped to API layer only
- [Phase 1] Deferred UI to v2
- [Phase 2] DD-1: Middleware pattern (matches codebase)
- [Phase 2] DD-2: JWT with RS256

## Dependency Graph

```
PHASE DEPENDENCIES

Phase 1: Requirements
  ├─> Phase 2: Design
  │    ├─> Phase 3: Design Review
  │    ├─> Phase 4: Impl Planning
  │    │    └─> Phase 5: Plan Review
  │    ├─> Phase 6: Test Planning
  │    │    └─> Phase 7: Test Plan Review
  │    ├─> Phase 8: Code Implementation
  │    │    └─> Phase 9: Code Review
  │    └─> Phase 10: Test Implementation
  │         └─> Phase 11: Test Review
  └─> Phase 12: Documentation
```

## Latest Commit
SHA: mno345pqr678
Message: forge: phase 3 — design review round 1
Timestamp: 2026-04-10 11:35 UTC
```

---

## Integration with Orchestrator

The orchestrator calls `regenerate_forge_logs()` after:
1. Phase completion (phase status changes to `approved` or `completed`)
2. Cascade detection (phases marked `invalidated`)
3. On-demand via `forge logs regenerate` command
4. Feature state changes

**Responsibility:** Orchestrator owns the git commit; generator only produces file content.

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| `state.json` missing or invalid JSON | Return error; do not create FORGE-LOGS.md |
| No active feature in `state.json` | Generate empty FORGE-LOGS.md with message |
| Phase object has `null` timestamps | Skip elapsed calculation, omit from timeline |
| Artifact path is `null` or empty | Skip artifact entry, log warning |
| Dependency graph is `null` or empty | Generate standard phase tree diagram |

---

## Performance Characteristics

- **Input:** state.json file read (typically < 50KB)
- **Processing:** Single pass through all 12 phases + formatting
- **Output:** FORGE-LOGS.md written (typically 3-10KB)
- **Target:** Generation completes in < 500ms

**Optimization:** No file I/O beyond reading state.json and writing FORGE-LOGS.md. All calculations are in-memory.

---

## Future Extensions

1. **Custom phase names:** `.context.custom.phase_names` could override default phase names
2. **Decision filtering:** Generate brief summary vs. full decision log (toggle)
3. **Artifact filtering:** Generate for specific phases only (for large features)
4. **Template customization:** Allow user-provided template for output format

---

## Dependencies

### Internal
- Unit 1 (State Schema) — reads from `.forge/state.json`

### External
- None (pure data transformation)

### Assumptions
- `.forge/state.json` is valid JSON and conforms to schema
- All timestamps are ISO 8601 strings
- Phase numbers are 1-12 (hardcoded in loops)
- Artifact paths are relative to project root or absolute (handled uniformly)

---

**Status:** Specification complete, ready for implementation
**Version:** 1.0
**Created:** 2026-04-10
