---
schema: goal-result/v1
id: 20261001-pin-hubs-gha-corpus
status: pass
---

# Result

Pins and pack fixtures hardened: F2P asserts every bumped hub caller; P2P is
structural (passes on the pre-change tree); goal has Acceptance gates with
`Set before the run.`

# Proof

- `check.sh` requires evals tip `e3a7201ed6e09a1cdc9a02c0e19dcda6848b8d5c` on evals callers and pre-commit tip
  `dfd996508e0d1d4c06ac904e4ce883600125e0d1` on thin pre-commit callers when present.
- `p2p-smoke.sh` checks pack/goal/result shape only (no tip SHA assertion).

# Manual verification

None — hermetic fixture greps cover the pin criteria; Kody threads on incomplete
F2P / non-P2P smoke addressed in this change.

# Next action

None.
