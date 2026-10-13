---
schema: goal/v1
id: 20261013-eval-ci-caller
title: Eval-ci caller pinned to hub tip
scope: repo
fixture_dir: evals/fixtures/github.com/hutch-fail/github-runner-then-fallback/20261013-eval-ci-caller
f2p_check: check.sh
p2p_check: p2p-smoke.sh
solver: none
---

# Decision

A pass lets us claim this consumer has a thin eval-ci.yml caller pinning
hutch-fail/evals reusable workflow + hub_ref to 5c075e0dc3e3fc97eafe8c39b47580907adaad4d.
