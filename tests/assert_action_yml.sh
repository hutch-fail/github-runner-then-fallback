#!/usr/bin/env bash
# Assert action.yml exposes the contract this repo's CI and consumers need.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
f="${ROOT}/action.yml"
[[ -f "$f" ]] || {
  echo "missing action.yml" >&2
  exit 1
}

for needle in \
  'primary-runner:' \
  'fallback-runner:' \
  'included-minutes:' \
  'github-token:' \
  'final-runner:' \
  'usage-threshold:' \
  'blacksmith-included-minutes:' \
  'blacksmith-api-token:' \
  'use-runner:' \
  'using: composite'
do
  grep -q "$needle" "$f" || {
    echo "action.yml missing: ${needle}" >&2
    exit 1
  }
done

echo action_yml_ok
