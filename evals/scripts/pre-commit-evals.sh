#!/usr/bin/env bash
# Host pre-commit entry — thin wrapper around the shared eval bars dispatcher.
#
# Hosts call this one hook (after hutch-fail/pre-commit). The shared script
# always runs universe bars, then language families from the changed path set:
#   - (always) universe → no raw GH_APP_* Actions secrets, …
#   - *.tf / *.tf.json  → OpenTofu language bars (remote-backend, …)
#   - *.ts / *.tsx / …  → typescript family (stub until a language bar exists)
#
# Usage (pre-commit, pass_filenames: true):
#   bash evals/scripts/pre-commit-evals.sh [path...]
#
# Prefer make eval/bars / scripts/eval-bars.sh for local and CI equivalence.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${here}/eval-bars.sh" "$@"
