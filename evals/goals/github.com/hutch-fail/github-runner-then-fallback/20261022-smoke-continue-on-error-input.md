---
schema: goal/v1
id: 20261022-smoke-continue-on-error-input
title: Smoke passes continue-on-error as reusable workflow input
scope: repo
fixture_dir: evals/fixtures/github.com/hutch-fail/github-runner-then-fallback/20261022-smoke-continue-on-error-input
f2p_check: check.sh
p2p_check: p2p-smoke.sh
solver: none
---

# Executive overview

Non-blocking smoke must call the reusable determine-runner workflow without a
job-level `continue-on-error` (invalid next to `uses:`). Tolerance is an
input on the reusable workflow so main stays mergeable when usejoy or tokens
are unavailable.

# Decision

A pass lets us claim smoke is parse-valid and non-blocking via a
`continue-on-error` workflow_call input. A pass does not prove live usejoy
scheduling or billing API success.

# User outcome

Optional live smoke can fail without turning the workflow into a parse error
that creates zero jobs.

# Scope

| Covered | Not covered |
| --- | --- |
| Reusable input + smoke caller shape | Live runner choice / org secrets |
| Reject job-level continue-on-error on smoke | Release / required ci.yml |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Reusable accepts continue-on-error | `determine-runner.yml` workflow_call input + job field |
| Smoke passes under with: | `smoke-determine-runner.yml` has indented input, not job-level key |

# Dataset

No train/test split. Hermetic greps of workflow YAML.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Wiring shape | F2P `check.sh` | Parse-invalid callers are a static YAML shape bug |

# Acceptance gates

Set before the run.

| Gate | Pass | Fail |
| --- | --- | --- |
| Red on main tip before fix | check exits non-zero | Already green |
| Green on branch | check exits 0 | Missing input or job-level key remains |

# Limitations

Does not run Actions or assert smoke job conclusion.
