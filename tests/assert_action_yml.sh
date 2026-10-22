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

# Sensible defaults for the headroom chain
grep -Eq '^[[:space:]]*default:[[:space:]]*ubuntu-latest[[:space:]]*$' "$f" \
  || { echo "action.yml: primary-runner should default to ubuntu-latest" >&2; exit 1; }
grep -Eq '^[[:space:]]*default:[[:space:]]*blacksmith-2vcpu-ubuntu-2404[[:space:]]*$' "$f" \
  || { echo "action.yml: fallback-runner should default to blacksmith-2vcpu-ubuntu-2404" >&2; exit 1; }
grep -Eq '^[[:space:]]*default:[[:space:]]*usejoy-2vcpu-ubuntu-2404[[:space:]]*$' "$f" \
  || { echo "action.yml: final-runner should default to usejoy-2vcpu-ubuntu-2404" >&2; exit 1; }
grep -Eq '^[[:space:]]*default:[[:space:]]*"80"[[:space:]]*$' "$f" \
  || { echo "action.yml: usage-threshold should default to \"80\"" >&2; exit 1; }
grep -Eq '^[[:space:]]*default:[[:space:]]*"2000"[[:space:]]*$' "$f" \
  || { echo "action.yml: included-minutes should default to \"2000\"" >&2; exit 1; }
grep -Eq '^[[:space:]]*default:[[:space:]]*"3000"[[:space:]]*$' "$f" \
  || { echo "action.yml: blacksmith-included-minutes should default to \"3000\"" >&2; exit 1; }

echo action_yml_ok
