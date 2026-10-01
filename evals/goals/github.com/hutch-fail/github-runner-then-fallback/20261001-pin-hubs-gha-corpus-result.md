---
schema: goal-result/v1
id: 20261001-pin-hubs-gha-corpus
status: pass
---

# Result

Pins bumped to post-gha-corpus / pack-gate hub SHAs (evals@e3a7201, pre-commit when present).

# Proof

- Fixture `check.sh` greps workflows for evals pin `e3a7201ed6e09a1cdc9a02c0e19dcda6848b8d5c`.
- Thin callers forward `TYPESAFE_API_KEY` so hub Tier2 meta/calibrate can run.

# Manual verification

None — covered by the hermetic fixture grep on workflow pins.

# Next action

None — merge when CI green.
