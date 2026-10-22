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

Pass. `determine-runner.yml` exposes a boolean `continue-on-error` input applied
to the determine job; smoke passes it under `with:`.

# Proof

```text
HERMES_EVAL_REPO_ROOT=<origin/main archive> …/check.sh → FAIL (missing input)
HERMES_EVAL_REPO_ROOT=<branch> …/check.sh → smoke_continue_on_error_input_ok
actionlint .github/workflows/{determine-runner,smoke-determine-runner}.yml → clean
```

# Manual verification

| Ran by hand | Observed | Automated check | Tier |
| --- | --- | --- | --- |
| actionlint on smoke + reusable | no syntax errors | F2P check.sh | hermetic |
| Main push smoke run 39833149845 | workflow file issue, zero jobs | F2P rejects job-level key | live-proof (pre-fix) |

# Blocking findings

None.

# Comparison

Main: smoke set job-level `continue-on-error` next to `uses:` → parse failure.
Branch: input on reusable workflow; smoke passes `with: continue-on-error: true`.

# Evidence and limitations

Does not yet prove usejoy is online; only that smoke is parse-valid and
non-blocking when the determine job fails.

# Next action

Merge; watch smoke on main for a real `use-runner` log line. Then pin a
consumer to this SHA for a live chain test.
