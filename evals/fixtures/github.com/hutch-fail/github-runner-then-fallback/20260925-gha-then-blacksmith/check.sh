#!/usr/bin/env bash
# F2P: prefer GHA then Blacksmith + create-github-app-token client-id.
set -euo pipefail

root="${HERMES_EVAL_REPO_ROOT:-}"
[[ -n "${root}" && -d "${root}" ]] || { echo "HERMES_EVAL_REPO_ROOT unset" >&2; exit 1; }

fail=0
miss() { printf '%s\n' "$*" >&2; fail=1; }

wf_dir="${root}/.github/workflows"
[[ -d "${wf_dir}" ]] || { miss "missing .github/workflows"; exit 1; }

# 1) Any workflow with a local work-job runs-on label must have determine-runner
#    (except github-runner-then-fallback/ci.yml which is Blacksmith-only by design).
while IFS= read -r -d '' f; do
  rel="${f#"${root}/"}"
  base="$(basename "${f}")"
  if [[ "${rel}" == ".github/workflows/ci.yml" ]] && grep -q 'do not dogfood prefer-GHA' "${f}" 2>/dev/null; then
    continue
  fi
  # Skip pure thin callers (only uses: hutch-fail/, no local runs-on jobs except none)
  if ! grep -Eq '^[[:space:]]+runs-on:' "${f}"; then
    continue
  fi
  # If file has determine-runner, require fromJson + fallback action
  if grep -Eq '^[[:space:]]*determine-runner(-[A-Za-z0-9_-]+)?:[[:space:]]*$' "${f}"; then
    grep -Eq 'uses:[[:space:]]*hutch-fail/github-runner-then-fallback' "${f}" \
      || miss "${rel}: missing github-runner-then-fallback"
    grep -Eq 'runs-on:[[:space:]]*\$\{\{[[:space:]]*fromJson\(' "${f}" \
      || miss "${rel}: missing fromJson runs-on"
    grep -Eqi 'primary-runner:[[:space:]]*ubuntu-' "${f}" \
      || miss "${rel}: primary-runner must be ubuntu-*"
    grep -Eqi 'fallback-runner:[[:space:]]*blacksmith-' "${f}" \
      || miss "${rel}: fallback-runner must be blacksmith-*"
    continue
  fi
  # Local runs-on without determine-runner: only allow if every runs-on is an expression
  # already dynamic, or this is unexpected
  if grep -Eq '^[[:space:]]+runs-on:[[:space:]]*(blacksmith-|ubuntu-)' "${f}"; then
    miss "${rel}: hardcoded runs-on without determine-runner"
  fi
done < <(find "${wf_dir}" -name '*.yml' -print0 2>/dev/null)

# 2) create-github-app-token must use client-id, not app-id / installation-id
while IFS= read -r -d '' f; do
  rel="${f#"${root}/"}"
  if ! grep -q 'create-github-app-token' "${f}"; then
    continue
  fi
  # crude: if app-id: appears as a with: input near the action
  if grep -Eq '^[[:space:]]+app-id:' "${f}"; then
    miss "${rel}: create-github-app-token must use client-id not app-id"
  fi
  if grep -Eq '^[[:space:]]+installation-id:' "${f}"; then
    miss "${rel}: create-github-app-token must not pass installation-id"
  fi
  if grep -q 'create-github-app-token' "${f}" && ! grep -Eq '^[[:space:]]+client-id:' "${f}"; then
    miss "${rel}: create-github-app-token missing client-id"
  fi
done < <(find "${wf_dir}" -name '*.yml' -print0 2>/dev/null)

# 3) Thin callers that uses: hutch-fail hubs should map ORG_BILLING_TOKEN (or inherit)
while IFS= read -r -d '' f; do
  rel="${f#"${root}/"}"
  if ! grep -Eq 'uses:[[:space:]]*hutch-fail/(evals|pre-commit|platform-ci|actions)/' "${f}"; then
    continue
  fi
  if grep -Eq 'secrets:[[:space:]]*inherit' "${f}"; then
    continue
  fi
  grep -Fq 'ORG_BILLING_TOKEN' "${f}" \
    || miss "${rel}: thin caller must map ORG_BILLING_TOKEN (or secrets: inherit)"
done < <(find "${wf_dir}" -name '*.yml' -print0 2>/dev/null)

if grep -REq '^[[:space:]]*uses:[[:space:]]*useblacksmith/checkout' "${wf_dir}" 2>/dev/null; then
  miss "must not use useblacksmith/checkout"
fi

[[ "${fail}" -eq 0 ]] || exit 1
echo "gha_then_blacksmith_ok"
