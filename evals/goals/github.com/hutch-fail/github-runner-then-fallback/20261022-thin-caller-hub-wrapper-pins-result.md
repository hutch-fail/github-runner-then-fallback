---
schema: result/v1
id: 20261022-thin-caller-hub-wrapper-pins
title: Thin callers pin wrapper-era pre-commit/evals hubs (github-runner-then-fallback) (result)
---

# Executive outcome

Listed thin callers pin wrapper-era hub SHAs and pass both billing secrets.

# Result

**Recommendation:** Adopt

# Outcome

Pass. F2P `check.sh` reports `thin_caller_hub_wrapper_pins_ok`.

# Proof

```text
HERMES_EVAL_REPO_ROOT=<repo> …/check.sh → thin_caller_hub_wrapper_pins_ok
exit code 0
```

# Manual verification

| Ran by hand | Observed | Automated check | Tier |
| --- | --- | --- | --- |
| F2P green | exit 0 | check.sh | hermetic |

# Blocking findings

None.

# Comparison

Main: pre-wrapper hub pins without BLACKSMITH on thin callers. Branch: hub pins
at pre-commit `77030147a25b824e38a5854e1377a3bb28deb750` / evals `eb8be6cdcc36461f658253d485f391e80a8137ce` with BLACKSMITH_API_TOKEN.
