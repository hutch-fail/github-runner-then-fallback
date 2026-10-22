#!/usr/bin/env bash
# Decide primary vs fallback (and optional final) runner from usage vs budgets.
set -euo pipefail

labels_to_json() {
  local raw="$1"
  # shellcheck disable=SC2206
  local parts=(${raw//,/ })
  local json="["
  local first=1
  local p
  for p in "${parts[@]}"; do
    p="${p#"${p%%[![:space:]]*}"}"
    p="${p%"${p##*[![:space:]]}"}"
    [[ -n "$p" ]] || continue
    if [[ $first -eq 1 ]]; then
      first=0
    else
      json+=","
    fi
    # Escape for JSON string
    p="${p//\\/\\\\}"
    p="${p//\"/\\\"}"
    json+="\"${p}\""
  done
  json+="]"
  printf '%s' "$json"
}

# used < included (full budget; two-way mode).
under_budget() {
  python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) < float(sys.argv[2]) else 1)' "$1" "$2"
}

# used < included * (threshold_percent / 100); chain headroom.
under_headroom() {
  python3 -c '
import sys
used, included, threshold = float(sys.argv[1]), float(sys.argv[2]), float(sys.argv[3])
sys.exit(0 if used < included * threshold / 100.0 else 1)
' "$1" "$2" "$3"
}

# Pure choice. Prints: primary | fallback | final
# Args: mode(two-way|chain) gha_used_or_empty gha_included bs_used_or_empty bs_included threshold_pct
# Empty used means that pool's meter failed or was skipped — treat as exhausted.
choose_runner() {
  local mode="$1"
  local gha_used="${2:-}"
  local gha_included="${3:-0}"
  local bs_used="${4:-}"
  local bs_included="${5:-0}"
  local threshold="${6:-100}"

  if [[ "$mode" == "two-way" ]]; then
    if [[ -n "$gha_used" ]] && under_budget "$gha_used" "$gha_included"; then
      printf '%s' primary
    else
      printf '%s' fallback
    fi
    return 0
  fi

  if [[ -n "$gha_used" ]] && under_headroom "$gha_used" "$gha_included" "$threshold"; then
    printf '%s' primary
    return 0
  fi
  if [[ -n "$bs_used" ]] && under_headroom "$bs_used" "$bs_included" "$threshold"; then
    printf '%s' fallback
    return 0
  fi
  printf '%s' final
}

# Extract month billable minutes from blacksmith usage JSON (field name may vary).
parse_blacksmith_billable_minutes() {
  local path="$1"
  python3 - "$path" <<'PY'
import json
import sys

path = sys.argv[1]
data = json.load(open(path))
KEYS = (
    "billable_minutes",
    "billableMinutes",
    "billing_minutes",
    "billingMinutes",
    "total_billable_minutes",
    "totalBillableMinutes",
)


def find_billable(obj, depth=0):
    if depth > 8:
        return None
    if isinstance(obj, dict):
        for key in KEYS:
            if key in obj and obj[key] is not None:
                try:
                    return float(obj[key])
                except (TypeError, ValueError):
                    pass
        for nest in ("totals", "summary", "usage", "data", "result"):
            if nest in obj:
                found = find_billable(obj[nest], depth + 1)
                if found is not None:
                    return found
        for key in ("items", "results", "days", "breakdown", "usageItems"):
            rows = obj.get(key)
            if isinstance(rows, list):
                total = 0.0
                hit = False
                for row in rows:
                    found = find_billable(row, depth + 1)
                    if found is not None:
                        total += found
                        hit = True
                if hit:
                    return total
    elif isinstance(obj, list):
        total = 0.0
        hit = False
        for row in obj:
            found = find_billable(row, depth + 1)
            if found is not None:
                total += found
                hit = True
        if hit:
            return total
    return None


value = find_billable(data)
if value is None:
    sys.stderr.write("Could not find billable_minutes in blacksmith usage JSON\n")
    sys.exit(1)
print(value)
PY
}

emit_runner() {
  local labels_csv="$1"
  local json
  json="$(labels_to_json "$labels_csv")"
  {
    echo "use-runner<<EOF"
    echo "$json"
    echo "EOF"
  } >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
  echo "Selected runner JSON: $json"
}

# Last-resort emit: two-way → fallback; chain → final (Jog).
fail_or_last_resort() {
  local msg="$1"
  echo "::warning::$msg"
  case "${INPUT_FALLBACK_ON_ERROR:-true}" in
    true|True|TRUE|yes|Yes|YES|1)
      if [[ -n "${INPUT_FINAL_RUNNER:-}" ]]; then
        echo "fallback-on-error is true; using final runner"
        emit_runner "${INPUT_FINAL_RUNNER}"
      else
        echo "fallback-on-error is true; using fallback runner"
        emit_runner "${INPUT_FALLBACK_RUNNER:?}"
      fi
      exit 0
      ;;
    *)
      echo "::error::$msg"
      exit 1
      ;;
  esac
}

# Back-compat name used by older call sites / mental model.
fail_or_fallback() {
  fail_or_last_resort "$1"
}

ensure_blacksmith_cli() {
  if command -v blacksmith >/dev/null 2>&1; then
    return 0
  fi
  # stderr only — stdout is captured as billable minutes by the caller.
  echo "Installing Blacksmith CLI" >&2
  curl -fsSL https://get.blacksmith.sh | sh >&2
  export PATH="${HOME}/.local/bin:${HOME}/.blacksmith/bin:/usr/local/bin:${PATH}"
  command -v blacksmith >/dev/null 2>&1
}

# Prints billable minutes for the current UTC calendar month, or fails.
fetch_blacksmith_billable_minutes() {
  local token="$1"
  local org="$2"
  local start end

  start="$(date -u +%Y-%m-01T00:00:00Z)"
  end="$(date -u -d "$(date -u +%Y-%m-01) +1 month" +%Y-%m-01T00:00:00Z)"

  ensure_blacksmith_cli || return 1

  # Non-interactive org token auth for CI (stderr — stdout is the minutes value).
  printf '%s' "$token" | blacksmith auth login --api-token - --non-interactive --organization "$org" >&2 \
    || return 1

  blacksmith usage --start-time "$start" --end-time "$end" --format json \
    > /tmp/grtf-bs-usage.json \
    || return 1

  parse_blacksmith_billable_minutes /tmp/grtf-bs-usage.json
}

fetch_github_linux_minutes() {
  local org="$1"
  local token="$2"
  local year="$3"
  local month="$4"
  local api_version="${GITHUB_API_VERSION:-2022-11-28}"
  local api_base="${GITHUB_API_URL:-https://api.github.com}"
  local http_code org_id

  http_code="$(curl -sS -o /tmp/grtf-org.json -w '%{http_code}' \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: ${api_version}" \
    "${api_base}/orgs/${org}")" || return 1

  if [[ "$http_code" != "200" ]]; then
    echo "GET /orgs/${org} returned HTTP ${http_code}: $(head -c 500 /tmp/grtf-org.json)" >&2
    return 1
  fi

  org_id="$(python3 -c 'import json; print(json.load(open("/tmp/grtf-org.json"))["id"])')" || return 1

  http_code="$(curl -sS -o /tmp/grtf-usage.json -w '%{http_code}' \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: ${api_version}" \
    "${api_base}/organizations/${org_id}/settings/billing/usage/summary?year=${year}&month=${month}")" \
    || return 1

  if [[ "$http_code" != "200" ]]; then
    echo "GET usage/summary returned HTTP ${http_code}: $(head -c 500 /tmp/grtf-usage.json)" >&2
    return 1
  fi

  python3 - <<'PY'
import json
data = json.load(open("/tmp/grtf-usage.json"))
used = 0.0
for item in data.get("usageItems") or []:
    sku = (item.get("sku") or "").lower()
    unit = (item.get("unitType") or "").lower()
    product = (item.get("product") or "").lower()
    if sku in ("actions_linux", "actions linux") or (
        product == "actions" and "linux" in sku and "minute" in unit
    ):
        used += float(item.get("grossQuantity") or 0)
print(used)
PY
}

emit_choice() {
  local choice="$1"
  local primary="$2"
  local fallback="$3"
  local final="$4"
  case "$choice" in
    primary)
      echo "Choice=primary; using primary runner"
      emit_runner "$primary"
      ;;
    fallback)
      echo "Choice=fallback; using fallback runner"
      emit_runner "$fallback"
      ;;
    final)
      echo "Choice=final; using final runner"
      emit_runner "$final"
      ;;
    *)
      fail_or_last_resort "Internal error: unknown choice ${choice}"
      ;;
  esac
}

main() {
  local primary="${INPUT_PRIMARY_RUNNER:?primary-runner is required}"
  local fallback="${INPUT_FALLBACK_RUNNER:?fallback-runner is required}"
  local final="${INPUT_FINAL_RUNNER:-}"
  local included_raw="${INPUT_INCLUDED_MINUTES:-}"
  local token="${INPUT_GITHUB_TOKEN:-}"
  local threshold_raw="${INPUT_USAGE_THRESHOLD:-80}"
  local bs_included_raw="${INPUT_BLACKSMITH_INCLUDED_MINUTES:-}"
  local bs_token="${INPUT_BLACKSMITH_API_TOKEN:-}"
  local mode="two-way"

  if [[ -n "$final" ]]; then
    mode="chain"
  fi

  if [[ -z "$included_raw" ]]; then
    if [[ "$mode" == "chain" ]]; then
      echo "::warning::included-minutes is empty; skipping GitHub pool in chain mode"
    else
      fail_or_last_resort "included-minutes is empty (set vars.ACTIONS_INCLUDED_MINUTES or the input)"
    fi
  fi
  if [[ -z "$token" ]]; then
    if [[ "$mode" == "chain" ]]; then
      echo "::warning::github-token is empty; skipping GitHub pool in chain mode"
    else
      fail_or_last_resort "github-token is empty (pass secrets.ORG_BILLING_TOKEN or equivalent)"
    fi
  fi

  local included=""
  if [[ -n "$included_raw" ]]; then
    if ! [[ "$included_raw" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      fail_or_last_resort "included-minutes must be a non-negative number; got: ${included_raw}"
    fi
    included="$included_raw"
  fi

  if ! [[ "$threshold_raw" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    fail_or_last_resort "usage-threshold must be a non-negative number; got: ${threshold_raw}"
  fi
  local threshold="$threshold_raw"

  local org="${INPUT_ORGANIZATION:-}"
  if [[ -z "$org" ]]; then
    local repo="${GITHUB_REPOSITORY:-}"
    if [[ -z "$repo" || "$repo" != */* ]]; then
      fail_or_last_resort "organization unset and GITHUB_REPOSITORY is not owner/repo"
    fi
    org="${repo%%/*}"
  fi

  local year month
  year="$(date -u +%Y)"
  month="$((10#$(date -u +%m)))"

  local gha_used=""
  if [[ -n "$token" && -n "$included" ]]; then
    if gha_used="$(fetch_github_linux_minutes "$org" "$token" "$year" "$month")"; then
      echo "Org=${org} period=${year}-${month} used_linux_minutes=${gha_used} included_minutes=${included}"
    else
      echo "::warning::GitHub billing usage check failed"
      gha_used=""
      if [[ "$mode" == "two-way" ]]; then
        fail_or_last_resort "GitHub billing usage check failed"
      fi
    fi
  fi

  if [[ "$mode" == "two-way" ]]; then
    local choice
    choice="$(choose_runner two-way "$gha_used" "$included" "" "" 100)"
    if [[ "$choice" == "primary" ]]; then
      echo "Under included minutes; using primary runner"
    else
      echo "Included minutes exhausted or met; using fallback runner"
    fi
    emit_choice "$choice" "$primary" "$fallback" ""
    return 0
  fi

  # Chain mode: GitHub headroom → Blacksmith headroom → final (Jog).
  local bs_included=""
  local bs_used=""
  if [[ -n "$bs_included_raw" ]]; then
    if ! [[ "$bs_included_raw" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      fail_or_last_resort "blacksmith-included-minutes must be a non-negative number; got: ${bs_included_raw}"
    fi
    bs_included="$bs_included_raw"
  fi

  if [[ -z "$bs_token" || -z "$bs_included" ]]; then
    echo "::warning::Blacksmith meter incomplete (token or included-minutes); skipping Blacksmith pool"
  else
    if bs_used="$(fetch_blacksmith_billable_minutes "$bs_token" "$org")"; then
      echo "Org=${org} blacksmith_billable_minutes=${bs_used} blacksmith_included_minutes=${bs_included} threshold=${threshold}"
    else
      echo "::warning::Blacksmith usage check failed; skipping Blacksmith pool"
      bs_used=""
    fi
  fi

  local choice
  choice="$(choose_runner chain "${gha_used}" "${included:-0}" "${bs_used}" "${bs_included:-0}" "$threshold")"
  echo "mode=chain threshold=${threshold} choice=${choice}"
  emit_choice "$choice" "$primary" "$fallback" "$final"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
