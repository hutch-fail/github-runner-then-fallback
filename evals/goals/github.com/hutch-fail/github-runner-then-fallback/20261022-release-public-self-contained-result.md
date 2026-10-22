---
schema: goal-result/v1
id: 20261022-release-public-self-contained
status: pass
---

# Executive outcome

`release.yml` is self-contained on `ubuntu-latest` with semantic-release; it no
longer `uses:` private `hutch-fail/actions` (blocked for public callers).

# Result

**Recommendation:** adopt

# Outcome

Pass. Hermetic F2P/P2P green. Live proof: after merge, `workflow_dispatch` on
`release` should create jobs (previously 0 jobs / “workflow was not found”).

# Proof

```text
HERMES_EVAL_REPO_ROOT=<main thin-caller> …/check.sh → FAIL (private uses:)
HERMES_EVAL_REPO_ROOT=<branch> …/check.sh → release_public_self_contained_ok
…/p2p-smoke.sh → release_public_self_contained_p2p_ok
```

# Manual verification

| Ran by hand | Observed | Automated check | Tier |
| --- | --- | --- | --- |
| `gh workflow run release.yml` on main (pre-fix) | 422 workflow was not found | — | live |
| F2P/P2P on branch | ok | check.sh / p2p-smoke.sh | hermetic |

# Blocking findings

None for the pack. Confirm a post-merge `release` run has jobs.

# Comparison

Main: thin `uses:` private reusable → silent failure. Branch: inlined release.

# Next action

Merge; watch first `release` run on `main` (push or dispatch).
