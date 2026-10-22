#!/usr/bin/env bash
# Ensure GitHub labels used by semantic-release exist.
set -euo pipefail
gh label create released \
  --color 0E8A16 \
  --description "Included in a GitHub Release" \
  --force
gh label create "release:pending" \
  --color FBCA04 \
  --description "Waiting for the next semantic-release" \
  --force
