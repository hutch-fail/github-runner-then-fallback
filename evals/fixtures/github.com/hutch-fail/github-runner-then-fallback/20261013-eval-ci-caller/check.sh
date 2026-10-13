#!/usr/bin/env bash
set -euo pipefail
root="${HERMES_EVAL_REPO_ROOT:-${HERMES_EVAL_SCAN_ROOT:-$PWD}}"
f="${root}/.github/workflows/eval-ci.yml"
[[ -f "$f" ]] || { echo "missing eval-ci.yml" >&2; exit 1; }
grep -q "5c075e0dc3e3fc97eafe8c39b47580907adaad4d" "$f" || { echo "hub pin missing 5c075e0dc3e3fc97eafe8c39b47580907adaad4d" >&2; exit 1; }
echo eval_ci_caller_ok
