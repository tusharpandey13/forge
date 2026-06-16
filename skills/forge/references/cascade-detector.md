# Cascade Detector Specification

## Overview

Cascade detector analyzes the dependency graph in state.json to determine impact of artifact changes. Two primary use cases:

1. **On Review Approval:** If a phase artifact is approved after review, check if downstream phases are still valid
2. **On Change Detection:** If artifact changes after approval, mark affected phases as invalidated
3. **On User Request:** User can query: "what's affected by changes to DESIGN.md?"

## Algorithm: detect_affected(changed_artifact_path)

### Input

- `changed_artifact_path` (string): Absolute path to artifact that changed (e.g., `.forge/features/auth-middleware/design/DESIGN.md`)
- `state` (state.json): Current feature state
- `feature_id` (string): Active feature identifier

### Output

```json
{
  "downstream": [
    {
      "path": ".forge/features/auth-middleware/plan/IMPL-PLAN.md",
      "phase": 4,
      "reason": "Plan depends on Design"
    }
  ],
  "upstream": [
    {
      "path": ".forge/features/auth-middleware/requirement/REQUIREMENTS.md",
      "phase": 1,
      "reason": "Design depends on Requirements; Requirements unchanged but context may have changed"
    }
  ],
  "invalidation_action": "mark phases 4,6,8,10 as invalidated if design is significant change"
}
```

### Pseudocode

```
FUNCTION detect_affected(changed_artifact_path, state):
    feature_id = state.features | find .is_active

    // Look up changed artifact in dependency_graph.backward (what it depends on)
    upstream_deps = state.dependency_graph.backward[changed_artifact_path] OR []

    // Look up changed artifact in dependency_graph.forward (what depends on it)
    downstream_deps = state.dependency_graph.forward[changed_artifact_path] OR []

    result = {
        downstream: [],
        upstream: [],
        invalidation_action: ""
    }

    // Build downstream results
    FOR each downstream_path IN downstream_deps:
        downstream_phase = find_phase(downstream_path, state)
        result.downstream.append({
            path: downstream_path,
            phase: downstream_phase.number,
            reason: reason_for_dependency(changed_artifact_path, downstream_path)
        })

    // Build upstream results (mark for re-review, not invalidation)
    FOR each upstream_path IN upstream_deps:
        upstream_phase = find_phase(upstream_path, state)
        result.upstream.append({
            path: upstream_path,
            phase: upstream_phase.number,
            reason: reason_for_dependency(upstream_path, changed_artifact_path)
        })

    // Determine invalidation strategy based on artifact type
    result.invalidation_action = cascade_rule(changed_artifact_path, state)

    RETURN result
END FUNCTION
```

## Cascade Rules per Artifact Type

### REQUIREMENTS.md Change

**Condition:** Phase 1 artifact changed after approval

**Downstream Impact:** Invalidate phases 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
- All downstream work depends on requirements
- Changes cascade through all subsequent phases

**Upstream Impact:** None (phase 1 is origin)

**Rationale:** Requirement changes affect all downstream work. No upstream dependencies.

---

### DESIGN.md Change (After Phase 2 Approved)

**Condition:** Phase 2 artifact changed after approval

**Downstream Impact:** Invalidate phases 4, 5, 6, 7, 8, 9, 10, 11
- Implementation Planning (Phase 4) depends directly on Design
- Test Planning (Phase 6) uses Design as reference
- Code Implementation (Phase 8) implements Design
- Test Implementation (Phase 10) tests Design contracts
- Documentation (Phase 12) references Design

**Upstream Impact:** Mark phase 1 (Requirements) for re-review
- Design changes may have revealed requirement gaps
- Requirements context may need re-validation
- Not automatically invalidated; marked for human review

**Rationale:** Design changes require plan + code rework. Requirements may need re-validation if design discovered new dependencies or constraints.

---

### IMPL-PLAN.md Change (After Phase 4 Approved)

**Condition:** Phase 4 artifact changed after approval

**Downstream Impact:** Invalidate phases 6, 7, 8, 9, 10, 11
- Test Planning (Phase 6) based on implementation strategy
- Code Implementation (Phase 8) follows the plan
- Code Review (Phase 9) validates against plan
- Test Implementation (Phase 10) based on test strategy in plan
- Test Review (Phase 11) validates test coverage

**Upstream Impact:** Mark phases 2, 3 (Design + Design Review) for re-review
- Implementation plan may have revealed design issues
- Design may need adjustment based on implementation feasibility
- Code Review findings may suggest Design changes

**Rationale:** Implementation plan changes require test plan + code rework. Design may need re-validation.

---

### TEST-PLAN.md Change (After Phase 6 Approved)

**Condition:** Phase 6 artifact changed after approval

**Downstream Impact:** Invalidate phases 8, 9, 10, 11
- Code Implementation (Phase 8) may be affected if test requirements changed
- Code Review (Phase 9) needs updated context
- Test Implementation (Phase 10) implements the test plan
- Test Review (Phase 11) validates against test plan

**Upstream Impact:** Mark phases 4, 5 (Impl Plan + Impl Plan Review) for re-review
- Test plan changes may require implementation changes
- Implementation strategy may need adjustment

**Rationale:** Test plan changes may require implementation changes. Implementation plan may need re-validation.

---

### Code/Implementation Change (After Phase 8 Approved)

**Condition:** Phase 8 artifacts (source code) changed after approval

**Downstream Impact:** Invalidate phases 10, 11
- Test Implementation (Phase 10) tests the implementation
- Test Review (Phase 11) validates tests against implementation

**Upstream Impact:** Mark phase 9 (Code Review) for update
- Code Review must re-examine changes
- Reviewer needs full context on what changed

**Rationale:** Code changes require test updates and re-review. Test patterns must match implementation changes.

---

### Test Code Change (After Phase 10 Approved)

**Condition:** Phase 10 artifacts (test code) changed after approval

**Downstream Impact:** Invalidate phase 12 (Documentation)
- Documentation may reference test patterns
- Test patterns affect documented behavior

**Upstream Impact:** Mark phase 9 (Code Review) for context
- Code Review should understand why tests changed
- May indicate implementation issues

**Rationale:** Test changes usually indicate implementation issues or pattern refinements. Documentation should reflect current test approach.

---

## Algorithm: mark_invalidated(phases_to_invalidate, state)

For each phase in the invalidation list:

```
FOR each phase_num IN phases_to_invalidate:
    IF state.phases[phase_num].status == "approved" OR state.phases[phase_num].status == "completed":
        state.phases[phase_num].status = "invalidated"
        state.phases[phase_num].completed = null  // Clear completion marker
        state.phases[phase_num].artifacts = []    // Clear artifacts (will be regenerated)
        state.phases[phase_num].execution_details = null

        APPEND to operations.jsonl:
        {
            ts: now,
            op: "cascade_detect",
            changed_artifact: original_artifact_path,
            invalidated_phase: phase_num,
            message: "Cascade: phase invalidated due to upstream change"
        }
    ELSE:
        // Phase not yet done; no action needed (still in pending or in_progress state)
    END IF
END FOR
```

**Key Semantics:**
- Only approved/completed phases are invalidated (pending phases unchanged)
- In-progress phases are left as-is; if task agent is still working, it will complete and state will be overwritten
- Invalidation clears artifacts (next phase run generates new ones)
- Each invalidation creates an audit trail in operations.jsonl

---

## Integration with Orchestrator

Orchestrator calls cascade detector in three scenarios:

### 1. After Review Phase Approval

```
IF phase IN [3, 5, 7, 9, 11]:  // Review phases
    IF phase.review_findings.gate == "PASS":
        affected = cascade_detector.detect_affected(phase.artifacts[0].path, state)

        // Log for observability
        IF affected.downstream not empty:
            OUTPUT: "Design change may affect downstream phases"
            QUERY USER: "Continue to next phase or inspect cascade?"

        // Mark upstream phases for re-review (non-blocking)
        FOR each upstream_artifact IN affected.upstream:
            LOG: "Note: upstream phase may need re-validation"
END IF
```

### 2. On Explicit User Request

```
// Command: forge affected <artifact-path>
// Show impact analysis without invalidation

FUNCTION affected_command(artifact_path):
    affected = cascade_detector.detect_affected(artifact_path, state)

    OUTPUT: "Changed artifact: {{ artifact_path }}"
    OUTPUT: ""
    OUTPUT: "Downstream impacts (depends on changed artifact):"
    FOR each downstream IN affected.downstream:
        OUTPUT: "  Phase {{ downstream.phase }}: {{ phase_name }} → INVALIDATED"

    OUTPUT: ""
    OUTPUT: "Upstream impacts (changed artifact depends on these):"
    FOR each upstream IN affected.upstream:
        OUTPUT: "  Phase {{ upstream.phase }}: {{ phase_name }} → marked for re-review"

    OUTPUT: ""
    OUTPUT: "Suggested action: Run 'forge cascade-fix' to re-execute all invalidated phases"
END FUNCTION
```

### 3. On Manual Phase Re-Run

```
// When user manually re-runs a phase and new artifacts are produced

FUNCTION phase_rerune_with_cascade_check(phase_num, new_artifacts):
    // Compare old and new artifacts
    old_artifacts = state.phases[phase_num].artifacts

    IF artifacts_differ(old_artifacts, new_artifacts):
        // Detect cascade for each new artifact
        FOR each new_artifact IN new_artifacts:
            affected = cascade_detector.detect_affected(new_artifact.path, state)

            IF affected.downstream not empty:
                // Mark downstream phases as invalidated
                cascade_detector.mark_invalidated(affected.downstream, state)

                OUTPUT: "Artifact changed. Downstream phases marked invalid:"
                FOR each invalid_phase IN affected.downstream:
                    OUTPUT: "  - Phase {{ invalid_phase }}"
END IF
```

---

## UI Commands

### forge affected

Show impact analysis for a changed artifact without invalidating.

```
# Show impact analysis for a changed artifact
forge affected .forge/features/auth-middleware/design/DESIGN.md

OUTPUT:
  Changed: .forge/features/auth-middleware/design/DESIGN.md

  Downstream impacts (depends on changed artifact):
    Phase 4: Implementation Planning → INVALIDATED
    Phase 6: Test Planning → INVALIDATED
    Phase 8: Code Implementation → INVALIDATED
    Phase 10: Test Implementation → INVALIDATED

  Upstream impacts (changed artifact depends on these):
    Phase 1: Requirements → marked for re-review (no changes required)

  Suggested action: Run "forge cascade-fix" to re-execute all invalidated phases
```

### forge cascade-fix

Automatically re-run all invalidated phases in dependency order.

```
# Automatically re-run all invalidated phases in dependency order
forge cascade-fix

PROCESS:
  1. Find all phases with status="invalidated"
  2. Order by phase number (lowest first; respects dependencies)
  3. For each phase:
     - Dispatch to task agent
     - Wait for completion
     - Update state.json
     - Detect cascade for new artifacts
     - Continue to next phase

OUTPUT:
  Invalidated phases found: 4
  Re-executing in order:
    Phase 4: Implementation Planning [⏳ in_progress]
    Phase 6: Test Planning [⏳ in_progress]
    Phase 8: Code Implementation [⏳ in_progress]
    Phase 10: Test Implementation [⏳ in_progress]

  [After all complete]
  ✓ Phase 4: Implementation Planning [✓ approved]
  ✓ Phase 6: Test Planning [✓ approved]
  ✓ Phase 8: Code Implementation [✓ approved]
  ✓ Phase 10: Test Implementation [✓ approved]

  Cascade fix complete. All dependent phases re-executed.
```

### forge cascade-find

Find all artifacts that would be affected by a hypothetical change.

```
# Find what would be affected if requirements changed
forge cascade-find .forge/features/auth-middleware/requirement/REQUIREMENTS.md

OUTPUT:
  Query: What would be affected if REQUIREMENTS.md changed?

  Downstream (directly or transitively):
    Phase 2: Design Creation
    Phase 3: Design Review
    Phase 4: Implementation Planning
    Phase 5: Impl Plan Review
    Phase 6: Test Planning
    Phase 7: Test Plan Review
    Phase 8: Code Implementation
    Phase 9: Code Review
    Phase 10: Test Implementation
    Phase 11: Test Review

  Upstream: (none — requirements are origin)

  Impact: A requirements change affects all 11 downstream phases.
```

---

## Dependency Graph Semantics

### Artifact Dependency vs. Phase Dependency

**Artifact dependency:** Direct reference relationship between artifact files.
- Design depends on Requirements: Design artifact references Requirement constraints
- Plan depends on Design: Plan artifact implements Design components

**Phase dependency:** Execution order relationship between phases.
- Phase 4 depends on Phase 2: Implementation Planning requires Design to be complete

The cascade detector operates on artifact-level dependencies, which map to phase-level propagation.

### Forward vs. Backward Edges

**Forward edges (dependency_graph.forward):**
- Key: Source artifact
- Value: List of artifacts that depend on this one (consumers)
- Used to find downstream impacts

**Backward edges (dependency_graph.backward):**
- Key: Artifact
- Value: List of artifacts this one depends on (dependencies)
- Used to find upstream impacts and validate completeness

Example:

```json
{
  "forward": {
    ".forge/features/auth-middleware/requirement/REQUIREMENTS.md": [
      ".forge/features/auth-middleware/design/DESIGN.md",
      ".forge/features/auth-middleware/plan/IMPL-PLAN.md"
    ],
    ".forge/features/auth-middleware/design/DESIGN.md": [
      ".forge/features/auth-middleware/plan/IMPL-PLAN.md",
      ".forge/features/auth-middleware/plan/TEST-PLAN.md",
      ".forge/features/auth-middleware/code/implementation.md"
    ]
  },
  "backward": {
    ".forge/features/auth-middleware/design/DESIGN.md": [
      ".forge/features/auth-middleware/requirement/REQUIREMENTS.md"
    ],
    ".forge/features/auth-middleware/plan/IMPL-PLAN.md": [
      ".forge/features/auth-middleware/design/DESIGN.md"
    ],
    ".forge/features/auth-middleware/plan/TEST-PLAN.md": [
      ".forge/features/auth-middleware/design/DESIGN.md",
      ".forge/features/auth-middleware/plan/IMPL-PLAN.md"
    ]
  }
}
```

### Inferring Dependency Graph from Artifacts

At feature creation:

```
FUNCTION infer_dependency_graph(feature_dir):
    forward = {}
    backward = {}

    // Standard phase dependencies (always true)
    add_edge(forward, backward, "Phase1", "Phase2")  // Req → Design
    add_edge(forward, backward, "Phase2", "Phase3")  // Design → Review
    add_edge(forward, backward, "Phase2", "Phase4")  // Design → Plan
    add_edge(forward, backward, "Phase2", "Phase6")  // Design → TestPlan
    add_edge(forward, backward, "Phase4", "Phase5")  // Plan → Review
    add_edge(forward, backward, "Phase4", "Phase8")  // Plan → Code
    add_edge(forward, backward, "Phase6", "Phase7")  // TestPlan → Review
    add_edge(forward, backward, "Phase6", "Phase10") // TestPlan → Tests
    add_edge(forward, backward, "Phase8", "Phase9")  // Code → Review
    add_edge(forward, backward, "Phase10", "Phase11")// Tests → Review
    add_edge(forward, backward, "Phase8", "Phase12") // Code → Docs
    add_edge(forward, backward, "Phase10", "Phase12")// Tests → Docs

    // Enhanced: Parse artifact contents for additional references
    // (Implementation detail; not required for basic cascade detection)

    RETURN {forward, backward}
END FUNCTION

FUNCTION add_edge(forward, backward, from_artifact, to_artifact):
    IF from_artifact NOT IN forward:
        forward[from_artifact] = []
    forward[from_artifact].append(to_artifact)

    IF to_artifact NOT IN backward:
        backward[to_artifact] = []
    backward[to_artifact].append(from_artifact)
END FUNCTION
```

---

## Error Handling

### Artifact Not in Dependency Graph

**Scenario:** New artifact created mid-feature; not yet in dependency graph

**Behavior:**
```
IF changed_artifact_path NOT IN state.dependency_graph:
    LOG: "New artifact detected; no cascade computed"
    affected = {
        downstream: [],
        upstream: [],
        invalidation_action: "none"
    }
    RETURN affected
```

**Rationale:** New artifacts have no dependents; no downstream cascade. User can manually register dependencies if needed.

---

### Circular Dependencies

**Scenario:** Dependency graph contains cycle (e.g., A → B → A)

**Behavior:**
```
// Detect cycles during graph traversal
FUNCTION traverse_forward(start_node, visited_set):
    IF start_node IN visited_set:
        LOG: "WARNING: Circular dependency detected in graph"
        RETURN []  // Break cycle; treat node as leaf

    visited_set.add(start_node)
    downstream = []

    FOR each next_node IN graph.forward[start_node]:
        downstream.extend(traverse_forward(next_node, visited_set))

    RETURN downstream
END FUNCTION
```

**Rationale:** Circular dependencies are impossible in phase workflow (phases are strictly ordered 1-12). If detected, log warning and treat as independent nodes.

---

### Phase Not Found for Artifact

**Scenario:** Artifact path references unknown phase

**Behavior:**
```
IF find_phase(artifact_path, state) == null:
    LOG: "ERROR: Artifact path maps to no phase"
    LOG: "Artifact: {{ artifact_path }}"

    // Attempt recovery: try to match artifact to phase by naming convention
    guessed_phase = guess_phase_from_path(artifact_path)

    IF guessed_phase != null:
        LOG: "Guessed phase: {{ guessed_phase }}"
        RETURN {guessed_phase}
    ELSE:
        ESCALATE: "Invalid state.json: artifact path not mappable to phase"
        OFFER: "Recover state from git commit?"
        RETURN error
END IF
```

**Rationale:** State.json corruption detection. Offer recovery path.

---

## Performance Characteristics

- **Time complexity:** O(E) where E = number of edges in dependency graph
- **Space complexity:** O(N + E) where N = number of artifacts, E = edges
- **Typical case (single feature):** < 50ms for full cascade analysis
- **Optimization:** Forward/backward edges provide O(1) lookup (dict/map operations)

---

## Testing Strategy

### Unit Tests

- **UT-1:** Design change → downstream includes [4,6,8,10], upstream includes [1]
- **UT-2:** Requirement change → downstream includes [2-11], upstream is empty
- **UT-3:** Code change → downstream includes [10,11], upstream includes [9]
- **UT-4:** New artifact (not in graph) → empty downstream/upstream
- **UT-5:** Circular dependency → cycle detection log warning, no infinite loop

### Integration Tests

- **IT-1:** Phase approval → detect_affected called, results logged
- **IT-2:** forge affected command → displays downstream/upstream, no invalidation
- **IT-3:** forge cascade-fix → re-runs all invalidated phases in order
- **IT-4:** Cascade invalidation → downstream phases marked with status="invalidated"

---

## Handoff

**Output:** Cascade Detector Specification with complete pseudocode, artifact dependency semantics, cascade rules per phase, integration points with orchestrator, UI commands.

**Used By:**
- Orchestrator (after phase approval, manual phase re-run)
- User commands: `forge affected`, `forge cascade-fix`
- State mutation logic: mark downstream phases as invalidated

**Next:** Unit 1 (State Schema) already complete; cascade detector integrates with Unit 6 (Orchestrator) and Unit 8 (Phase Skills).
