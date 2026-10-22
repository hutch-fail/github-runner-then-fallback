---
schema: goal/v1
id: 20261022-headroom-then-usejoy
title: Default headroom chain then usejoy for paid minutes
scope: repo
fixture_dir: evals/fixtures/github.com/hutch-fail/github-runner-then-fallback/20261022-headroom-then-usejoy
f2p_check: check.sh
p2p_check: p2p-smoke.sh
solver: none
---

# Executive overview

The action defaults to a headroom chain: GitHub up to 80% of 2000 included
minutes, Blacksmith up to 80% of 3000, then usejoy for overage. A reusable
workflow runs the detect job on usejoy by default. Two-way remains available
with `final-runner: ""`.

# Decision

A pass lets us claim those defaults are wired in `action.yml`, the reusable
`determine-runner.yml` meters on usejoy, offline `choose_runner` covers 80/80/final,
and docs describe the default chain. A pass does not prove live billing or
Blacksmith CLI auth against production tokens.

# User outcome

Operators get headroom + usejoy overage with only billing/Blacksmith secrets.
Missing Blacksmith meter data fails closed to usejoy when `fallback-on-error`
is true.

# Scope

| Covered | Not covered |
| --- | --- |
| Inputs, decide.sh chain predicate, README chain example | Live org billing / Blacksmith org-token calls |
| Offline choose_runner 80% cases | Org-wide workflow rollout |
| Two-way default preserved | usejoy usage metering (no public API) |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Sensible defaults on the action | `final-runner`→usejoy, threshold 80, included 2000, blacksmith 3000, primary/fallback labels |
| Reusable detect on usejoy | `.github/workflows/determine-runner.yml` defaults to usejoy |
| Pure choice implements 80/80/final | `choose_runner` / `under_headroom`; fixture asserts cases |
| Blacksmith usage path exists | `fetch_blacksmith_billable_minutes` in `decide.sh` |
| Two-way opt-out still works | P2P: under budget → primary, at budget → fallback |

# Dataset

No train/test split. Hermetic grep + sourced bash helpers against the product
tree (`HERMES_EVAL_REPO_ROOT`).

# Grading

| Check | Pass when |
| --- | --- |
| F2P `check.sh` | Chain inputs, `choose_runner` / headroom, Blacksmith fetch path, README docs, offline 80% cases |
| P2P `p2p-smoke.sh` | Two-way default still primary under budget and fallback at budget |
| Red baseline | Same F2P fails on `origin/main` (no `final-runner`) |

# Limitations

- Allowance values stay configured; neither GitHub nor the Blacksmith CLI
  returns minutes remaining.
- usejoy label is an input; no usage API is graded.
- This pack does not install or call the live Blacksmith CLI.

# Acceptance gates

Set before the run.

| Gate | Command / check |
| --- | --- |
| Red on main | `HERMES_EVAL_REPO_ROOT=<main tree> bash …/check.sh` exits non-zero |
| Green on branch | `make -C evals eval/run GOAL=github.com/hutch-fail/github-runner-then-fallback/20261022-headroom-then-usejoy` or fixture checks with repo root |
| Offline unit | `bash tests/test_decide_helpers.sh` |
