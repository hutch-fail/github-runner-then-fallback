#!/usr/bin/env bash
# Offline unit checks for label JSON shaping and runner choice (no live APIs).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "${ROOT}/scripts/decide.sh"

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

# Two-way: used < included → primary
assert_eq "$(choose_runner two-way 1500 2000 "" "" 100)" primary "two-way under budget"
assert_eq "$(choose_runner two-way 2000 2000 "" "" 100)" fallback "two-way at budget"
assert_eq "$(choose_runner two-way 2055 2000 "" "" 100)" fallback "two-way over budget"
assert_eq "$(choose_runner two-way "" 2000 "" "" 100)" fallback "two-way empty meter"

# Chain at 80%: GitHub headroom → Blacksmith headroom → final
# 80% of 2000 = 1600; 80% of 3000 = 2400
assert_eq "$(choose_runner chain 1000 2000 100 3000 80)" primary "chain gha under 80%"
assert_eq "$(choose_runner chain 1600 2000 100 3000 80)" fallback "chain gha at 80% → blacksmith"
assert_eq "$(choose_runner chain 1800 2000 1000 3000 80)" fallback "chain gha over 80% bs under 80%"
assert_eq "$(choose_runner chain 1800 2000 2400 3000 80)" final "chain both at 80% → final"
assert_eq "$(choose_runner chain 1800 2000 2500 3000 80)" final "chain both over 80% → final"
assert_eq "$(choose_runner chain "" 2000 1000 3000 80)" fallback "chain gha fail → blacksmith"
assert_eq "$(choose_runner chain "" 2000 "" 3000 80)" final "chain both meters fail → final"
assert_eq "$(choose_runner chain 1800 2000 "" 3000 80)" final "chain bs fail → final"

# under_headroom / under_budget helpers
if under_budget 1500 2000; then echo "ok under_budget true"; else echo "FAIL under_budget"; exit 1; fi
if under_budget 2000 2000; then echo "FAIL under_budget at edge"; exit 1; else echo "ok under_budget false at edge"; fi
if under_headroom 1599 2000 80; then echo "ok under_headroom true"; else echo "FAIL under_headroom"; exit 1; fi
if under_headroom 1600 2000 80; then echo "FAIL under_headroom at 80%"; exit 1; else echo "ok under_headroom false at 80%"; fi

# Blacksmith JSON parse: billable_minutes field
tmp="$(mktemp)"
printf '%s\n' '{"billable_minutes":1064,"jobs":10}' >"$tmp"
assert_eq "$(parse_blacksmith_billable_minutes "$tmp")" "1064.0" "parse billable_minutes"
printf '%s\n' '{"totals":{"billableMinutes":42}}' >"$tmp"
assert_eq "$(parse_blacksmith_billable_minutes "$tmp")" "42.0" "parse nested billableMinutes"
printf '%s\n' '{"days":[{"billable_minutes":10},{"billable_minutes":5.5}]}' >"$tmp"
assert_eq "$(parse_blacksmith_billable_minutes "$tmp")" "15.5" "parse sum days"
rm -f "$tmp"

echo "All offline tests passed."
