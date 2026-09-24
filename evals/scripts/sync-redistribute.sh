#!/usr/bin/env bash
# Branch each included consumer, sync-pull from hub tip, commit, push, open a DRAFT PR.
# Usage: sync-redistribute.sh [--consumers-root DIR] [--hub DIR] [--branch NAME] [--dry-run]
set -euo pipefail

HUB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONSUMERS_ROOT="${CONSUMERS_ROOT:-$HOME/github.com/hutch-fail}"
HUB="${HUB:-$HUB_ROOT}"
DRY_RUN=0
ORG=hutch-fail
BRANCH="chore/sync-evals-$(date +%Y%m%d)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --consumers-root) CONSUMERS_ROOT="${2:?}"; shift 2 ;;
    --hub) HUB="${2:?}"; shift 2 ;;
    --branch) BRANCH="${2:?}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: sync-redistribute.sh [--consumers-root DIR] [--hub DIR] [--branch NAME] [--dry-run]
For each include=true kit/missing clone: refuse if dirty; checkout/create BRANCH;
run sync-pull.sh --hub HUB (--init-scope if no scope.yaml); install-host-adapters.sh;
commit + push when the tree changed; open a draft PR (gh pr create --draft).
Leave PRs draft until ready-for-review so eval-ci/pre-commit stay skipped.
EOF
      exit 0
      ;;
    *) printf 'error: unknown arg %s\n' "$1" >&2; exit 2 ;;
  esac
done

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }

git_https() {
  git -c url."https://github.com/".insteadOf="git@github.com:" \
      -c url."https://github.com/".insteadOf="git@ssh.github.com:" \
      "$@"
}

LIST_SCRIPT="$HUB_ROOT/scripts/sync-list-repos.sh"
PULL_SCRIPT="$HUB_ROOT/scripts/sync-pull.sh"
ADAPTERS="$HUB_ROOT/scripts/install-host-adapters.sh"
[[ -f "$LIST_SCRIPT" ]] || die "missing $LIST_SCRIPT"
[[ -f "$PULL_SCRIPT" ]] || die "missing $PULL_SCRIPT"
[[ -f "$ADAPTERS" ]] || die "missing $ADAPTERS"
command -v jq >/dev/null || die "jq required"
command -v gh >/dev/null || die "gh required (draft PR create)"
HUB="$(cd "$HUB" && pwd)"
[[ -f "$HUB/Makefile" ]] || die "HUB=$HUB missing Makefile"

FAIL=0
OK=0
DRAFT_PRS=0

open_draft_pr() {
  local path="$1" name="$2"
  local title body url existing
  title="chore(evals): sync kit from hub (${BRANCH})"
  body="$(cat <<EOF
## Summary
- Sync-pull evals kit (+ universe/language + own leaf) from hub tip
- Host adapters refreshed

## Notes
- Opened as **draft** so eval-ci / pre-commit stay skipped until ready-for-review
- Kit-only diffs rely on consumer \`evals/**\` paths-ignore for pre-commit (no \`[skip ci]\`)
- Mark ready-for-review in batches after spot-check

EOF
)"
  existing="$(gh pr list --repo "${ORG}/${name}" --head "$BRANCH" --json number --jq '.[0].number // empty' 2>/dev/null || true)"
  if [[ -n "$existing" ]]; then
    url="$(gh pr view "$existing" --repo "${ORG}/${name}" --json url --jq .url)"
    log "OK    $name draft PR already #${existing} $url"
    return 0
  fi
  url="$(gh pr create --repo "${ORG}/${name}" --draft --base main --head "$BRANCH" --title "$title" --body "$body")"
  log "OK    $name draft PR $url"
  DRAFT_PRS=$((DRAFT_PRS + 1))
}

while IFS= read -r row; do
  name="$(jq -r '.name' <<<"$row")"
  include="$(jq -r '.include|tostring' <<<"$row")"
  path="$(jq -r '.path // empty' <<<"$row")"
  [[ "$include" == true ]] || continue
  if [[ -z "$path" || ! -d "$path/.git" ]]; then
    log "FAIL  $name uncloned"
    FAIL=1
    continue
  fi
  if [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
    log "FAIL  $name dirty — refuse redistribute"
    FAIL=1
    continue
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY   $name would branch $BRANCH + sync-pull + adapters + draft PR"
    OK=$((OK + 1))
    continue
  fi
  git_https -C "$path" fetch origin --prune
  if git -C "$path" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git -C "$path" checkout "$BRANCH"
  else
    # Prefer branching from current mainline tip
    if git -C "$path" show-ref --verify --quiet refs/remotes/origin/main; then
      git -C "$path" checkout -B "$BRANCH" origin/main
    elif git -C "$path" show-ref --verify --quiet refs/remotes/origin/master; then
      git -C "$path" checkout -B "$BRANCH" origin/master
    else
      git -C "$path" checkout -B "$BRANCH"
    fi
  fi

  init_args=()
  if [[ ! -f "$path/evals/scope.yaml" ]]; then
    init_args+=(--init-scope)
  fi
  (
    cd "$path"
    bash "$PULL_SCRIPT" --hub "$HUB" "${init_args[@]}"
    bash "$ADAPTERS"
  )

  if [[ -z "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
    # No tree change — still ensure a draft PR exists if the branch was pushed before.
    if git -C "$path" rev-parse --verify --quiet "origin/${BRANCH}" >/dev/null 2>&1; then
      open_draft_pr "$path" "$name" || { log "FAIL  $name draft PR"; FAIL=1; continue; }
    else
      log "OK    $name on $BRANCH (no changes; skip push/PR)"
    fi
    OK=$((OK + 1))
    continue
  fi

  git -C "$path" add -A
  if git -C "$path" diff --cached --quiet; then
    log "OK    $name on $BRANCH (nothing staged; skip)"
    OK=$((OK + 1))
    continue
  fi
  git -C "$path" commit -m "$(cat <<EOF
chore(evals): sync kit from hub

Redistribute via sync-pull + host adapters (${BRANCH}).
EOF
)"
  git_https -C "$path" push -u origin "HEAD:${BRANCH}"
  open_draft_pr "$path" "$name" || { log "FAIL  $name draft PR"; FAIL=1; continue; }
  log "OK    $name on $BRANCH (sync-pull + adapters + draft PR)"
  OK=$((OK + 1))
done < <(CONSUMERS_ROOT="$CONSUMERS_ROOT" "$LIST_SCRIPT" --format json --consumers-root "$CONSUMERS_ROOT" --org "$ORG" | jq -c '.[]')

log "sync-redistribute: ok=$OK fail=$FAIL draft_prs=$DRAFT_PRS branch=$BRANCH hub=$HUB"
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
