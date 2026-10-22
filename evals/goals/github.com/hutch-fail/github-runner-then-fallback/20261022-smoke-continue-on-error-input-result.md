---
schema: result/v1
id: 20261022-smoke-continue-on-error-input
title: Smoke passes continue-on-error as reusable workflow input (result)
---

# Executive outcome

Smoke can call the reusable determine-runner workflow without a parse-invalid
job-level `continue-on-error`.

# Result

**Recommendation:** Adopt

# Outcome

Pass. Smoke is parse-valid via a `continue-on-error` input; cross-repo callers
checkout the action tree (`action-ref`); Blacksmith CLI install/auth stay on
stderr so minutes parse cleanly.

# Proof

```text
HERMES_EVAL_REPO_ROOT=<origin/main archive> …/check.sh → FAIL (missing input)
HERMES_EVAL_REPO_ROOT=<branch> …/check.sh → smoke_continue_on_error_input_ok
machine-layers canary job 120021274438:
  blacksmith_billable_minutes=11646.0; mode=chain choice=final
```

# Manual verification

| Ran by hand | Observed | Automated check | Tier |
| --- | --- | --- | --- |
| actionlint on smoke + reusable | no syntax errors | F2P check.sh | hermetic |
| Main push smoke run 39833149845 | workflow file issue, zero jobs | F2P rejects job-level key | live-proof (pre-fix) |
| machine-layers PR #165 determine | choice=final with clean minutes | consumer canary | live-proof |

# Blocking findings

None for this pack. usejoy label still unregistered org-wide.

# Comparison

Main: job-level `continue-on-error` + bare `uses: ./` broke callers.
Branch: input tolerance, checkout + `./_github-runner-then-fallback`, stderr-clean CLI.

# Evidence and limitations

Consumer canary keeps `final-runner` on Blacksmith until usejoy exists.

# Next action

Merge; retarget machine-layers pin to the merge commit on main.
