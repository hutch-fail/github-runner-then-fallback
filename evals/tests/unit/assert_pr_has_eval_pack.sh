#!/usr/bin/env bash
# A behavior-changing diff must carry an eval pack.
# CI mode: fixture check, pre-run goal, and post-run report.
# Pre-commit mode: fixture check and pre-run goal.
# tests/unit and runs/ do not count.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

resolve_pack_roots() {
  if [[ -n "${EVALS_PACK_ROOT:-}" ]]; then
    ROOT="$(cd "${EVALS_PACK_ROOT}" && pwd)"
    LAYOUT="host"
    return 0
  fi
  if [[ -d "${HUB_ROOT}/.git" ]]; then
    ROOT="${HUB_ROOT}"
    LAYOUT="hub"
    return 0
  fi
  ROOT="$(cd "${HUB_ROOT}/.." && pwd)"
  LAYOUT="host"
}

usage() {
  printf '%s\n' \
    "usage: assert_pr_has_eval_pack.sh [--mode ci|pre-commit] [--paths-file FILE | --range REV]" \
    "       with no args: self-test (or the branch range when PRE_COMMIT=1)" >&2
}

is_eval() {
  case "$1" in
    fixtures/*/check.sh|fixtures/*/p2p-smoke.sh) return 0 ;;
    evals/fixtures/*/check.sh|evals/fixtures/*/p2p-smoke.sh) return 0 ;;
    *) return 1 ;;
  esac
}

is_goal() {
  local base
  case "$1" in
    goals/*.md|evals/goals/*.md) ;;
    *) return 1 ;;
  esac
  base="${1##*/}"
  case "${base}" in
    *-result.md|README.md|_schema.md) return 1 ;;
    *) return 0 ;;
  esac
}

is_result() {
  case "$1" in
    goals/*-result.md|evals/goals/*-result.md) return 0 ;;
    *) return 1 ;;
  esac
}

is_outside() {
  if [[ "${LAYOUT}" == "hub" ]]; then
    case "$1" in
      fixtures/*|goals/*|runs/*|templates/*) return 1 ;;
      *) return 0 ;;
    esac
  else
    case "$1" in
      evals/*) return 1 ;;
      *) return 0 ;;
    esac
  fi
}

missing_kinds() {
  local mode="$1"
  shift
  local path outside=0 have_eval=0 have_goal=0 have_result=0
  for path in "$@"; do
    [[ -n "${path}" ]] || continue
    if is_outside "${path}"; then
      outside=1
    fi
    if is_eval "${path}"; then
      have_eval=1
    fi
    if is_goal "${path}"; then
      have_goal=1
    fi
    if is_result "${path}"; then
      have_result=1
    fi
  done
  if [[ "${outside}" -eq 0 ]]; then
    return 0
  fi
  if [[ "${have_eval}" -eq 0 ]]; then
    printf '%s\n' 'eval'
  fi
  if [[ "${have_goal}" -eq 0 ]]; then
    printf '%s\n' 'pre-run goal'
  fi
  if [[ "${mode}" == "ci" && "${have_result}" -eq 0 ]]; then
    printf '%s\n' 'post-run report'
  fi
}

report_missing() {
  local mode="$1"
  shift
  local missing kind
  missing="$(missing_kinds "${mode}" "$@")"
  [[ -n "${missing}" ]] || return 0
  printf '%s\n' '✗ pull request changes code without an eval pack' >&2
  while IFS= read -r kind; do
    [[ -n "${kind}" ]] || continue
    printf '  missing: %s\n' "${kind}" >&2
  done <<<"${missing}"
  return 1
}

read_paths_file() {
  local file="$1" line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "${line}" ]] || continue
    printf '%s\n' "${line}"
  done <"${file}"
}

paths_from_range() {
  local range="$1"
  git -C "${ROOT}" diff --name-only --diff-filter=ACMRD "${range}"
}

collect_precommit_paths() {
  local base=""
  if git -C "${ROOT}" rev-parse --verify origin/main >/dev/null 2>&1; then
    base="$(git -C "${ROOT}" merge-base origin/main HEAD)"
  elif git -C "${ROOT}" rev-parse --verify main >/dev/null 2>&1; then
    base="$(git -C "${ROOT}" merge-base main HEAD)"
  fi
  if [[ -n "${base}" ]]; then
    git -C "${ROOT}" diff --name-only --diff-filter=ACMRD "${base}" HEAD
  fi
  git -C "${ROOT}" diff --name-only --cached --diff-filter=ACMRD
}

check_list() {
  local mode="$1"
  shift
  local -a paths=()
  local line
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    paths+=("${line}")
  done
  if [[ "${#paths[@]}" -eq 0 ]]; then
    return 0
  fi
  report_missing "${mode}" "${paths[@]}"
}

self_test() {
  local tmp bad good prerun unit_only runs_only
  tmp="$(mktemp -d)"
  trap 'rm -rf "'"${tmp}"'"' RETURN
  bad="${tmp}/bad"
  good="${tmp}/good"
  prerun="${tmp}/prerun"
  unit_only="${tmp}/unit-only"
  runs_only="${tmp}/runs-only"
  if [[ "${LAYOUT}" == "hub" ]]; then
    cat >"${bad}" <<'EOF'
docs/evals.md
skills/goal/SKILL.md
Makefile
tests/unit/test_evals_harness.sh
EOF
    cat >"${good}" <<'EOF'
docs/evals.md
skills/goal/SKILL.md
fixtures/github.com/hermes/hermes/20260919-pr-eval-pack/check.sh
goals/github.com/hermes/hermes/20260919-pr-eval-pack.md
goals/github.com/hermes/hermes/20260919-pr-eval-pack-result.md
EOF
    cat >"${prerun}" <<'EOF'
skills/goal/SKILL.md
fixtures/github.com/hermes/hermes/20260919-pr-eval-pack/check.sh
goals/github.com/hermes/hermes/20260919-pr-eval-pack.md
EOF
    printf '%s\n' 'tests/unit/test_infra_tools.sh' >"${unit_only}"
    cat >"${runs_only}" <<'EOF'
skills/goal/SKILL.md
runs/20260919-pr-eval-pack/manifest.json
EOF
  else
    cat >"${bad}" <<'EOF'
docs/infra-tools.md
scripts/instance/create.sh
EOF
    cat >"${good}" <<'EOF'
docs/infra-tools.md
evals/fixtures/github.com/hermes/hermes/20260919-pr-eval-pack/check.sh
evals/goals/github.com/hermes/hermes/20260919-pr-eval-pack.md
evals/goals/github.com/hermes/hermes/20260919-pr-eval-pack-result.md
EOF
    cat >"${prerun}" <<'EOF'
scripts/instance/create.sh
evals/fixtures/github.com/hermes/hermes/20260919-pr-eval-pack/check.sh
evals/goals/github.com/hermes/hermes/20260919-pr-eval-pack.md
EOF
    printf '%s\n' 'tests/unit/test_infra_tools.sh' >"${unit_only}"
    cat >"${runs_only}" <<'EOF'
scripts/instance/create.sh
evals/runs/20260919-pr-eval-pack/manifest.json
EOF
  fi
  local fail=0
  if bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --paths-file "${bad}" >/dev/null 2>&1; then
    printf '✗ self-test: ci mode accepted a pack-less diff\n' >&2
    fail=1
  fi
  if ! bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --paths-file "${good}" >/dev/null 2>&1; then
    printf '✗ self-test: ci mode rejected a full pack\n' >&2
    fail=1
  fi
  if ! bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode pre-commit --paths-file "${prerun}" >/dev/null 2>&1; then
    printf '✗ self-test: pre-commit mode rejected fixture plus goal\n' >&2
    fail=1
  fi
  if bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --paths-file "${prerun}" >/dev/null 2>&1; then
    printf '✗ self-test: ci mode accepted a missing result\n' >&2
    fail=1
  fi
  if bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --paths-file "${unit_only}" >/dev/null 2>&1; then
    printf '✗ self-test: unit test counted as a pack\n' >&2
    fail=1
  fi
  if bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --paths-file "${runs_only}" >/dev/null 2>&1; then
    printf '✗ self-test: runs/ counted as a pack\n' >&2
    fail=1
  fi
  if [[ "${fail}" -ne 0 ]]; then
    exit 1
  fi
  printf '✓ eval pack gate\n'
}

resolve_pack_roots

mode="ci"
paths_file=""
range=""

if [[ "$#" -eq 0 ]]; then
  if [[ -n "${PRE_COMMIT:-}" ]]; then
    check_list pre-commit < <(collect_precommit_paths)
    exit $?
  fi
  self_test
  exit $?
fi

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --paths-file)
      paths_file="${2:-}"
      shift 2
      ;;
    --range)
      range="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

case "${mode}" in
  ci|pre-commit) ;;
  *)
    printf '✗ unknown mode: %s\n' "${mode}" >&2
    exit 2
    ;;
esac

if [[ -n "${paths_file}" && -n "${range}" ]]; then
  printf '✗ pass only one of --paths-file and --range\n' >&2
  exit 2
fi

if [[ -n "${paths_file}" ]]; then
  [[ -f "${paths_file}" ]] || {
    printf '✗ paths file not found: %s\n' "${paths_file}" >&2
    exit 2
  }
  check_list "${mode}" < <(read_paths_file "${paths_file}")
elif [[ -n "${range}" ]]; then
  check_list "${mode}" < <(paths_from_range "${range}")
else
  usage
  exit 2
fi
