#!/usr/bin/env bash
set -euo pipefail
root="${HERMES_EVAL_REPO_ROOT:-${HERMES_EVAL_SCAN_ROOT:-$PWD}}"
grep -Rq 'e5b38acde79e3d3dc5051ac4757ca48fc4b8a905' "${root}/.github/workflows" || { echo "missing evals pin e5b38acde79e3d3dc5051ac4757ca48fc4b8a905" >&2; exit 1; }
echo pin_hubs_gha_corpus_ok
