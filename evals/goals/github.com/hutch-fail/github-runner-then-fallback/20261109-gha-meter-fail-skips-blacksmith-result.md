---
schema: result/v1
id: 20261109-gha-meter-fail-skips-blacksmith
verdict: Adopt
---

# Result

Offline F2P/P2P green on the branch; certified red on `origin/main` (empty GHA
meter previously returned `fallback`).

## Evidence

- `bash tests/test_decide_helpers.sh` — `chain gha fail → final (skip blacksmith)`
- `HERMES_EVAL_REPO_ROOT=<main archive> bash …/check.sh` → exit 1
- `HERMES_EVAL_REPO_ROOT=<branch> bash …/check.sh` → `gha_meter_fail_skips_blacksmith_ok`

## Manual verification

```bash
bash tests/test_decide_helpers.sh
HERMES_EVAL_REPO_ROOT="$PWD" bash evals/fixtures/github.com/hutch-fail/github-runner-then-fallback/20261109-gha-meter-fail-skips-blacksmith/check.sh
```
