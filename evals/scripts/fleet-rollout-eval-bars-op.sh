#!/usr/bin/env bash
# Fleet rollout: sync evals kit (eval/bars) + migrate GH_APP thin callers / inline mints to OP.
# Usage: fleet-rollout-eval-bars-op.sh [--dry-run] [--ready] [--skip-gateway]
set -euo pipefail

HUB="${HUB:-$HOME/github.com/hutch-fail/evals}"
CONSUMERS_ROOT="${CONSUMERS_ROOT:-$HOME/github.com/hutch-fail}"
HUB_SHA="$(cd "$HUB" && git rev-parse HEAD)"
BRANCH="chore/fleet-eval-bars-op-$(date +%Y%m%d)"
DRY_RUN=0
READY=0
SKIP_GATEWAY=1
PC_TAG=v0.1.5
ORG=hutch-fail

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --ready) READY=1; shift ;;
    --no-skip-gateway) SKIP_GATEWAY=0; shift ;;
    --branch) BRANCH="${2:?}"; shift 2 ;;
    *) echo "unknown $1" >&2; exit 2 ;;
  esac
done

LIST="$HUB/scripts/sync-list-repos.sh"
PULL="$HUB/scripts/sync-pull.sh"
ADAPTERS="$HUB/scripts/install-host-adapters.sh"
MIGRATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_fleet_migrate_workflows.py"

log() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -x "$PULL" ]] || die "missing $PULL"
[[ -f "$MIGRATE" ]] || die "missing $MIGRATE"
command -v gh >/dev/null || die "gh required"

FAIL=0
OK=0
PRS=()

while IFS= read -r row; do
  name="$(jq -r '.name' <<<"$row")"
  include="$(jq -r '.include|tostring' <<<"$row")"
  path="$(jq -r '.path // empty' <<<"$row")"
  class="$(jq -r '.class' <<<"$row")"
  [[ "$include" == true ]] || continue
  [[ -n "$path" && -d "$path/.git" ]] || { log "FAIL  $name uncloned"; FAIL=1; continue; }
  if [[ "$SKIP_GATEWAY" -eq 1 && "$name" == "service-gateway" ]]; then
    log "SKIP  $name (already rolled out)"
    continue
  fi
  if [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
    log "FAIL  $name dirty"; FAIL=1; continue
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY   $name branch=$BRANCH sync-pull migrate pin=$HUB_SHA pc=$PC_TAG"
    continue
  fi

  log "==== $name ($class) ===="
  git -C "$path" fetch origin main
  git -C "$path" checkout main
  git -C "$path" reset --hard origin/main
  git -C "$path" checkout -B "$BRANCH"

  init=()
  if [[ ! -f "$path/evals/scope.yaml" ]]; then
    init=(--init-scope)
  fi
  (
    cd "$path"
    bash "$PULL" --hub "$HUB" "${init[@]}"
    bash "$ADAPTERS" || true
  )

  python3 "$MIGRATE" --root "$path" --hub-sha "$HUB_SHA" --pre-commit-tag "$PC_TAG"

  # Ensure universe check would pass after migrate
  if [[ -x "$path/evals/scripts/eval-bars.sh" ]]; then
    if ! HERMES_EVAL_KIT="$path/evals" HERMES_EVAL_SCAN_ROOT="$path" bash "$path/evals/scripts/eval-bars.sh"; then
      log "WARN  $name eval-bars still red after migrate — leaving PR for manual fix"
    fi
  fi

  if [[ -z "$(git -C "$path" status --porcelain)" ]]; then
    log "OK    $name no changes after sync/migrate"
    continue
  fi

  git -C "$path" add -A
  git -C "$path" commit -m "$(cat <<EOF
chore(evals): fleet sync eval/bars + OP App credentials

Sync kit from hub ${HUB_SHA:0:7}; pin eval-ci; migrate GH_APP_* callers to
OP_SERVICE_ACCOUNT_TOKEN; pin pre-commit ${PC_TAG}.

EOF
)"
  git -C "$path" push -u origin "HEAD:$BRANCH" --force-with-lease

  title="chore(evals): fleet sync eval/bars + OP credentials"
  body="$(cat <<EOF
## Summary
- Sync-pull evals kit from hub \`${HUB_SHA}\` (shared \`eval/bars\`)
- Pin \`eval-ci\` to that tip; pass \`OP_SERVICE_ACCOUNT_TOKEN\`
- Pin \`pre-commit\` workflow/hook to \`${PC_TAG}\` + OP token where applicable
- Migrate remaining \`secrets.GH_APP_*\` mint/pass-through to 1Password load

## Test plan
- [ ] \`make -C evals eval/bars\` / pre-commit evals hook green
- [ ] eval-ci green on ready-for-review

EOF
)"
  existing="$(gh pr list --repo "${ORG}/${name}" --head "$BRANCH" --json number --jq '.[0].number // empty' 2>/dev/null || true)"
  if [[ -n "$existing" ]]; then
    url="$(gh pr view "$existing" --repo "${ORG}/${name}" --json url --jq .url)"
    log "OK    $name PR already #$existing $url"
    if [[ "$READY" -eq 1 ]]; then
      gh pr ready "$existing" --repo "${ORG}/${name}" 2>/dev/null || true
    fi
    PRS+=("${ORG}/${name}#${existing}")
  else
    args=(--repo "${ORG}/${name}" --base main --head "$BRANCH" --title "$title" --body "$body")
    if [[ "$READY" -eq 0 ]]; then
      args+=(--draft)
    fi
    url="$(gh pr create "${args[@]}")"
    log "OK    $name PR $url"
    PRS+=("$url")
  fi
  OK=$((OK + 1))
done < <(CONSUMERS_ROOT="$CONSUMERS_ROOT" bash "$LIST" --format json --consumers-root "$CONSUMERS_ROOT" --org "$ORG" | jq -c '.[]')

log "done ok=$OK fail=$FAIL branch=$BRANCH hub=$HUB_SHA"
printf '%s\n' "${PRS[@]}"
exit "$FAIL"
