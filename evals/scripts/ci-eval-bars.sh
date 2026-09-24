#!/usr/bin/env bash
# CI helper for eval-ci.yml: run make eval/bars against the caller workspace.
# Usage: ci-eval-bars.sh <kit_dir> [scan_root]
#   kit_dir: hub Makefile root (GITHUB_WORKSPACE when evals_path is ".", else .evals-hub)
#   scan_root: product root to scan (default: GITHUB_WORKSPACE or cwd)
#
# Thin Actions step — all bar logic lives in scripts/eval-bars.sh (shellcheckable).
set -euo pipefail

kit="${1:-.}"
scan_root="${2:-${GITHUB_WORKSPACE:-${PWD}}}"

[[ -d "${kit}" ]] || {
  printf 'error: kit_dir not a directory: %s\n' "${kit}" >&2
  exit 1
}
[[ -d "${scan_root}" ]] || {
  printf 'error: scan_root not a directory: %s\n' "${scan_root}" >&2
  exit 1
}

scan_root="$(cd "${scan_root}" && pwd)"
kit="$(cd "${kit}" && pwd)"

export HERMES_EVAL_KIT="${kit}"
export HERMES_EVAL_SCAN_ROOT="${scan_root}"
export HERMES_EVAL_REPO_ROOT="${scan_root}"

if [[ -f "${kit}/Makefile" ]] && grep -Eq '^[[:space:]]*eval/bars:' "${kit}/Makefile"; then
  make --no-print-directory -C "${kit}" eval/bars
  exit $?
fi

# Fallback when Makefile target missing (older pin) — still prefer Make.
bash "${kit}/scripts/eval-bars.sh"
