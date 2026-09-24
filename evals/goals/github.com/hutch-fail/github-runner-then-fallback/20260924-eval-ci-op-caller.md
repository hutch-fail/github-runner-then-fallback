---
schema: goal/v1
id: 20260924-eval-ci-op-caller
title: Thin eval-ci caller uses OP_SERVICE_ACCOUNT_TOKEN
fixture_dir: evals/fixtures/github.com/hutch-fail/github-runner-then-fallback/20260924-eval-ci-op-caller
f2p_check: check.sh
p2p_check: p2p-smoke.sh
solver: none
---

Set before the run.

# Decision

A pass means this repo's `.github/workflows/eval-ci.yml` clones the private evals hub via 1Password-loaded App credentials (`OP_SERVICE_ACCOUNT_TOKEN`), not raw `secrets.GH_APP_*`.

# User outcome

Fleet CI can run global eval bars without storing GitHub App PEM as Actions secrets on each repo.

# Scope

| Covered | Not covered |
| --- | --- |
| Thin eval-ci caller secrets wiring | Org-wide secret provisioning UI |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Caller passes OP token | `.github/workflows/eval-ci.yml` contains `OP_SERVICE_ACCOUNT_TOKEN` |
| Caller does not pass GH_APP secrets | File has no `secrets.GH_APP_ID` / `secrets.GH_APP_PRIVATE_KEY` |

# Acceptance gates

| Question | Pass | Fail |
| --- | --- | --- |
| Does check.sh exit 0 on the wired caller? | exit 0 | exit non-zero |

# Result file

After the run, write `<same-name>-result.md` beside this goal.
