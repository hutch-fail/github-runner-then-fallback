#!/usr/bin/env bash
# F2P: opt-in headroom chain (GHA → Blacksmith → final/usejoy) is wired.
set -euo pipefail

root="${HERMES_EVAL_REPO_ROOT:-${HERMES_EVAL_SCAN_ROOT:-$PWD}}"
action="${root}/action.yml"
decide="${root}/scripts/decide.sh"
readme="${root}/README.md"
tests="${root}/tests/test_decide_helpers.sh"

miss() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[[ -f "${action}" ]] || miss "missing action.yml"
[[ -f "${decide}" ]] || miss "missing scripts/decide.sh"
[[ -f "${readme}" ]] || miss "missing README.md"

grep -q '^  final-runner:' "${action}" || miss "action.yml missing final-runner input"
grep -q '^  usage-threshold:' "${action}" || miss "action.yml missing usage-threshold input"
grep -q '^  blacksmith-included-minutes:' "${action}" || miss "action.yml missing blacksmith-included-minutes"
grep -q '^  blacksmith-api-token:' "${action}" || miss "action.yml missing blacksmith-api-token"
grep -q 'INPUT_FINAL_RUNNER' "${action}" || miss "action.yml does not pass INPUT_FINAL_RUNNER"

grep -q '^choose_runner()' "${decide}" || miss "decide.sh missing choose_runner()"
grep -q '^under_headroom()' "${decide}" || miss "decide.sh missing under_headroom()"
grep -q 'fetch_blacksmith_billable_minutes' "${decide}" || miss "decide.sh missing Blacksmith usage fetch"
grep -q 'mode="chain"' "${decide}" || miss "decide.sh missing chain mode"

grep -Eq 'final-runner|FINAL_RUNNER' "${readme}" || miss "README missing final-runner docs"
grep -Eq 'usage-threshold|USAGE_THRESHOLD' "${readme}" || miss "README missing usage-threshold docs"
grep -Eq 'determine-runner' "${readme}" || miss "README missing determine-runner example"

# Offline predicate: empty meter on GitHub skips to Blacksmith; both empty → final.
# shellcheck source=/dev/null
source "${decide}"
got="$(choose_runner chain 1000 2000 100 3000 80)"
[[ "${got}" == "primary" ]] || miss "choose_runner expected primary under GHA headroom; got ${got}"
got="$(choose_runner chain 1600 2000 1000 3000 80)"
[[ "${got}" == "fallback" ]] || miss "choose_runner expected fallback at 80% GHA; got ${got}"
got="$(choose_runner chain 1800 2000 2400 3000 80)"
[[ "${got}" == "final" ]] || miss "choose_runner expected final at 80% both; got ${got}"
got="$(choose_runner two-way 1500 2000 "" "" 100)"
[[ "${got}" == "primary" ]] || miss "two-way default still primary under budget; got ${got}"

if [[ -f "${tests}" ]]; then
  grep -q 'choose_runner chain' "${tests}" || miss "tests missing chain choose_runner cases"
fi

echo headroom_then_usejoy_ok
