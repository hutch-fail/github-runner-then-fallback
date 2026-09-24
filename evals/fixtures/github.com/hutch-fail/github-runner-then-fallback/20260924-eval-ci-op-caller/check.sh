#!/usr/bin/env bash
# Pass when the consumer thin eval-ci caller uses OP_SERVICE_ACCOUNT_TOKEN (not GH_APP_* secrets).
set -euo pipefail
root="${HERMES_EVAL_SCAN_ROOT:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
# When run from fixture under evals/, host root is parent of evals/
if [[ -d "${root}/evals" ]]; then
  host="${root}"
elif [[ -d "${root}/../.github" ]]; then
  host="$(cd "${root}/.." && pwd)"
else
  host="${root}"
fi
wf="${host}/.github/workflows/eval-ci.yml"
[[ -f "$wf" ]] || { echo "missing $wf"; exit 1; }
grep -q 'OP_SERVICE_ACCOUNT_TOKEN' "$wf" || { echo "eval-ci must pass OP_SERVICE_ACCOUNT_TOKEN"; exit 1; }
if grep -E 'secrets\.GH_APP_(ID|PRIVATE_KEY)' "$wf" >/dev/null; then
  echo "eval-ci must not pass secrets.GH_APP_*"
  exit 1
fi
exit 0
