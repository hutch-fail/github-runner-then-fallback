#!/usr/bin/env bash
# P2P: structural pack integrity only — must pass on the pre-change tree too.
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="${HERMES_EVAL_REPO_ROOT:-${HERMES_EVAL_SCAN_ROOT:-$PWD}}"

[[ -d "${root}/.github/workflows" ]] || { echo "missing .github/workflows" >&2; exit 1; }
[[ -x "${dir}/check.sh" ]] || { echo "check.sh not executable" >&2; exit 1; }
[[ -f "${dir}/p2p-smoke.sh" ]] || { echo "missing p2p-smoke.sh" >&2; exit 1; }

# Goal + result must sit beside the fixture id (do not assert tip SHAs here).
pack_id="$(basename "${dir}")"
# fixture path: evals/fixtures/github.com/<org>/<repo>/<id>
# goal path:    evals/goals/github.com/<org>/<repo>/<id>.md
leaf="${dir#*/fixtures/}"
goal="${root}/evals/goals/${leaf}.md"
result="${root}/evals/goals/${leaf}-result.md"
# When HERMES roots differ, also try repo-relative from cwd layout:
if [[ ! -f "${goal}" ]]; then
  goal="${root}/evals/goals/github.com/$(echo "${leaf}" | sed -E 's|^github\.com/||')"
  # leaf already includes github.com/...
  goal="${root}/evals/goals/${leaf}.md"
fi
[[ -f "${goal}" ]] || { echo "missing goal for ${pack_id}: ${goal}" >&2; exit 1; }
[[ -f "${result}" ]] || { echo "missing result for ${pack_id}: ${result}" >&2; exit 1; }
grep -Eq '^schema:[[:space:]]*goal/v1' "${goal}" || { echo "goal schema not goal/v1" >&2; exit 1; }
grep -Fq 'Set before the run.' "${goal}" || { echo "goal missing Set before the run." >&2; exit 1; }
grep -Eq '^schema:[[:space:]]*goal-result/v1' "${result}" || { echo "result schema not goal-result/v1" >&2; exit 1; }
grep -Fq '# Manual verification' "${result}" || { echo "result missing Manual verification" >&2; exit 1; }

echo p2p_pin_hubs_pack_ok
