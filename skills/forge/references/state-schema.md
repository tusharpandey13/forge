# State Schema — Forge State Management

## Overview

`state.json` is the machine-readable source of truth for Forge. It captures:
- Feature metadata (id, name, status, dates)
- Per-phase status and artifacts
- Artifact index with SHA and metadata
- Dependency graph (forward + backward edges)
- Execution details (model, reasoning tokens, context %)

This is a **living reference document**. The orchestrator skill references this file to understand state structure and operations. Keep this in sync with actual state mutations.

---

## Schema (JSON) — Version 1.0

```json
{
  "version": "1.0",
  "repository": {
    "root": "/absolute/path/to/project",
    "created": "2026-04-10T10:00:00Z",
    "git_initialized": true
  },
  "features": [
    {
      "id": "feature-slug",
      "name": "Feature Name",
      "status": "in_progress|completed|failed",
      "track": "standard|lite",
      "created": "2026-04-10T10:00:00Z",
      "is_active": true,
      "root_dir": ".forge/features/feature-slug",
      "phases": {
        "1": {
          "name": "Requirement Analysis",
          "status": "pending|in_progress|completed|approved|failed|invalidated",
          "started": "2026-04-10T10:00:00Z",
          "completed": "2026-04-10T10:30:00Z",
          "execution": "task_agent|manual|null",
          "artifacts": [
            {
              "path": ".forge/features/feature-slug/requirement/REQUIREMENTS.md",
              "phase": 1,
              "sha": "abc123def456",
              "size_bytes": 12500,
              "created": "2026-04-10T10:30:00Z"
            }
          ],
          "decisions": [
            "DD-1: Scoped to API layer only",
            "DD-2: Deferred UI to v2"
          ],
          "execution_details": {
            "model": "qc-readonly",
            "reasoning_lines": 245,
            "context_usage_percent": 22,
            "elapsed_seconds": 1800
          },
          "review_findings": null
        },
        "2": {
          "name": "Design Creation",
          "status": "approved",
          "started": "2026-04-10T10:35:00Z",
          "completed": "2026-04-10T11:15:00Z",
          "execution": "task_agent",
          "artifacts": [
            {
              "path": ".forge/features/feature-slug/design/DESIGN.md",
              "phase": 2,
              "sha": "def456ghi789",
              "size_bytes": 18200,
              "created": "2026-04-10T11:15:00Z"
            },
            {
              "path": ".forge/features/feature-slug/design/design-artifact-decision-1.md",
              "phase": 2,
              "sha": "ghi789jkl012",
              "size_bytes": 5600,
              "created": "2026-04-10T11:15:00Z"
            }
          ],
          "decisions": [
            "DD-1: Middleware pattern (matches codebase)",
            "DD-2: JWT with RS256 (per security requirements)"
          ],
          "execution_details": {
            "model": "qc-readonly",
            "reasoning_lines": 412,
            "context_usage_percent": 31,
            "elapsed_seconds": 2400
          },
          "review_findings": null
        },
        "3": {
          "name": "Design Review",
          "status": "approved",
          "started": "2026-04-10T11:20:00Z",
          "completed": "2026-04-10T11:35:00Z",
          "execution": "task_agent",
          "artifacts": [
            {
              "path": ".forge/features/feature-slug/design/DESIGN-REVIEW-1.md",
              "phase": 3,
              "sha": "jkl012mno345",
              "size_bytes": 3200,
              "created": "2026-04-10T11:35:00Z"
            }
          ],
          "decisions": [],
          "execution_details": {
            "model": "qc-readonly",
            "reasoning_lines": 156,
            "context_usage_percent": 18,
            "elapsed_seconds": 900
          },
          "review_findings": {
            "round": 1,
            "critical": 0,
            "major": 0,
            "minor": 2,
            "suggestion": 1,
            "gate": "PASS"
          }
        },
        "4": {
          "name": "Implementation Planning",
          "status": "pending",
          "started": null,
          "completed": null,
          "execution": null,
          "artifacts": [],
          "decisions": [],
          "execution_details": null,
          "review_findings": null
        },
        "5": {
          "name": "Impl Plan Review",
          "status": "pending",
          "started": null,
          "completed": null,
          "execution": null,
          "artifacts": [],
          "decisions": [],
          "execution_details": null,
          "review_findings": null
        },
        "6": {
          "name": "Test Planning",
          "status": "pending",
          "started": null,
          "completed": null,
          "execution": null,
          "artifacts": [],
          "decisions": [],
          "execution_details": null,
          "review_findings": null
        },
        "7": {
          "name": "Test Plan Review",
          "status": "pending",
          "started": null,
          "completed": null,
          "execution": null,
          "artifacts": [],
          "decisions": [],
          "execution_details": null,
          "review_findings": null
        },
        "8": {
          "name": "Code Implementation",
          "status": "pending",
          "started": null,
          "completed": null,
          "execution": null,
          "artifacts": [],
          "decisions": [],
          "execution_details": null,
          "review_findings": null
        },
        "9": {
          "name": "Code Review",
          "status": "pending",
          "started": null,
          "completed": null,
          "execution": null,
          "artifacts": [],
          "decisions": [],
          "execution_details": null,
          "review_findings": null
        },
        "10": {
          "name": "Test Implementation",
          "status": "pending",
          "started": null,
          "completed": null,
          "execution": null,
          "artifacts": [],
          "decisions": [],
          "execution_details": null,
          "review_findings": null
        },
        "11": {
          "name": "Test Review",
          "status": "pending",
          "started": null,
          "completed": null,
          "execution": null,
          "artifacts": [],
          "decisions": [],
          "execution_details": null,
          "review_findings": null
        },
        "12": {
          "name": "Documentation",
          "status": "pending",
          "started": null,
          "completed": null,
          "execution": null,
          "artifacts": [],
          "decisions": [],
          "execution_details": null,
          "review_findings": null
        }
      },
      "dependency_graph": {
        "forward": {
          ".forge/features/feature-slug/requirement/REQUIREMENTS.md": [
            ".forge/features/feature-slug/design/DESIGN.md"
          ],
          ".forge/features/feature-slug/design/DESIGN.md": [
            ".forge/features/feature-slug/plan/IMPL-PLAN.md",
            ".forge/features/feature-slug/plan/TEST-PLAN.md"
          ]
        },
        "backward": {
          ".forge/features/feature-slug/design/DESIGN.md": [
            ".forge/features/feature-slug/requirement/REQUIREMENTS.md"
          ],
          ".forge/features/feature-slug/plan/IMPL-PLAN.md": [
            ".forge/features/feature-slug/design/DESIGN.md"
          ],
          ".forge/features/feature-slug/plan/TEST-PLAN.md": [
            ".forge/features/feature-slug/design/DESIGN.md"
          ]
        }
      },
      "context": {
        "config_path": ".forge/FORGE-CONFIG.md",
        "custom": {
          "priority": "high",
          "team": "backend",
          "notes": "Critical path item"
        }
      }
    }
  ],
  "latest_commit": {
    "sha": "mno345pqr678",
    "message": "forge: phase 3 — design review round 1",
    "timestamp": "2026-04-10T11:35:00Z"
  }
}
```

---

## Schema Field Definitions

### repository
- `root` (string, absolute path): Project root directory
- `created` (ISO 8601): When state.json was first created
- `git_initialized` (boolean): Whether `.forge/.git` is initialized

### features[] (array)
Array of active features. Initially 1; architecture supports future multi-feature.

### feature object
- `id` (string, slug): Feature identifier (kebab-case, e.g., `auth-middleware`)
- `name` (string): Human-readable feature name
- `status` (enum): Current feature status (see **Feature Status Enum** below)
- `track` (enum): `standard` (12 phases) | `lite` (4 stages: Plan→Build→Test→Review). Chosen once at feature creation; immutable for the feature's life. Determines how many entries `phases` holds and which pipeline the orchestrator drives. See **Scope-Adaptive Lite Lane** in the orchestrator skill.
- `created` (ISO 8601): Feature creation timestamp
- `is_active` (boolean): Whether this is the active feature
- `root_dir` (string, relative path): `.forge/features/<slug>`
- `phases` (object): Key = phase number (1-12 as strings); value = phase object
- `dependency_graph` (object): Forward and backward edge indices (see **Dependency Graph** below)
- `context` (object): Config and custom metadata

### phase object (phases["N"])
- `name` (string): Phase display name (e.g., "Requirement Analysis")
- `status` (enum): Phase status (see **Phase Status Enum** below)
- `started` (ISO 8601 or null): When phase execution started
- `completed` (ISO 8601 or null): When phase completed
- `execution` (enum or null): How phase was executed (`task_agent`, `manual`, or `null`)
- `artifacts` (array): Output artifacts from this phase
- `decisions` (array of strings): Key decisions made (DD-N format recommended)
- `execution_details` (object or null): Task agent metadata (model, tokens, timing)
- `review_findings` (object or null): For review phases only (counts + gate status)

### artifact object (phase.artifacts[])
- `path` (string, absolute path): Artifact file path
- `phase` (number): Which phase produced this artifact
- `sha` (string, 12 chars): Short git SHA for artifact commit
- `size_bytes` (number): File size in bytes
- `created` (ISO 8601): When artifact was created

### execution_details object
- `model` (string): LLM model used (e.g., `qc-readonly`)
- `reasoning_lines` (number): Lines of reasoning produced
- `context_usage_percent` (number): % of context budget used (0-100)
- `elapsed_seconds` (number): Wall clock time from start to finish

### review_findings object (Phase 3, 5, 7, 9, 11 only)
- `round` (number): Review round number (1, 2, 3...)
- `critical` (number): Count of CRITICAL findings
- `major` (number): Count of MAJOR findings
- `minor` (number): Count of MINOR findings
- `suggestion` (number): Count of SUGGESTION findings
- `gate` (enum): "PASS" (no critical/major) or "FAIL" (has critical or major)

### dependency_graph.forward
Maps artifact path → list of downstream dependencies.
- Key: source artifact path (e.g., `.forge/features/auth-middleware/design/DESIGN.md`)
- Value: array of paths that depend on this artifact

Example: If DESIGN.md is used by both IMPL-PLAN.md and TEST-PLAN.md:
```json
".forge/features/auth-middleware/design/DESIGN.md": [
  ".forge/features/auth-middleware/plan/IMPL-PLAN.md",
  ".forge/features/auth-middleware/plan/TEST-PLAN.md"
]
```

### dependency_graph.backward
Maps artifact path ← list of upstream dependencies.
- Key: artifact path
- Value: array of paths this artifact depends on

Example: IMPL-PLAN.md depends on DESIGN.md:
```json
".forge/features/auth-middleware/plan/IMPL-PLAN.md": [
  ".forge/features/auth-middleware/design/DESIGN.md"
]
```

### context
- `config_path` (string): Path to FORGE-CONFIG.md
- `custom` (object): Freeform user metadata (priority, team, notes, etc.) — schema-free extension point

---

## Status Enums

### feature.status
- `pending`: Feature created but phase 1 not started
- `in_progress`: One or more phases in progress or some completed
- `completed`: All phases 1-12 completed and approved
- `failed`: A phase failed its gate and user has not retried

### phase.status
- `pending`: Phase not yet started (no artifacts, no execution)
- `in_progress`: Phase is currently running (task agent executing)
- `completed`: Phase artifacts produced; if review phase, findings available but gate not yet evaluated
- `approved`: Phase passed gate (for review phases) or user explicitly approved (for non-review phases)
- `failed`: Phase failed gate (review phase has CRITICAL or MAJOR findings) or execution errored
- `invalidated`: Phase marked as needing re-execution due to upstream artifact change (cascade detection)

**Lifecycle per phase type:**

Non-review phases (1, 2, 4, 6, 8, 10, 12):
```
pending → in_progress → completed → approved
                             ↓
                           failed
```

Review phases (3, 5, 7, 9, 11):
```
pending → in_progress → completed → approved (gate=PASS)
                             ↓
                           failed (gate=FAIL)
```

Either phase type:
```
approved/completed → invalidated (if upstream artifact changes)
```

---

## Operations.jsonl Format

Append-only log of state mutations. One JSON object per line. Provides full audit trail and enables rollback/replay.

**Format (one JSON object per line):**

```jsonl
{"ts":"2026-04-10T10:00:00Z","op":"feature_create","feature_id":"auth-middleware","message":"Created feature from context"}
{"ts":"2026-04-10T10:00:00Z","op":"git_init","message":"Initialized .forge/.git with defensive config"}
{"ts":"2026-04-10T10:00:00Z","op":"phase_dispatch","phase":1,"feature_id":"auth-middleware","agent":"qc-readonly","status":"start"}
{"ts":"2026-04-10T10:30:00Z","op":"phase_complete","phase":1,"feature_id":"auth-middleware","status":"completed","artifact_count":1,"sha":"abc123def456"}
{"ts":"2026-04-10T11:40:00Z","op":"cascade_detect","changed_artifact":".forge/features/auth-middleware/design/DESIGN.md","invalidated":[".forge/features/auth-middleware/plan/IMPL-PLAN.md"],"message":"Design change detected"}
{"ts":"2026-04-10T12:00:00Z","op":"state_update","phase":1,"reason":"Phase 1 complete; state.json updated","delta":"phases[1].status: completed → approved"}
```

### Supported Operations

| Operation | When | Fields | Purpose |
|-----------|------|--------|---------|
| `feature_create` | New feature created | `feature_id`, `message` | Log feature initialization |
| `feature_activate` | User switches active feature | `feature_id` | Track feature activation |
| `git_init` | .forge/.git initialized | `message` | Defensive git setup logged |
| `git_commit` | Artifacts committed | `sha`, `message` | Git history tracking |
| `phase_dispatch` | Phase sent to task agent | `phase`, `feature_id`, `agent`, `status` | Dispatch event |
| `phase_complete` | Phase completed by agent | `phase`, `feature_id`, `status`, `artifact_count`, `sha` | Completion marker |
| `phase_rollback` | Phase rolled back | `target_phase`, `sha`, `status` | Rollback event |
| `cascade_detect` | Changes detected, artifacts invalidated | `changed_artifact`, `invalidated[]`, `message` | Cascade propagation |
| `state_update` | state.json mutated | `phase`, `reason`, `delta` | State change logged |

### Schema (per operation)

All operations include:
- `ts` (ISO 8601): Operation timestamp
- `op` (string): Operation type
- `message` (string, optional): Human-readable description

Operation-specific fields as per table above.

### Example Sequences

**Feature creation → Phase 1 dispatch → Phase 1 complete → Phase 2 dispatch:**

```jsonl
{"ts":"2026-04-10T10:00:00Z","op":"feature_create","feature_id":"auth-middleware","message":"Created feature from context"}
{"ts":"2026-04-10T10:00:00Z","op":"git_init","message":"Initialized .forge/.git with defensive config"}
{"ts":"2026-04-10T10:00:00Z","op":"phase_dispatch","phase":1,"feature_id":"auth-middleware","agent":"qc-readonly","status":"start"}
{"ts":"2026-04-10T10:30:00Z","op":"phase_complete","phase":1,"feature_id":"auth-middleware","status":"completed","artifact_count":1,"sha":"abc123def456"}
{"ts":"2026-04-10T10:31:00Z","op":"state_update","phase":1,"reason":"Merged phase 1 output","delta":"phases[1].status: in_progress → completed, artifacts: [REQUIREMENTS.md]"}
{"ts":"2026-04-10T10:32:00Z","op":"phase_dispatch","phase":2,"feature_id":"auth-middleware","agent":"qc-readonly","status":"start"}
```

**Cascade detection when design changes:**

```jsonl
{"ts":"2026-04-10T12:00:00Z","op":"cascade_detect","changed_artifact":".forge/features/auth-middleware/design/DESIGN.md","invalidated":[".forge/features/auth-middleware/plan/IMPL-PLAN.md",".forge/features/auth-middleware/plan/TEST-PLAN.md",".forge/features/auth-middleware/review/CODE-REVIEW-1.md"],"message":"Design change detected; downstream artifacts marked for re-execution"}
{"ts":"2026-04-10T12:00:01Z","op":"state_update","reason":"Cascade: marked phases 4,6,8 as invalidated","delta":"phases[4].status: approved → invalidated, phases[6].status: completed → invalidated, phases[8].status: approved → invalidated"}
```

---

## Practical Usage

### Loading State (Orchestrator)

```python
import json

def load_state():
    """Load state.json; handle missing or corrupted file."""
    try:
        with open('.forge/state.json', 'r') as f:
            state = json.load(f)
        return state
    except FileNotFoundError:
        # Reinitialize
        return initialize_state()
    except json.JSONDecodeError:
        # Corrupted; offer rollback to last git commit
        raise ValueError("state.json corrupted; rollback to last commit: git -C .forge log --oneline")

def initialize_state():
    """Create empty state.json structure."""
    return {
        "version": "1.0",
        "repository": {
            "root": os.getcwd(),
            "created": datetime.now(timezone.utc).isoformat(),
            "git_initialized": False
        },
        "features": [],
        "latest_commit": None
    }
```

### Updating State (State Manager)

```python
def mark_phase_complete(feature_id, phase_num, status, artifacts, decisions):
    """Mark phase as complete; atomically update state.json."""
    state = load_state()
    feature = next(f for f in state["features"] if f["id"] == feature_id and f["is_active"])

    phase = feature["phases"][str(phase_num)]
    phase["status"] = status  # "completed" or "approved"
    phase["completed"] = datetime.now(timezone.utc).isoformat()
    phase["artifacts"] = artifacts
    phase["decisions"] = decisions

    # Atomic write (temp file + rename)
    temp_file = ".forge/state.json.tmp"
    with open(temp_file, 'w') as f:
        json.dump(state, f, indent=2)
    os.rename(temp_file, ".forge/state.json")

    # Append to operations.jsonl
    operation = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "op": "phase_complete",
        "phase": phase_num,
        "feature_id": feature_id,
        "status": status,
        "artifact_count": len(artifacts)
    }
    with open(".forge/operations.jsonl", "a") as f:
        f.write(json.dumps(operation) + "\n")
```

### Querying State (CLI)

```bash
# Show current phase
jq '.features[] | select(.is_active) | .phases | to_entries[] | select(.value.status != "pending") | "\(.key): \(.value.name) [\(.value.status)]"' .forge/state.json

# List all approved phases
jq '.features[0].phases | to_entries[] | select(.value.status == "approved") | .key' .forge/state.json

# Get all artifacts from phase 2
jq '.features[0].phases["2"].artifacts[] | .path' .forge/state.json

# Count findings by phase (review phases only)
jq '.features[0].phases | to_entries[] | select(.value.review_findings != null) | "\(.key): \(.value.review_findings.gate)"' .forge/state.json
```

---

## Validation Rules

### state.json Validation

1. **Version:** Must be "1.0"
2. **Repository.root:** Must be absolute path
3. **Features:** At least one feature with `is_active=true`
4. **Phases:** All 12 phases (numbered 1-12 as strings) present
5. **Phase.status:** Must be one of the allowed enums
6. **Artifacts.path:** Must be under `.forge/features/<feature_id>/`
7. **Dependency graph:** No circular edges (validated on updates)
8. **Timestamps:** All ISO 8601 format
9. **SHA:** 12-character hex string

### operations.jsonl Validation

1. **Format:** One JSON object per line (no multi-line)
2. **Required fields:** `ts`, `op` present in every line
3. **Timestamps:** ISO 8601, monotonically increasing
4. **Operations:** `op` value matches supported operations list

---

## Related Files

- `.forge/state.json` — Instance file (actual state)
- `.forge/operations.jsonl` — Instance file (audit log)
- `.forge/FORGE-CONFIG.md` — Project conventions (referenced in context.config_path)
- `.forge/.git/` — Git repository (tracks all state changes)

---

---

## Schema — Version 2.0 (thin index + ref envelope)

**Version field:** `state.json["version"] = "2.0"` — used for future auto-migrate detection.
Do NOT build migration logic yet; detection hook only.

### v2 Design: thin index

The v2 schema replaces per-phase inline bulk (`artifacts`, `decisions`, `execution_details`,
`review_findings`) with a ref envelope pointer. Bulk lives in `features/<slug>/phases/NN.json`.

#### phase object (v2 thin index)

```json
{
  "name": "Requirement Analysis",
  "status": "completed",
  "started": "2026-04-10T10:00:00Z",
  "completed": "2026-04-10T10:30:00Z",
  "ref": {
    "type": "phase",
    "repo": ".forge",
    "locator": "/abs/path/.forge/features/<slug>/phases/01.json",
    "summary": "≤120-char carry_forward hint"
  }
}
```

Hot index entry per phase = `{ref→NN.json, summary}` ONLY. ~2 lines each.

Bulk fields (`artifacts`, `decisions`, `execution_details`, `review_findings`,
`carry_forward`) are stored in `NN.json` and dereffed only on demand.

#### Ref envelope (canonical — from REF-SPEC.md)

```json
{
  "type": "artifact|ghost|phase",
  "repo": "project|.forge",
  "locator": "<absolute-path-or-sha>",
  "summary": "≤120 char hint (carry_forward for phase refs)"
}
```

- `type`: what it points to
- `repo`: which git store / filesystem root. `project` = user repo. `.forge` = forge runtime.
- `locator`: for `artifact` = relative path under feature dir; for `phase` = `features/<slug>/phases/NN.json` (absolute); for `ghost` = git SHA on `forge-ghost/<slug>` branch.
- `summary`: ONLY field allowed in hot index besides pointer metadata. Heavy content stays behind locator.

#### Bulk file: features/<slug>/phases/NN.json

```json
{
  "phase": 1,
  "slug": "feature-slug",
  "written": "2026-04-10T10:30:00Z",
  "status": "completed",
  "artifacts": [...],
  "decisions": [...],
  "execution_details": {...},
  "review_findings": null,
  "carry_forward": "handoff summary for next phase"
}
```

#### Archive stub: features/<slug>/archive.json

Terminal features are archived via `forge archive <slug>`. Produces:

```json
{
  "slug": "feature-slug",
  "name": "Feature Name",
  "archived": "2026-04-10T12:00:00Z",
  "original_status": "completed",
  "track": "standard",
  "created": "...",
  "phases": { "1": <bulk>, "2": <bulk>, ... }
}
```

After archive, individual `phases/NN.json` files are removed. State index entry gets thin stubs
pointing at `archive.json`.

#### Write order (BLK-3 invariant)

1. Write `features/<slug>/phases/NN.json` (bulk) — atomic temp+rename.
2. Update `state.json` index with `{ref, summary}` — atomic temp+rename.

On startup, `forge repair` scans for partial writes:
- Ref locator file missing → mark phase `pending`, drop ref.
- Bulk file exists but no index ref → rebuild ref from bulk.

#### Hot vs cold access

| What | Where | Enters context |
|------|-------|----------------|
| Active feature status | state.json thin index | slice output only (~1k chars) |
| Phase bulk (artifacts, decisions) | phases/NN.json | only when a phase explicitly derefs |
| Archived feature history | archive.json | only on demand |
| Ghost project snapshots | forge-ghost/<slug> branch in project repo | only via ghost-diff |

#### carry_forward semantics

carry_forward = **PER-PHASE** (the `summary` field in the ref envelope). Each phase's summary
is that phase's handoff hint for the next phase. To access older phase data: explicit deref of
that phase's NN.json. This prevents index growing linearly with phase count.

#### Cross-repo SHA (ghost refs)

Ghost refs carry `repo: "project"`. Deref MUST target project's `.git`, not `.forge/.git`.
The forge commit trailer `ghost-sha:` is always a project-repo SHA.

---

## Change Log

### Version 2.0 (2026-08-20)
- Thin index: phase entries now hold `{ref, summary}` only; bulk in `phases/NN.json`
- Ref envelope schema (type/repo/locator/summary) per REF-SPEC.md
- Archive verb: terminal feature bulk → `archive.json`, stub in index
- Version field bumped to "2.0" for future auto-migrate detection
- Repair verb: detects dangling refs + orphan bulk files

### Version 1.0 (2026-04-10)
- Initial schema definition
- Phases 1-12 structure
- Dependency graph with forward/backward edges
- Operations.jsonl append-only log
- Review findings schema

---

**Status:** Canonical reference document for Forge state management
**Audience:** Orchestrator skill, state manager, cascade detector, status reporters
**Maintenance:** Update this document if state schema changes
