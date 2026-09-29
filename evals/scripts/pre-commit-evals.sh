#!/usr/bin/env bash
# Host pre-commit entry — pack gate + shared eval bars dispatcher.
#
# Hosts call this one hook (after hutch-fail/pre-commit). On PRE_COMMIT=1 it
# fast-fails when a behavior-changing staged/branch diff lacks an eval fixture
# + pre-run goal (assert_pr_has_eval_pack --mode pre-commit). Result files are
# still CI-only (eval-ci). Then it runs universe bars and language families:
#   - (always) universe → no raw GH_APP_* Actions secrets, …
#   - languages: ui / design|scripts/ui-* → UI language bars
#   - *.tf / *.tf.json  → OpenTofu language bars (remote-backend, …)
#   - *.ts / *.tsx / …  → typescript family (stub until a language bar exists)
#
# Usage (pre-commit, pass_filenames: true):
#   bash evals/scripts/pre-commit-evals.sh [path...]
#
# Prefer make eval/bars / scripts/eval-bars.sh for local and CI equivalence.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Local fast-fail: same pack gate as CI, softer (no result required yet).
if [[ -n "${PRE_COMMIT:-}" ]]; then
  assert="${here}/../tests/unit/assert_pr_has_eval_pack.sh"
  if [[ -f "${assert}" ]]; then
    # No args + PRE_COMMIT → collect_precommit_paths (host or hub layout).
    bash "${assert}"
  fi
fi

exec bash "${here}/eval-bars.sh" "$@"
