#!/usr/bin/env bash
# F2P: public repo release.yml must not call private hutch-fail/actions reusable.
set -euo pipefail
ROOT="${HERMES_EVAL_REPO_ROOT:-}"
[[ -n "${ROOT}" && -d "${ROOT}" ]] || { echo "FAIL: set HERMES_EVAL_REPO_ROOT" >&2; exit 1; }
cd "${ROOT}"
[[ -f ./tests/assert_release_yml.sh ]] || { echo "FAIL: missing ./tests/assert_release_yml.sh" >&2; exit 1; }
# Exercise product assert (pack-quality use-path cue: ./tests/…).
./tests/assert_release_yml.sh
echo release_public_self_contained_ok
