#!/usr/bin/env bash
# Shared eval bars entrypoint for local, pre-commit, and CI.
#
# Always runs applicable **universe** bars against HERMES_EVAL_SCAN_ROOT.
# Additionally runs **language** family bars when changed paths (or force)
# indicate them:
#   - *.tf / *.tf.json     → opentofu (remote-backend, …)
#   - *.ts / *.tsx / tsconfig.json / package.json with typescript cues → typescript
#     (family recognized; no language bar shipped yet — no-op stub)
#
# Usage:
#   bash scripts/eval-bars.sh [path...]
#   make eval/bars
#   HERMES_EVAL_FORCE_FAMILIES=opentofu bash scripts/eval-bars.sh
#
# Env:
#   HERMES_EVAL_KIT / EVALS_KIT — evals hub (default: ./evals or parent of scripts/)
#   HERMES_EVAL_SCAN_ROOT — product root to scan (default: cwd)
#   HERMES_EVAL_FORCE_FAMILIES — comma list to add families even with no paths
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_kit() {
  local kit="${HERMES_EVAL_KIT:-${EVALS_KIT:-}}"
  if [[ -n "${kit}" ]]; then
    printf '%s\n' "$(cd "${kit}" && pwd)"
    return 0
  fi
  if [[ -f "${PWD}/evals/harness/goal.sh" ]]; then
    printf '%s\n' "$(cd "${PWD}/evals" && pwd)"
    return 0
  fi
  if [[ -f "${script_dir}/../harness/goal.sh" ]]; then
    printf '%s\n' "$(cd "${script_dir}/.." && pwd)"
    return 0
  fi
  printf 'error: cannot find evals kit (set HERMES_EVAL_KIT or run from a product with ./evals)\n' >&2
  return 1
}

is_tf_path() {
  local base
  base="$(basename "$1")"
  case "${base}" in
    *.tf|*.tf.json) return 0 ;;
  esac
  return 1
}

is_typescript_path() {
  local base
  base="$(basename "$1")"
  case "${base}" in
    *.ts|*.tsx|tsconfig.json|tsconfig.*.json) return 0 ;;
  esac
  return 1
}

# Skip kit / recipe paths (language fixtures ship *.tf; universe fixtures ship workflows).
is_kit_path() {
  case "$1" in
    evals/*|*/evals/*|fixtures/*|*/fixtures/*) return 0 ;;
  esac
  return 1
}

# Print unique families that apply (one per line): universe (always), opentofu, typescript, …
detect_families() {
  local arg fam
  declare -A seen=()
  # Universe bars always apply (global / recipe-wide policy).
  seen[universe]=1

  if [[ -n "${HERMES_EVAL_FORCE_FAMILIES:-}" ]]; then
    IFS=',' read -r -a forced <<<"${HERMES_EVAL_FORCE_FAMILIES}"
    for fam in "${forced[@]}"; do
      fam="$(echo "${fam}" | tr -d '[:space:]')"
      [[ -n "${fam}" ]] || continue
      # Legacy alias from #35 — map gha → universe (already always-on).
      if [[ "${fam}" == "gha" ]]; then
        seen[universe]=1
        continue
      fi
      seen["${fam}"]=1
    done
  fi

  for arg in "$@"; do
    if is_kit_path "${arg}"; then
      continue
    fi
    if is_tf_path "${arg}"; then
      seen[opentofu]=1
    fi
    if is_typescript_path "${arg}"; then
      seen[typescript]=1
    fi
  done

  for fam in "${!seen[@]}"; do
    printf '%s\n' "${fam}"
  done | sort -u
}

run_universe_bars() {
  local kit="$1" scan_root="$2"
  local check="${kit}/fixtures/universe/20260924-no-gha-app-actions-secrets/check.sh"
  if [[ ! -x "${check}" ]]; then
    printf 'error: missing universe no-GH_APP check at %s\n' "${check}" >&2
    return 1
  fi

  export HERMES_EVAL_SCAN_ROOT="${scan_root}"
  export HERMES_EVAL_REPO_ROOT="${scan_root}"
  bash "${check}"
}

run_opentofu_bars() {
  local kit="$1" scan_root="$2"
  local check="${kit}/fixtures/language/opentofu/20260924-remote-backend-locking/check.sh"
  if [[ ! -x "${check}" ]]; then
    printf 'error: missing OpenTofu remote-backend check at %s\n' "${check}" >&2
    return 1
  fi

  local manifest=""
  if [[ -f "${scan_root}/evals/scope.yaml" ]]; then
    manifest="${scan_root}/evals/scope.yaml"
  elif [[ -f "${scan_root}/scope.yaml" && -d "${scan_root}/harness" ]]; then
    manifest="${scan_root}/scope.yaml"
  fi
  if [[ -n "${manifest}" ]] && ! grep -qE '^[[:space:]]*-[[:space:]]*opentofu[[:space:]]*$|languages:.*opentofu' "${manifest}"; then
    printf 'warning: %s does not list languages: opentofu (opentofu bars still run on TF paths)\n' \
      "${manifest}" >&2
  fi

  export HERMES_EVAL_SCAN_ROOT="${scan_root}"
  export HERMES_EVAL_REPO_ROOT="${scan_root}"
  bash "${check}"
}

run_typescript_bars() {
  # Stub: family is detected so future language bars can plug in without
  # changing the dispatcher shape. No TypeScript language fixture yet.
  printf 'eval-bars: typescript family selected (stub — no language bar yet; skip)\n' >&2
  return 0
}

kit="$(resolve_kit)"
scan_root="$(cd "${HERMES_EVAL_SCAN_ROOT:-${PWD}}" && pwd)"

mapfile -t families < <(detect_families "$@")

rc=0
for fam in "${families[@]}"; do
  case "${fam}" in
    universe)
      if ! run_universe_bars "${kit}" "${scan_root}"; then
        rc=1
      fi
      ;;
    opentofu)
      if ! run_opentofu_bars "${kit}" "${scan_root}"; then
        rc=1
      fi
      ;;
    typescript)
      if ! run_typescript_bars "${kit}" "${scan_root}"; then
        rc=1
      fi
      ;;
    *)
      printf 'error: unknown eval family %q (extend scripts/eval-bars.sh)\n' "${fam}" >&2
      rc=1
      ;;
  esac
done

exit "${rc}"
