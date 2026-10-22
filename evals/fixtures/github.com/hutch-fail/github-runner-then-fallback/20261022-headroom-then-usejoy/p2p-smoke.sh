#!/usr/bin/env bash
# P2P: two-way default still present; chain helpers do not break label JSON.
set -euo pipefail

root="${HERMES_EVAL_REPO_ROOT:-${HERMES_EVAL_SCAN_ROOT:-$PWD}}"
decide="${root}/scripts/decide.sh"
action="${root}/action.yml"

[[ -f "${decide}" && -f "${action}" ]] || {
  echo "missing decide.sh or action.yml" >&2
  exit 1
}

grep -q 'primary-runner:' "${action}"
grep -q 'fallback-runner:' "${action}"
grep -q 'included-minutes:' "${action}"

# shellcheck source=/dev/null
source "${decide}"
[[ "$(labels_to_json 'ubuntu-latest')" == '["ubuntu-latest"]' ]]
[[ "$(choose_runner two-way 100 2000 "" "" 100)" == "primary" ]]
[[ "$(choose_runner two-way 2000 2000 "" "" 100)" == "fallback" ]]

echo headroom_then_usejoy_p2p_ok
