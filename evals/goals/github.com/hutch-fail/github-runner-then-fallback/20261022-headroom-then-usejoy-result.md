---
schema: goal-result/v1
id: 20261022-headroom-then-usejoy
status: pass
---

# Executive outcome

Opt-in headroom chain (GitHub → Blacksmith → final/usejoy) is present; two-way
default remains. F2P was red on `origin/main` and green on this branch.

# Result

**Recommendation:** adopt

# Outcome

Pass. Chain inputs, `choose_runner` / `under_headroom`, Blacksmith usage fetch
path, and README chain docs are in place. Offline 80% cases and two-way default
covered by fixture + `tests/test_decide_helpers.sh`.

# Proof

```text
HERMES_EVAL_REPO_ROOT=<origin/main archive> …/check.sh → FAIL: action.yml missing final-runner input (exit 1)
HERMES_EVAL_REPO_ROOT=<branch> …/check.sh → headroom_then_usejoy_ok
…/p2p-smoke.sh → headroom_then_usejoy_p2p_ok
bash tests/test_decide_helpers.sh → All offline tests passed.
```

# Manual verification

| Ran by hand | Observed | Automated check | Tier |
| --- | --- | --- | --- |
| F2P against `git archive origin/main` | exit 1 missing `final-runner` | `check.sh` | hermetic |
| F2P/P2P against branch tree | both ok | `check.sh` / `p2p-smoke.sh` | hermetic |
| `bash tests/test_decide_helpers.sh` | all cases ok | same + CI offline step | hermetic |

# Blocking findings

None.

# Comparison

Main: two-way only. Branch: chain when `final-runner` set; threshold default 80.

# Evidence and limitations

Live GitHub billing and Blacksmith org-token calls were not exercised. usejoy
has no metered API in this pack.

# Next action

Merge; consumers opt in with `final-runner`, `blacksmith-included-minutes`, and
`blacksmith-api-token`. Run `determine-runner` on the final label.
