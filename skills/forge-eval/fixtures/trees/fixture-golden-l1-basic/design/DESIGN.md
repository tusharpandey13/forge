# Design: forge-eval MVP

## Overview
Offline deterministic regression-fixture evaluation engine for forge workflow.

## Architecture
- Grader engine: YAML rubrics + JSON fixtures
- L1-L5 process-compliance checks
- Bash + jq + yq only

## Key Components
1. Grader runner (bash)
2. Check functions (embedded)
3. Fixture corpus (golden + known-wrong)
4. Self-test harness

## Exit Semantics
- 0: all checks passed, work_count > 0
- 1: any check failed OR work_count == 0
