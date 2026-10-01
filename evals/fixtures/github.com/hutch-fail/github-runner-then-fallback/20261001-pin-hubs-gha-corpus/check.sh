#!/usr/bin/env bash
# F2P: every thin hub caller this pack covers must pin the tip SHAs.
set -euo pipefail
root="${HERMES_EVAL_REPO_ROOT:-${HERMES_EVAL_SCAN_ROOT:-$PWD}}"
wf="${root}/.github/workflows"
EVALS_PIN='e3a7201ed6e09a1cdc9a02c0e19dcda6848b8d5c'
PC_PIN='dfd996508e0d1d4c06ac904e4ce883600125e0d1'
fail=0
miss() { printf '%s\n' "$*" >&2; fail=1; }

[[ -d "${wf}" ]] || { echo "missing .github/workflows" >&2; exit 1; }

# evals callers (eval-ci and any sibling reusable callers that pin hutch-fail/evals)
shopt -s nullglob
for f in "${wf}"/eval-ci.yml "${wf}"/eval-pack.yml "${wf}"/eval-select.yml; do
  [[ -f "$f" ]] || continue
  if grep -qE 'hutch-fail/evals/.github/workflows/[^@]+@' "$f"; then
    grep -Fq "$EVALS_PIN" "$f" || miss "$(basename "$f") missing evals pin ${EVALS_PIN}"
  fi
  if grep -qE '^[[:space:]]*hub_ref:' "$f"; then
    grep -Eq "^[[:space:]]*hub_ref:[[:space:]]*${EVALS_PIN}$" "$f"       || miss "$(basename "$f") hub_ref must be ${EVALS_PIN}"
  fi
done

# pre-commit thin callers
for f in "${wf}"/pre-commit.yml "${wf}"/pre-commit-ci.yml; do
  [[ -f "$f" ]] || continue
  if grep -qE 'hutch-fail/pre-commit/.github/workflows/pre-commit.yml@' "$f"; then
    grep -Fq "$PC_PIN" "$f" || miss "$(basename "$f") missing pre-commit pin ${PC_PIN}"
  fi
done

[[ "${fail}" -eq 0 ]] || exit 1
echo pin_hubs_gha_corpus_ok
