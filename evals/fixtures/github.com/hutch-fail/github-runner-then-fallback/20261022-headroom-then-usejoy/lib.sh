#!/usr/bin/env bash
# Helpers for 20261022-headroom-then-usejoy (blank lines break bash-budget runs).
set -euo pipefail

miss() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_action_defaults() {
  local action="$1"
  [[ -f "${action}" ]] || miss "missing action.yml"

  grep -q '^  final-runner:' "${action}" || miss "action.yml missing final-runner input"
  grep -q '^  usage-threshold:' "${action}" || miss "action.yml missing usage-threshold input"
  grep -q '^  blacksmith-included-minutes:' "${action}" || miss "action.yml missing blacksmith-included-minutes"
  grep -q '^  blacksmith-api-token:' "${action}" || miss "action.yml missing blacksmith-api-token"
  grep -q 'INPUT_FINAL_RUNNER' "${action}" || miss "action.yml does not pass INPUT_FINAL_RUNNER"

  grep -Eq 'default:[[:space:]]*usejoy-2vcpu-ubuntu-2404' "${action}" \
    || miss "action.yml final-runner should default to usejoy-2vcpu-ubuntu-2404"
  grep -Eq 'default:[[:space:]]*"80"' "${action}" \
    || miss "action.yml usage-threshold should default to 80"
  grep -Eq 'default:[[:space:]]*"2000"' "${action}" \
    || miss "action.yml included-minutes should default to 2000"
  grep -Eq 'default:[[:space:]]*"3000"' "${action}" \
    || miss "action.yml blacksmith-included-minutes should default to 3000"
}

assert_decide_chain() {
  local decide="$1"
  [[ -f "${decide}" ]] || miss "missing scripts/decide.sh"

  grep -q '^choose_runner()' "${decide}" || miss "decide.sh missing choose_runner()"
  grep -q '^under_headroom()' "${decide}" || miss "decide.sh missing under_headroom()"
  grep -q 'fetch_blacksmith_billable_minutes' "${decide}" || miss "decide.sh missing Blacksmith usage fetch"
  grep -q 'mode="chain"' "${decide}" || miss "decide.sh missing chain mode"
}

assert_docs_and_workflow() {
  local root="$1"
  local readme="${root}/README.md"
  local wf="${root}/.github/workflows/determine-runner.yml"
  local ci="${root}/.github/workflows/ci.yml"
  local smoke="${root}/.github/workflows/smoke-determine-runner.yml"
  [[ -f "${readme}" ]] || miss "missing README.md"

  grep -Eq 'final-runner|FINAL_RUNNER' "${readme}" || miss "README missing final-runner docs"
  grep -Eq 'usage-threshold|USAGE_THRESHOLD' "${readme}" || miss "README missing usage-threshold docs"
  grep -Eq 'determine-runner' "${readme}" || miss "README missing determine-runner example"

  [[ -f "${wf}" ]] || miss "missing reusable determine-runner.yml"
  grep -Eq 'default:[[:space:]]*usejoy-2vcpu-ubuntu-2404' "${wf}" \
    || miss "determine-runner.yml final-runner should default to usejoy"
  grep -Eq '^[[:space:]]+detect-runner:' "${wf}" \
    || miss "determine-runner.yml missing detect-runner input"
  detect_default="$(awk '/^[[:space:]]+detect-runner:/{p=1; next} p && /^[[:space:]]+default:/{print $2; exit}' "${wf}")"
  [[ "${detect_default}" == "ubuntu-latest" ]] \
    || miss "determine-runner.yml detect-runner should default to ubuntu-latest (got ${detect_default:-empty})"
  if grep -Eq 'runs-on:.*inputs\.final-runner' "${wf}"; then
    miss "determine job runs-on must not use final-runner (detect is GitHub-hosted)"
  fi

  [[ -f "${ci}" ]] || miss "missing ci.yml"
  grep -Eq 'runs-on:[[:space:]]*ubuntu-latest' "${ci}" || miss "ci.yml must pin ubuntu-latest (bootstrap)"
  if grep -Eq '^[[:space:]]*uses:[[:space:]].*(determine-runner|github-runner-then-fallback)' "${ci}"; then
    miss "ci.yml must not call the picker (bootstrap catch-22)"
  fi

  [[ -f "${smoke}" ]] || miss "missing smoke-determine-runner.yml"
  # Caller cannot set job-level continue-on-error with uses:; pass under with:.
  if grep -Eq '^[[:space:]]{4}continue-on-error:' "${smoke}"; then
    miss "smoke must not set job-level continue-on-error (invalid with uses:)"
  fi
  grep -Eq '^[[:space:]]{6,}continue-on-error:[[:space:]]*true' "${smoke}" \
    || miss "smoke must pass continue-on-error: true under with:"
}

assert_choose_runner_cases() {
  local decide="$1"
  # shellcheck source=/dev/null
  source "${decide}"
  local got

  got="$(choose_runner chain 1000 2000 100 3000 80)"
  [[ "${got}" == "primary" ]] || miss "choose_runner expected primary under GHA headroom; got ${got}"

  got="$(choose_runner chain 1600 2000 1000 3000 80)"
  [[ "${got}" == "fallback" ]] || miss "choose_runner expected fallback at 80% GHA; got ${got}"

  got="$(choose_runner chain 1800 2000 2400 3000 80)"
  [[ "${got}" == "final" ]] || miss "choose_runner expected final at 80% both; got ${got}"

  got="$(choose_runner two-way 1500 2000 "" "" 100)"
  [[ "${got}" == "primary" ]] || miss "two-way default still primary under budget; got ${got}"
}
