---
schema: goal/v1
id: 20261022-headroom-then-usejoy
title: Opt-in headroom chain then usejoy for paid minutes
scope: repo
fixture_dir: evals/fixtures/github.com/hutch-fail/github-runner-then-fallback/20261022-headroom-then-usejoy
f2p_check: check.sh
p2p_check: p2p-smoke.sh
solver: none
---

# Executive overview

Consumers can leave headroom on free GitHub Actions and Blacksmith minutes,
then send paid work to a final runner (usejoy). The detect job is documented to
run on that final label so metering does not burn the free pools. Two-way
behavior stays the default when `final-runner` is unset.

# Decision

A pass lets us claim the action exposes an opt-in chain (GitHub under
`usage-threshold` of `included-minutes` → Blacksmith under the same threshold
of `blacksmith-included-minutes` → `final-runner`) with offline
`choose_runner` coverage, and that docs show `determine-runner` on the final
label. A pass does not prove live billing API or Blacksmith CLI auth against
production tokens.

# User outcome

Operators keep free-minute headroom and route overage to usejoy without
rewriting every workflow’s two-way inputs. Missing Blacksmith meter data fails
closed to the final runner when `fallback-on-error` is true.

# Scope

| Covered | Not covered |
| --- | --- |
| Inputs, decide.sh chain predicate, README chain example | Live org billing / Blacksmith org-token calls |
| Offline choose_runner 80% cases | Org-wide workflow rollout |
| Two-way default preserved | usejoy usage metering (no public API) |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Chain inputs exist on the action | `action.yml` has `final-runner`, `usage-threshold`, `blacksmith-included-minutes`, `blacksmith-api-token` |
| Pure choice implements 80/80/final | `choose_runner` / `under_headroom` in `scripts/decide.sh`; fixture asserts cases |
| Blacksmith usage path exists | `fetch_blacksmith_billable_minutes` in `decide.sh` |
| Docs show detect on final label | README mentions `final-runner` / `determine-runner` |
| Two-way default intact | P2P: under budget → primary, at budget → fallback |

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
