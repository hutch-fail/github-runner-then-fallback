#!/usr/bin/env bash
# F2P: default headroom chain (GHA → Blacksmith → usejoy) is wired.
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${dir}/lib.sh"
root="${HERMES_EVAL_REPO_ROOT:-${HERMES_EVAL_SCAN_ROOT:-$PWD}}"
assert_action_defaults "${root}/action.yml"
assert_decide_chain "${root}/scripts/decide.sh"
assert_docs_and_workflow "${root}"
assert_choose_runner_cases "${root}/scripts/decide.sh"
tests="${root}/tests/test_decide_helpers.sh"
[[ -f "${tests}" ]] || miss "missing tests/test_decide_helpers.sh"
grep -q 'choose_runner chain' "${tests}" || miss "tests missing chain choose_runner cases"
echo headroom_then_usejoy_ok
