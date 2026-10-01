---
schema: goal/v1
id: 20261001-pin-hubs-gha-corpus
title: Pin hubs to language/gha corpus SHAs
scope: repo
fixture_dir: evals/fixtures/github.com/hutch-fail/github-runner-then-fallback/20261001-pin-hubs-gha-corpus
f2p_check: check.sh
p2p_check: p2p-smoke.sh
solver: none
---

# Decision

A pass lets us claim this consumer pins evals (and pre-commit when present) to
SHAs that include unique runner-determination concurrency, language/gha bars,
and the dependency-bump pack-gate skip.

# Success criteria

| Criterion | What we look at |
| --- | --- |
| evals pin | Thin `eval-ci.yml` (and sibling evals callers) use @e3a7201 / matching hub_ref |
| pre-commit pin | Thin `pre-commit.yml` / `pre-commit-ci.yml` use @dfd9965 when they call the reusable |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Are evals thin callers on tip? | uses/hub_ref = e3a7201ed6e09a1cdc9a02c0e19dcda6848b8d5c | older SHA or drift between uses and hub_ref |
| Are pre-commit thin callers on tip (when present)? | uses = dfd996508e0d1d4c06ac904e4ce883600125e0d1 | older SHA or missing pin |
