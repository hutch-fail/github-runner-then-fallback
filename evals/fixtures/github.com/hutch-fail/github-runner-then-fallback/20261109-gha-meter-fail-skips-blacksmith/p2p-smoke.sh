#!/usr/bin/env bash
# P2P: same choose_runner contract as F2P (offline).
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${dir}/check.sh"
