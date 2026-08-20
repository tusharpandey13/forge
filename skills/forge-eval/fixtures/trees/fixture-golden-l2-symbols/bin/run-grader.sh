#!/usr/bin/env bash
set -euo pipefail

# Check jq and yq
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required"; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "ERROR: yq required"; exit 1; }

run-grader() {
  echo "running grader"
}

echo "OK"
