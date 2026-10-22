---
schema: goal/v1
id: 20261022-release-public-self-contained
title: Public repo ships semantic-release without private reusable
scope: repo
fixture_dir: evals/fixtures/github.com/hutch-fail/github-runner-then-fallback/20261022-release-public-self-contained
f2p_check: check.sh
p2p_check: p2p-smoke.sh
solver: none
---

# Executive overview

This repository is **public**. GitHub forbids calling a reusable workflow from a
**private** repository (`hutch-fail/actions`). Release must therefore be a
self-contained workflow on `ubuntu-latest` that still runs semantic-release
(GitHub Releases, no CHANGELOG file). Detect/picker is intentionally not used
here (same bootstrap rule as `ci.yml`).

# Decision

A pass lets us claim `.github/workflows/release.yml` no longer `uses:`
`hutch-fail/actions` and still contains a semantic-release path. A pass does
not prove a live release ran or that tags were published.

# User outcome

Merges to `main` can publish GitHub Releases again instead of failing in 0s
with “workflow was not found.”

# Scope

| Covered | Not covered |
| --- | --- |
| Self-contained release.yml shape | Live `npx semantic-release` on Actions |
| No private reusable `uses:` | Making this repository private |
| ubuntu-latest ship runner | Jog / Blacksmith for release |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| No private actions reusable | `release.yml` has no `uses: hutch-fail/actions` |
| semantic-release present | Workflow runs `semantic-release` (npx or equivalent) |
| Pinned ship runner | Job `runs-on: ubuntu-latest` |
| Triggers preserved | `push` to `main` and `workflow_dispatch` |

# Dataset

No train/test hold-out split. Hermetic exercise of
`tests/assert_release_yml.sh` against `HERMES_EVAL_REPO_ROOT`.

# Grading

| Check | Pass when |
| --- | --- |
| F2P `check.sh` | Runs `tests/assert_release_yml.sh` (self-contained release contract) |
| P2P `p2p-smoke.sh` | Triggers + permissions write contents |
| Red baseline | Current thin caller to private reusable fails the “no private uses” rule |

# Limitations

- Does not grade org access settings on `hutch-fail/actions`.
- Private sibling repos should keep the thin `uses:` pin pattern.

# Acceptance gates

Set before the run.

| Gate | Command / check |
| --- | --- |
| Red on baseline | `HERMES_EVAL_REPO_ROOT=<thin-caller tree> bash …/check.sh` exits non-zero |
| Green on branch | Same check against this branch exits 0 |
