#!/usr/bin/env bash
# F2P: chain mode must not select Blacksmith when the GHA meter is empty.
set -euo pipefail
root="${HERMES_EVAL_REPO_ROOT:-${HERMES_EVAL_SCAN_ROOT:-$PWD}}"
decide="${root}/scripts/decide.sh"
readme="${root}/README.md"
[[ -f "${decide}" ]] || { echo "FAIL: missing scripts/decide.sh" >&2; exit 1; }
[[ -f "${readme}" ]] || { echo "FAIL: missing README.md" >&2; exit 1; }

# shellcheck source=/dev/null
source "${decide}"

got="$(choose_runner chain "" 2000 1000 3000 80)"
[[ "${got}" == "final" ]] || {
  echo "FAIL: empty GHA meter must emit final (skip Blacksmith); got ${got}" >&2
  exit 1
}

got="$(choose_runner chain 1800 2000 1000 3000 80)"
[[ "${got}" == "fallback" ]] || {
  echo "FAIL: exhausted GHA under BS headroom must emit fallback; got ${got}" >&2
  exit 1
}

got="$(choose_runner two-way "" 2000 "" "" 100)"
[[ "${got}" == "fallback" ]] || {
  echo "FAIL: two-way empty meter must still emit fallback; got ${got}" >&2
  exit 1
}

grep -Eqi 'GitHub meter failure.*(final|Jog)|never Blacksmith' "${readme}" \
  || { echo "FAIL: README must document GHA meter failure → final (not Blacksmith)" >&2; exit 1; }

echo gha_meter_fail_skips_blacksmith_ok
