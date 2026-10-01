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

A pass lets us claim this consumer pins pre-commit / evals to SHAs that include
unique runner-determination concurrency and the language/gha bar.

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Pins | Workflows reference evals@e3a7201 (and sibling hubs when present) |
