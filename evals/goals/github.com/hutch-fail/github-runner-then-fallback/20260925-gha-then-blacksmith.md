---
schema: goal/v1
id: 20260925-gha-then-blacksmith
title: Prefer GHA minutes then Blacksmith; mint with client-id
scope: repo
fixture_dir: evals/fixtures/github.com/hutch-fail/github-runner-then-fallback/20260925-gha-then-blacksmith
f2p_check: check.sh
p2p_check: p2p-smoke.sh
solver: none
---

# Decision

A pass lets us claim this repo's GitHub Actions prefer free/included
`ubuntu-latest` minutes then fall back to Blacksmith via `determine-runner` +
`hutch-fail/github-runner-then-fallback`, and that App token minting uses
`client-id` (not deprecated `app-id` / invalid `installation-id`).

# User outcome

Included Actions minutes are burned first; org billing fallback stays Blacksmith.

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Prefer-GHA wiring | Local work jobs use determine-runner + fromJson; primary ubuntu-*; fallback blacksmith-* |
| App mint | create-github-app-token steps use client-id only |
| Billing map | Thin hub callers map ORG_BILLING_TOKEN or secrets: inherit |
| Safe checkout | No useblacksmith/checkout |

# Result file

Write `20260925-gha-then-blacksmith-result.md` beside this goal after the run.
