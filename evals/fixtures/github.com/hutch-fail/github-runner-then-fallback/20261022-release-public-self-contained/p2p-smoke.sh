#!/usr/bin/env bash
# P2P: release triggers and permissions stay shippable.
set -euo pipefail
ROOT="${HERMES_EVAL_REPO_ROOT:-}"
[[ -n "${ROOT}" && -d "${ROOT}" ]] || { echo "FAIL: set HERMES_EVAL_REPO_ROOT" >&2; exit 1; }
wf="${ROOT}/.github/workflows/release.yml"
[[ -f "${wf}" ]] || { echo "FAIL: missing release.yml" >&2; exit 1; }
grep -Eq 'workflow_dispatch:' "${wf}" || { echo "FAIL: missing workflow_dispatch" >&2; exit 1; }
grep -Eq 'branches:[[:space:]]*\[main\]' "${wf}" || { echo "FAIL: missing push to main" >&2; exit 1; }
grep -Eq 'contents:[[:space:]]*write' "${wf}" || { echo "FAIL: missing contents: write" >&2; exit 1; }
echo release_public_self_contained_p2p_ok
