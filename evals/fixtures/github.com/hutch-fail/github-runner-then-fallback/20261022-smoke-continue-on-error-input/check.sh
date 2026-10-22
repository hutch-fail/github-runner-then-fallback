#!/usr/bin/env bash
# F2P: smoke continue-on-error is a reusable workflow input, not a job key.
set -euo pipefail

root="${HERMES_EVAL_REPO_ROOT:-}"
[[ -n "${root}" && -d "${root}" ]] || { echo "HERMES_EVAL_REPO_ROOT unset" >&2; exit 1; }

miss() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

wf="${root}/.github/workflows/determine-runner.yml"
smoke="${root}/.github/workflows/smoke-determine-runner.yml"
[[ -f "${wf}" ]] || miss "missing determine-runner.yml"
[[ -f "${smoke}" ]] || miss "missing smoke-determine-runner.yml"

grep -Eq '^[[:space:]]+continue-on-error:' "${wf}" \
  || miss "determine-runner.yml missing continue-on-error input"
grep -Eq 'continue-on-error:[[:space:]]*\$\{\{[[:space:]]*inputs\.continue-on-error' "${wf}" \
  || miss "determine job must set continue-on-error from inputs"

if grep -Eq '^[[:space:]]{4}continue-on-error:' "${smoke}"; then
  miss "smoke must not set job-level continue-on-error (invalid with uses:)"
fi
grep -Eq '^[[:space:]]{6,}continue-on-error:[[:space:]]*true' "${smoke}" \
  || miss "smoke must pass continue-on-error: true under with:"

grep -Eq 'path:[[:space:]]*_github-runner-then-fallback' "${wf}" \
  || miss "determine-runner.yml must checkout action tree to _github-runner-then-fallback"
grep -Eq 'uses:[[:space:]]*\./_github-runner-then-fallback' "${wf}" \
  || miss "determine-runner.yml must run composite from checked-out path"
if grep -Eq 'uses:[[:space:]]*\./[[:space:]]*$' "${wf}"; then
  miss "determine-runner.yml must not use bare uses: ./ (resolves in caller repo)"
fi

echo smoke_continue_on_error_input_ok
