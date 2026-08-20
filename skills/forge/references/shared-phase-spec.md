# Shared Phase Spec

Canonical reference for boilerplate shared across all forge phase skills.

---

## § sidecar-schema

Each phase writes a `.phase-N-output.json` sidecar to `{feature_dir}/`. Full absolute path provided by orchestrator at dispatch time.

Schema:
```json
{
  "phase": <N>,
  "status": "completed",
  "artifacts": [
    {
      "path": "<absolute path to artifact>",
      "sha": "<git SHA of artifact>",
      "size_bytes": <file size>
    }
  ],
  "decisions": [
    "<key decision or summary>"
  ],
  "execution_details": {
    "model": "<model used>",
    "reasoning_lines": <count>,
    "context_usage_percent": <%>,
    "elapsed_seconds": <duration>
  }
}
```

Phases that include a quality gate append:
```json
  "quality_gate": {
    "passed": <bool>,
    "tool_version": "<version string>",
    "work_count": <N>,
    "exit_code": <N>,
    "deviations": ["<deviation description>"]
  }
```

---

## § error-cases

Standard "Before Starting" error cases for all phases:

1. **State missing/invalid** — `.forge/state.json` not found or corrupted → ERROR: "state.json missing or corrupted. Run /forge to reinitialize." Do not proceed; return error.

2. **Prereq phase not complete** — Required upstream phase status is not "completed" or "approved" → ERROR: "Phase N (<name>) must be completed/approved first. Current status: {{ phase_N.status }}" Return error; do not start.

3. **Config not found** — `.forge/FORGE-CONFIG.md` missing → WARN or ERROR per skill (see individual skill). Continue with best-effort or escalate.

4. **Output not writable** — `{feature_dir}/<subdir>/` cannot be created or written to → ERROR: "Cannot write to {{ output_path }}: {{ reason }}" Return error; do not write `.phase-N-output.json`.

---

## § orchestrator-note

**Orchestrator updates state.json — skill does NOT write state.json directly.**

Flow:
- Skill writes `.phase-N-output.json` sidecar
- Orchestrator reads sidecar → updates state.json with artifacts, decisions, execution details
- Orchestrator commits to `.forge` git

---

## § feature-dir-note

`{feature_dir}` is resolved by the orchestrator to an **absolute path** before dispatch. Example: `/Users/alice/project/.forge/features/auth-middleware/`. All paths in skill examples show both the variable form (`{feature_dir}/...`) and a concrete example.

---

## § self-validate

Before completing each phase, re-read the primary output artifact. Verify:
- No `[placeholder]`, `[TBD]`, or similar markers remain
- All required sections have content
- Cross-reference IDs are consistent with upstream artifacts

Fix any issues silently.

---

## § mandatory-first-output

Every phase skill MUST emit its phase banner as the **first output** before any other work:
```
FORGE :: <PHASE NAME>
```
This signals to the orchestrator and user which phase is running.
