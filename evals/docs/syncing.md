# Org-wide evals sync (harvest ↔ redistribute)

This hub (`hutch-fail/evals`) is the org **source of truth** for the shared
kit (harness, skills, docs, Make API, universe/language goals) and for
**harvested product packs**. Consumer `evals/scope.yaml` never lives on the
hub.

## Taxonomy

| Class | Meaning | Harvest | Redistribute |
| --- | --- | --- | --- |
| **kit** | Has `evals/Makefile` | Packs + kit-only deltas | `sync/pull` |
| **pack-only** | Packs/`scope.yaml` but no kit | Packs only | Bootstrap via `sync/pull` |
| **missing** | No `evals/` | Nothing | Bootstrap kit + minimal `scope.yaml` |
| **skipped** | `service-meter`, archived, or hub itself | — | — |

## Workflow (mechanical)

```text
discover → harvest → hub PR → merge → pull/bootstrap every included repo
```

From a machine with org checkouts under `~/github.com/hutch-fail`
(`CONSUMERS_ROOT`):

```bash
# 0) Inventory (gh + local path probe)
make sync/list CONSUMERS_ROOT="$HOME/github.com/hutch-fail"

# 1) Harvest packs (+ kit-only consumer files) into this hub working tree
make sync/harvest CONSUMERS_ROOT="$HOME/github.com/hutch-fail"
# optional: scripts/sync-harvest.sh --dry-run

# 2) Open/land a hub PR with tooling + harvested content

# 3) After hub is on origin/main, per consumer repo root:
bash /path/to/evals/scripts/sync-pull.sh --hub /path/to/evals
# or once kit exists:
make -C evals sync/pull HUB=/path/to/evals
bash evals/scripts/install-host-adapters.sh

# 4) Doctor across the org
make sync/doctor CONSUMERS_ROOT="$HOME/github.com/hutch-fail"
```

Discovery always uses `gh repo list` (not a hard-coded subset). Archived
repos and `service-meter` are skipped. Local `*-wt-*` / `.worktrees/` are
ignored (only canonical clones under `CONSUMERS_ROOT/<name>` or
`dot-github` for `.github`).

## Ownership

| Layer | Owner | Notes |
| --- | --- | --- |
| Kit / universe / language | This hub | Author on hub; consumers refresh via `sync/pull` |
| Repo packs | Authored in any repo | Must be **harvested to hub** for org SoT before redistribute |
| `scope.yaml` | Product repo only | Never copied to hub; `sync/pull` preserves or `--init-scope` |

## Conflict policy

**Packs**

- Consumer’s **own** leaf (`goals|fixtures/github.com/<org>/<this-repo>/`)
  overwrites hub on harvest.
- Shared leaves (other repos, hermes seeds): copy consumer-only files; when
  both sides exist and differ, hub keeps content and harvest prints
  `CONFLICT` (re-run with `--prefer-consumer` only when intentional).

**Kit**

- Consumer-only kit files are copied into the hub.
- Content conflicts keep hub (kit SoT). Prefer file sync over
  `git subtree pull` so `scope.yaml`, `runs/`, and consumer root
  `.github/` stay under product control.

## What `sync/pull` redistributes

**Only:**

1. Hub **kit** (harness, scripts, skills, docs, Make API, flat smoke fixtures, …)
2. `goals|fixtures/universe/` and `goals|fixtures/language/`
3. This consumer’s **own** leaf `goals|fixtures/github.com/<org>/<this-repo>/`
   (consumer-owned files are preserved, then that leaf is overlaid from hub
   when present)

**Never** copies other products’ `github.com/**` packs (that broke
`eval/select` on earlier redistributes). Always omits `runs/` and `.github/`,
and restores `scope.yaml` after sync.

## Org reset → redistribute → ship → land

```bash
make sync/reset-main CONSUMERS_ROOT="$HOME/github.com/hutch-fail"
make sync/redistribute CONSUMERS_ROOT="$HOME/github.com/hutch-fail" HUB="$HOME/github.com/hutch-fail/evals"
# redistribute opens draft PRs; then batch ready-for-review → land → origin/main
make sync/ship-land CONSUMERS_ROOT="$HOME/github.com/hutch-fail"   # reset+redistribute + checklist
make sync/doctor CONSUMERS_ROOT="$HOME/github.com/hutch-fail"
```

Skill: `evals-org-redistribute`. Fail closed on dirty trees. Draft PRs skip
eval-ci/pre-commit until ready-for-review. Kit-only syncs rely on consumer
`evals/**` paths-ignore for pre-commit (do not use `[skip ci]`).

## Why not subtree-only?

`git subtree pull` is awkward for bootstrap, deletes poorly controlled
paths, and fights product-owned `scope.yaml`. `sync/pull` uses selective
`rsync` (see above) instead of mirroring the whole harvested pack tree.

## Agent checklist

1. `make sync/list` — confirm classes; fail closed on unexpected non-archived repos.
2. Reset included clones to `origin/main` (never touch `service-meter`).
3. Branch hub `chore/harvest-consumer-evals` → tooling + `sync/harvest`.
4. Validate (`tests/unit`, harvest `--dry-run`); open hub PR; merge when green.
5. One branch/PR per included consumer: `sync-pull.sh`, preserve/create
   `scope.yaml`, `install-host-adapters.sh`.
6. `make sync/doctor` — every included repo is **kit** and has `scope.yaml`.
7. Leave consumer PRs open for review; do not auto-merge.

## Make targets

| Target | Role |
| --- | --- |
| `make sync/list` | TSV/JSON inventory |
| `make sync/harvest CONSUMERS_ROOT=…` | Consumer → hub |
| `make sync/pull HUB=…` | Hub → this consumer `evals/` (kit + universe/language + own leaf) |
| `make sync/reset-main` | Included clones → `origin/main` (refuse dirty) |
| `make sync/redistribute` | Branch + sync-pull + adapters + draft PR |
| `make sync/ship-land` | Reset + redistribute + ready/land checklist |
| `make sync/doctor` | Org inventory vs hub tip |
