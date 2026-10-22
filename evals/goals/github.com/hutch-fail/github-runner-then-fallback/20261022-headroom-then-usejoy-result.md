---
schema: goal-result/v1
id: 20261022-headroom-then-usejoy
status: pass
---

# Executive outcome

Default headroom chain is wired: 80% of GitHub (2000), 80% of Blacksmith (3000),
then usejoy; reusable `determine-runner.yml` meters on usejoy. F2P red on
`origin/main`, green on this branch.

# Result

**Recommendation:** adopt

# Outcome

Pass. Action defaults, reusable detect-on-usejoy workflow, offline 80/80/final
cases, and docs match the default chain. Two-way remains via `final-runner: ""`.

# Proof

```text
HERMES_EVAL_REPO_ROOT=<origin/main archive> …/check.sh → FAIL (no final-runner default / chain)
HERMES_EVAL_REPO_ROOT=<branch> …/check.sh → headroom_then_usejoy_ok
…/p2p-smoke.sh → headroom_then_usejoy_p2p_ok
bash tests/test_decide_helpers.sh → All offline tests passed.
bash tests/assert_action_yml.sh → action_yml_ok
```

# Manual verification

| Ran by hand | Observed | Automated check | Tier |
| --- | --- | --- | --- |
| F2P against `git archive origin/main` | non-zero (missing defaults/chain) | `check.sh` | hermetic |
| F2P/P2P against branch | both ok | `check.sh` / `p2p-smoke.sh` | hermetic |
| `assert_action_yml.sh` + `test_decide_helpers.sh` | ok | CI offline steps | hermetic |

# Blocking findings

None.

# Comparison

Main: two-way only, no usejoy default. Branch: chain defaults + detect-on-usejoy reusable workflow.

# Evidence and limitations

Live GitHub billing and Blacksmith org-token calls were not exercised. The
usejoy label default is `usejoy-2vcpu-ubuntu-2404` until the install’s real
label is confirmed.

# Next action

Merge; set org secrets `ORG_BILLING_TOKEN` and `BLACKSMITH_API_TOKEN`. Prefer
`uses: …/determine-runner.yml@v1` so detect runs on usejoy by default.
