#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v shellcheck >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq shellcheck
fi
shellcheck "${ROOT}/scripts/decide.sh"
echo shellcheck_ok
