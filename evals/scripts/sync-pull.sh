#!/usr/bin/env bash
# Sync hub kit into a consumer's evals/ (bootstrap or refresh).
# Run from the consumer repository root:
#   bash /path/to/evals/scripts/sync-pull.sh [--hub DIR] [--init-scope]
# Or: make -C evals sync/pull HUB=../evals  (once kit exists)
#
# Redistributes: kit + goals|fixtures/universe/ + goals|fixtures/language/
# + this repo's own github.com/<org>/<repo>/ leaf (preserve then overlay from hub).
# Does NOT copy other products' github.com packs. Omits runs/ and .github/.
# Preserves evals/scope.yaml.
set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }

CONSUMER_ROOT="$(pwd)"
HUB=""
INIT_SCOPE=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hub) HUB="${2:?}"; shift 2 ;;
    --init-scope) INIT_SCOPE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: sync-pull.sh [--hub DIR] [--init-scope] [--dry-run]
Run from the consumer repo root. Syncs hub → ./evals/:
  kit + universe/language (+ fixtures) + own github.com/<org>/<repo>/ leaf only.
Preserves existing evals/scope.yaml and consumer-owned own leaf, then overlays
that leaf from hub when present. Omits runs/, .github/, and other products'
github.com packs.
EOF
      exit 0
      ;;
    *) die "unknown arg $1" ;;
  esac
done

if [[ -z "$HUB" ]]; then
  if [[ -d "$CONSUMER_ROOT/../evals/.git" ]]; then
    HUB="$(cd "$CONSUMER_ROOT/../evals" && pwd)"
  else
    die "pass --hub /path/to/evals hub checkout"
  fi
fi
HUB="$(cd "$HUB" && pwd)"
[[ -f "$HUB/Makefile" ]] || die "HUB=$HUB does not look like the evals hub (no Makefile)"
[[ -f "$HUB/harness/goal.sh" ]] || die "HUB=$HUB missing harness/goal.sh"
command -v rsync >/dev/null || die "rsync required"

DEST="$CONSUMER_ROOT/evals"
SCOPE_BACKUP=""
OWN_GOALS_BACKUP=""
OWN_FIX_BACKUP=""
tmpdir=""
cleanup() {
  if [[ -n "$SCOPE_BACKUP" && -f "$SCOPE_BACKUP" ]]; then
    mkdir -p "$DEST"
    cp -a "$SCOPE_BACKUP" "$DEST/scope.yaml"
  fi
  [[ -n "$tmpdir" && -d "$tmpdir" ]] && rm -rf "$tmpdir"
}
trap cleanup EXIT

infer_repo_slug() {
  local url
  url="$(git -C "$CONSUMER_ROOT" remote get-url origin 2>/dev/null || true)"
  if [[ "$url" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    printf 'github.com/%s/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return
  fi
  local base
  base="$(basename "$CONSUMER_ROOT")"
  if [[ "$base" == "dot-github" ]]; then
    printf 'github.com/hutch-fail/.github\n'
    return
  fi
  printf 'github.com/hutch-fail/%s\n' "$base"
}

slug="$(infer_repo_slug)"
# slug is github.com/<org>/<repo> — leaf under goals|fixtures
own_rel="${slug}"

tmpdir="$(mktemp -d)"

if [[ -f "$DEST/scope.yaml" ]]; then
  SCOPE_BACKUP="$tmpdir/scope.yaml"
  cp -a "$DEST/scope.yaml" "$SCOPE_BACKUP"
  log "preserved existing evals/scope.yaml"
fi

if [[ -d "$DEST/goals/${own_rel}" ]]; then
  OWN_GOALS_BACKUP="$tmpdir/own-goals"
  mkdir -p "$OWN_GOALS_BACKUP"
  cp -a "$DEST/goals/${own_rel}/." "$OWN_GOALS_BACKUP/"
  log "preserved consumer own goals leaf ${own_rel}"
fi
if [[ -d "$DEST/fixtures/${own_rel}" ]]; then
  OWN_FIX_BACKUP="$tmpdir/own-fixtures"
  mkdir -p "$OWN_FIX_BACKUP"
  cp -a "$DEST/fixtures/${own_rel}/." "$OWN_FIX_BACKUP/"
  log "preserved consumer own fixtures leaf ${own_rel}"
fi

RSYNC_FLAGS=(-a --delete --exclude 'runs/' --exclude '.github/' --exclude '.git/' \
  --exclude 'goals/github.com/' --exclude 'fixtures/github.com/')
if [[ "$DRY_RUN" -eq 1 ]]; then
  RSYNC_FLAGS+=(--dry-run --itemize-changes)
fi

mkdir -p "$DEST"
log "rsync $HUB/ → $DEST/ (kit + universe/language; omit foreign github.com packs)"
rsync "${RSYNC_FLAGS[@]}" "$HUB/" "$DEST/"

restore_own_leaf() {
  local kind="$1" backup="$2"
  local dest_leaf="$DEST/${kind}/${own_rel}"
  if [[ -n "$backup" && -d "$backup" ]]; then
    mkdir -p "$dest_leaf"
    cp -a "$backup/." "$dest_leaf/"
  fi
}

if [[ "$DRY_RUN" -eq 0 ]]; then
  # Drop stale foreign packs left from earlier full-tree pulls, then restore own leaf.
  if [[ -d "$DEST/goals/github.com" ]]; then
    rm -rf "$DEST/goals/github.com"
    log "removed stale goals/github.com (will restore own leaf only)"
  fi
  if [[ -d "$DEST/fixtures/github.com" ]]; then
    rm -rf "$DEST/fixtures/github.com"
    log "removed stale fixtures/github.com (will restore own leaf only)"
  fi

  restore_own_leaf goals "$OWN_GOALS_BACKUP"
  restore_own_leaf fixtures "$OWN_FIX_BACKUP"

  # Overlay own leaf from hub when present (harvested updates)
  if [[ -d "$HUB/goals/${own_rel}" ]]; then
    mkdir -p "$DEST/goals/${own_rel}"
    rsync -a "$HUB/goals/${own_rel}/" "$DEST/goals/${own_rel}/"
    log "overlaid own goals leaf from hub: ${own_rel}"
  fi
  if [[ -d "$HUB/fixtures/${own_rel}" ]]; then
    mkdir -p "$DEST/fixtures/${own_rel}"
    rsync -a "$HUB/fixtures/${own_rel}/" "$DEST/fixtures/${own_rel}/"
    log "overlaid own fixtures leaf from hub: ${own_rel}"
  fi
fi

# Restore scope after rsync --delete
if [[ -n "$SCOPE_BACKUP" && -f "$SCOPE_BACKUP" ]]; then
  cp -a "$SCOPE_BACKUP" "$DEST/scope.yaml"
  SCOPE_BACKUP=""  # avoid double restore in trap
fi

if [[ ! -f "$DEST/scope.yaml" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY: would write minimal scope.yaml for $slug"
  else
    cat >"$DEST/scope.yaml" <<EOF
schema: evals-scope/v1
repo: $slug
languages: []
opt_out: []
EOF
    log "wrote minimal evals/scope.yaml ($slug)"
  fi
elif [[ "$INIT_SCOPE" -eq 1 ]]; then
  log "scope.yaml already present — left unchanged (--init-scope)"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "✓ sync-pull dry-run done → $DEST"
  exit 0
fi
[[ -f "$DEST/Makefile" ]] || die "sync incomplete: no evals/Makefile"
[[ -f "$DEST/scope.yaml" ]] || die "sync incomplete: no evals/scope.yaml"
log "✓ sync-pull done → $DEST (own leaf ${own_rel} only under github.com/)"
