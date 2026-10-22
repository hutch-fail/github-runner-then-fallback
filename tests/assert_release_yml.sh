#!/usr/bin/env bash
# Assert release.yml is self-contained (public repo cannot call private reusables).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
f="${ROOT}/.github/workflows/release.yml"
[[ -f "$f" ]] || {
  echo "missing .github/workflows/release.yml" >&2
  exit 1
}

if grep -Eq 'uses:[[:space:]]*hutch-fail/actions/' "$f"; then
  echo "release.yml must not uses: private hutch-fail/actions (public caller)" >&2
  exit 1
fi
grep -Eq 'semantic-release' "$f" || {
  echo "release.yml missing semantic-release" >&2
  exit 1
}
grep -Eq 'runs-on:[[:space:]]*ubuntu-latest' "$f" || {
  echo "release.yml must run on ubuntu-latest" >&2
  exit 1
}
grep -Eq 'workflow_dispatch:' "$f" || {
  echo "release.yml missing workflow_dispatch" >&2
  exit 1
}

echo release_yml_ok
