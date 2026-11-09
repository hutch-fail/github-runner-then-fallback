---
schema: goal/v1
id: 20261109-gha-meter-fail-skips-blacksmith
title: Chain mode skips Blacksmith when the GitHub meter fails
scope: repo
fixture_dir: evals/fixtures/github.com/hutch-fail/github-runner-then-fallback/20261109-gha-meter-fail-skips-blacksmith
f2p_check: check.sh
p2p_check: p2p-smoke.sh
solver: none
---

# Executive overview

When the GitHub Actions billing meter fails (bad/expired `ORG_BILLING_TOKEN`,
401, etc.) while free included minutes remain, chain mode must not select
Blacksmith. It must emit the final runner (Jog). This closes the hole that
turned a dead billing token into a Blacksmith invoice.

# Decision

A pass lets us claim `choose_runner` chain mode treats an empty GHA meter as
“go to final,” and docs/tests match. A pass does not prove live org tokens or
that every consumer pin is on the hub wrapper.

# User outcome

Operators keep free GitHub minutes (or Jog) when billing auth breaks, instead
of silently burning Blacksmith minutes and getting a surprise bill.

# Scope

| Covered | Not covered |
| --- | --- |
| `choose_runner` chain empty-GHA → final | Live `ORG_BILLING_TOKEN` rotation |
| Offline unit + README wording | Org-wide consumer pin rollout |
| Two-way empty-meter → fallback preserved | Detect-job hardcodes in other repos |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Empty GHA meter in chain → final | `choose_runner chain "" …` returns `final` |
| Blacksmith still used when GHA exhausted under headroom | `choose_runner chain 1800 2000 1000 3000 80` → `fallback` |
| Docs say GHA meter failure emits final | README chain decision notes |
| Two-way unchanged | empty meter still → `fallback` |

# Dataset

No train/test split. Hermetic bash against `HERMES_EVAL_REPO_ROOT`.

# Grading

| Check | Pass when |
| --- | --- |
| F2P `check.sh` | Chain empty-GHA → final; exhausted GHA → blacksmith; README; two-way |
| P2P `p2p-smoke.sh` | Same choose_runner cases after sourcing decide.sh |
| Red baseline | Same F2P fails on `origin/main` (empty GHA still → fallback) |

# Limitations

- Does not rotate secrets or bump consumer workflow pins.
- Jog availability for private repos remains an operator concern.

# Acceptance gates

Set before the run.

| Gate | Command / check |
| --- | --- |
| Red on main | `HERMES_EVAL_REPO_ROOT=<main tree> bash …/check.sh` exits non-zero |
| Green on branch | same check exits 0 on this tree |
