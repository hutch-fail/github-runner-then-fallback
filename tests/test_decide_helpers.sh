#!/usr/bin/env bash
# Offline unit checks for label JSON shaping (no live billing API).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source <(sed -n '/^labels_to_json()/,/^}/p' "${ROOT}/scripts/decide.sh")

assert_eq() {
  local got="$1" want="$2" name="$3"
  if [[ "$got" != "$want" ]]; then
    echo "FAIL ${name}: got=${got} want=${want}" >&2
    exit 1
  fi
  echo "ok ${name}"
}

assert_eq "$(labels_to_json 'ubuntu-latest')" '["ubuntu-latest"]' "single label"
assert_eq "$(labels_to_json 'self-hosted,linux')" '["self-hosted","linux"]' "multi label"
assert_eq "$(labels_to_json ' blacksmith-2vcpu-ubuntu-2404 ')" '["blacksmith-2vcpu-ubuntu-2404"]' "trim spaces"

# Decision predicate: used < included → primary
python3 - <<'PY'
used, included = 1500.0, 2000.0
assert used < included
used, included = 2000.0, 2000.0
assert not (used < included)
used, included = 2055.0, 2000.0
assert not (used < included)
print("ok predicate")
PY

echo "All offline tests passed."
