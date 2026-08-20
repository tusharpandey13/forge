# Auto-Write: Phase Persistence Triggers (WS-F F2)

Forge has two complementary auto-write triggers that ensure phase output is persisted to
`.forge` git, covering both normal completion and interrupted sessions.

---

## Trigger A: Phase Completion (Commit Hook)

**Path**: `forge commit-phase` (via `bin/lib/commit.sh`) or `forge autowrite-phase` (convenience wrapper).

**When it fires**: Every time a phase completes — either called directly from the orchestrator
SKILL.md or via the convenience wrapper `forge autowrite-phase`.

**What it persists**:
1. `forge merge <slug> <phase> <output-json>` — merges phase output into state index (thin).
2. `forge mark-complete <slug> <phase> <status>` — writes bulk `NN.json` (artifacts, decisions,
   carry_forward) and updates thin index entry. **BLK-3 write order: bulk first, index second.**
3. `forge commit-phase <slug> <phase> <status>` — commits staged `.forge/` state to
   `.forge/.git` with trailers (`ghost-sha:`, `artifacts:`, `feature:`, `phase:`, `status:`).

**Convenience verb** (`forge autowrite-phase`): does all three steps in sequence. Use when the
orchestrator wants to complete a phase in one call:

```bash
forge autowrite-phase <slug> <phase> <status> \
  --output-json /path/to/phase-output.json \
  --log-line "phase N complete: <summary>" \
  --carry "<carry_forward text>" \
  --ghost-sha <project-sha>
```

**Invariants**:
- `commit-phase` already fires on every phase completion in the WS-B exec layer.
- The carry_forward and ref are committed to `.forge/.git` as part of the phase commit.
- This is the "optimistic auto-write during active run" from CONTEXT.md.

---

## Trigger B: Session Stop Hook

**File**: `skills/forge/bin/hooks/forge-stop-hook.sh`

**When it fires**: On Claude Code session Stop (graceful or interrupted).

**What it does**: Scans state.json for any phase with status `in_progress`/`active`/`started`/
`running`, then calls `forge commit-phase` for each, tagging the commit with log line
`"session-stop: partial flush from forge-stop-hook"`. This captures partial carry_forward and
current state across sessions.

**Safety**: Always exits 0. Errors are logged to stderr and swallowed — hook failure never
blocks Claude Code shutdown.

---

## Registering the Stop Hook in settings.json

**Do NOT edit `~/.claude/settings.json` directly.** Add the snippet below to your settings:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/tushar.pandey/src/forge/skills/forge/bin/hooks/forge-stop-hook.sh"
          }
        ]
      }
    ]
  }
}
```

**Steps to register**:
1. Open `~/.claude/settings.json` (or your project's `.claude/settings.json`).
2. If a `"hooks"` key already exists, merge the `"Stop"` array entry into it.
3. If `"hooks"` doesn't exist, add the entire block above.
4. Save. The hook fires automatically on next session Stop.

**Tip**: If your forge source lives at a different path, update the `command` value to the
absolute path of `forge-stop-hook.sh`. You can also set `FORGE_HOOK_BIN=/path/to/bin/forge`
in the hook's environment to override forge binary discovery.

---

## Flow Diagram

```
Phase completes normally:
  orchestrator → forge autowrite-phase (or merge+mark-complete+commit-phase)
                → .forge/.git commit (ref + carry_forward persisted)

Session interrupted:
  Claude Code Stop → forge-stop-hook.sh
                   → finds in-progress phases via state.json
                   → forge commit-phase (session-stop tag)
                   → .forge/.git commit (partial state captured)
```

---

## Relation to commit-phase (WS-B)

`commit-phase` (in `bin/lib/commit.sh`) is the **core persistence primitive**. It:
- Stages all `.forge/` state (state.json + phase bulk files).
- Commits to `.forge/.git` with structured trailers.
- Updates `state.json` `latest_commit` pointer.

Both auto-write triggers call `commit-phase` — they are wrappers, not replacements.
