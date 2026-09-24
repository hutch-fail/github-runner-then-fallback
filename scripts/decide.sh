#!/usr/bin/env bash
# Decide primary vs fallback runner from org Actions Linux usage vs included budget.
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

fail_or_fallback() {
  local msg="$1"
  echo "::warning::$msg"
  case "${INPUT_FALLBACK_ON_ERROR:-true}" in
    true|True|TRUE|yes|Yes|YES|1)
      echo "fallback-on-error is true; using fallback runner"
      emit_runner "${INPUT_FALLBACK_RUNNER:?}"
      exit 0
      ;;
    *)
      echo "::error::$msg"
      exit 1
      ;;
  esac
}

main() {
  local primary="${INPUT_PRIMARY_RUNNER:?primary-runner is required}"
  local fallback="${INPUT_FALLBACK_RUNNER:?fallback-runner is required}"
  local included_raw="${INPUT_INCLUDED_MINUTES:-}"
  local token="${INPUT_GITHUB_TOKEN:-}"

  # Missing budget/token is common before org secrets/vars are set; prefer
  # fallback-on-error over hard-failing the composite step.
  if [[ -z "$included_raw" ]]; then
    fail_or_fallback "included-minutes is empty (set vars.ACTIONS_INCLUDED_MINUTES or the input)"
  fi
  if [[ -z "$token" ]]; then
    fail_or_fallback "github-token is empty (pass secrets.ORG_BILLING_TOKEN or equivalent)"
  fi

  if ! [[ "$included_raw" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    fail_or_fallback "included-minutes must be a non-negative number; got: ${included_raw}"
  fi
  local included="$included_raw"

  local org="${INPUT_ORGANIZATION:-}"
  if [[ -z "$org" ]]; then
    local repo="${GITHUB_REPOSITORY:-}"
    if [[ -z "$repo" || "$repo" != */* ]]; then
      fail_or_fallback "organization unset and GITHUB_REPOSITORY is not owner/repo"
    fi
    org="${repo%%/*}"
  fi

  local api_version="${GITHUB_API_VERSION:-2022-11-28}"
  local api_base="${GITHUB_API_URL:-https://api.github.com}"

  # Current calendar month in UTC (billing period for enhanced usage summary).
  local year month
  year="$(date -u +%Y)"
  month="$((10#$(date -u +%m)))"

  local http_code
  http_code="$(curl -sS -o /tmp/grtf-org.json -w '%{http_code}' \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: ${api_version}" \
    "${api_base}/orgs/${org}")" || fail_or_fallback "Failed to resolve organization ${org}"

  if [[ "$http_code" != "200" ]]; then
    fail_or_fallback "GET /orgs/${org} returned HTTP ${http_code}: $(head -c 500 /tmp/grtf-org.json)"
  fi

  local org_id
  org_id="$(python3 -c 'import json,sys; print(json.load(open("/tmp/grtf-org.json"))["id"])')" \
    || fail_or_fallback "Could not parse organization id for ${org}"

  # Enhanced billing usage summary (legacy /orgs/{org}/settings/billing/actions is 410).
  http_code="$(curl -sS -o /tmp/grtf-usage.json -w '%{http_code}' \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: ${api_version}" \
    "${api_base}/organizations/${org_id}/settings/billing/usage/summary?year=${year}&month=${month}")" \
    || fail_or_fallback "Failed to fetch billing usage summary for ${org}"

  if [[ "$http_code" != "200" ]]; then
    fail_or_fallback "GET usage/summary returned HTTP ${http_code}: $(head -c 500 /tmp/grtf-usage.json)"
  fi

  local used
  used="$(python3 - <<'PY'
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
)" || fail_or_fallback "Could not parse actions_linux usage from summary"

  echo "Org=${org} period=${year}-${month} used_linux_minutes=${used} included_minutes=${included}"

  # Prefer primary while under configured included budget.
  if python3 -c "import sys; sys.exit(0 if float('${used}') < float('${included}') else 1)"; then
    echo "Under included minutes; using primary runner"
    emit_runner "$primary"
  else
    echo "Included minutes exhausted or met; using fallback runner"
    emit_runner "$fallback"
  fi
}

main "$@"
