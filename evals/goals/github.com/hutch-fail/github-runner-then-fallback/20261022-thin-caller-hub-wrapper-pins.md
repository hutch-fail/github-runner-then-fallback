---
schema: goal/v1
id: 20261022-thin-caller-hub-wrapper-pins
title: Thin callers pin wrapper-era pre-commit/evals hubs (github-runner-then-fallback)
scope: repo
fixture_dir: evals/fixtures/github.com/hutch-fail/github-runner-then-fallback/20261022-thin-caller-hub-wrapper-pins
f2p_check: check.sh
p2p_check: p2p-smoke.sh
solver: none
---

# Executive overview

`github-runner-then-fallback` thin callers for pre-commit and/or eval-ci still pin hub SHAs from
before the org determine-runner wrapper landed. They must pin
`pre-commit@77030147a25b824e38a5854e1377a3bb28deb750` and/or `evals@eb8be6cdcc36461f658253d485f391e80a8137ce` (matching `hub_ref`) and pass
`BLACKSMITH_API_TOKEN` beside `ORG_BILLING_TOKEN` so the wrapper can consider
Blacksmith in the GHA → Blacksmith → Jog chain.

# Decision

A pass lets us claim the listed thin-caller workflows use the wrapper-era hub
pins with both billing secrets. A pass does not prove live runner labels on the
next PR.

# User outcome

Operators get Blacksmith considered on shared CI paths after org minutes headroom
is exhausted, instead of skipping straight past an empty Blacksmith meter to Jog.

# Scope

| Covered | Not covered |
| --- | --- |
| Thin callers listed in assert_hub_pins.py | Product workflows that already call platform-ci directly |
| Hub pin + BLACKSMITH_API_TOKEN | Live billing choice |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Hub pins | pre-commit / eval-ci / hub_ref at wrapper-era SHAs |
| Both secrets | ORG_BILLING_TOKEN + BLACKSMITH_API_TOKEN |

# Dataset

Hermetic greps of the thin-caller workflow files. No train/test hold-out — those
files are the case set. Live Actions runs are hold-out.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Wiring | F2P `check.sh` | Static YAML shape |

# Acceptance gates

Set before the run.

| Gate | Pass | Fail |
| --- | --- | --- |
| Red on main | check exits non-zero | Already on hub pins |
| Green on branch | check exits 0 | Missing pin/secrets |

# Limitations

- Hermetic F2P greps wiring only. Live runner choice is hold-out.
