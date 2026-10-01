#!/usr/bin/env bash
set -euo pipefail
root="${HERMES_EVAL_REPO_ROOT:-${HERMES_EVAL_SCAN_ROOT:-$PWD}}"
grep -Rq 'e3a7201ed6e09a1cdc9a02c0e19dcda6848b8d5c' "${root}/.github/workflows" || {
  echo "missing evals pin e3a7201ed6e09a1cdc9a02c0e19dcda6848b8d5c" >&2
  exit 1
}
echo pin_hubs_gha_corpus_ok
