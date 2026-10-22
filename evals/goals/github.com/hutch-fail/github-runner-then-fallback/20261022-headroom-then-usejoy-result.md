---
schema: goal-result/v1
id: 20261022-headroom-then-usejoy
status: pass
---

# Executive outcome

Default headroom chain is wired: 80% of GitHub (2000), 80% of Blacksmith (3000),
then Jog (`jog` / usejog.com); reusable `determine-runner.yml` detects on
`ubuntu-latest`. Required `ci.yml` pins `ubuntu-latest` (no picker catch-22);
optional smoke dogfoods with `continue-on-error`. F2P red on `origin/main`,
green on this branch.

# Result

**Recommendation:** adopt

# Outcome

Pass. Action defaults, reusable detect-on-GitHub-hosted workflow, bootstrap-safe
`ci.yml`, non-blocking smoke, offline 80/80/final cases, and docs match.
Two-way remains via `final-runner: ""`. Final overage label is `jog`.

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

None for the hermetic pack. Live Jog requires private consumer repos listed on
usejog.com/account with credits; this action repo may stay public.

# Comparison

Main: two-way only, no Jog default. Branch: chain defaults + detect on
`ubuntu-latest` + final `jog`.

# Evidence and limitations

Live GitHub billing and Blacksmith org-token calls were not exercised in the
hermetic pack. Org usage observed elsewhere already exceeds both 80% pools, so
consumers should emit `jog` once pinned to this SHA.

# Next action

Merge; set org secrets `ORG_BILLING_TOKEN` and `BLACKSMITH_API_TOKEN`. Confirm
private consumers on usejog.com/account. Prefer
`uses: …/determine-runner.yml@v1` (or SHA) so detect runs on `ubuntu-latest`
and final defaults to `jog`.
