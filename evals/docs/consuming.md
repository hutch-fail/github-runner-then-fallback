# Consuming this hub

Primary **refresh** for org repos is file sync from this hub (`sync/pull`),
not `git subtree pull`. See [`syncing.md`](syncing.md) for harvest → hub PR →
redistribute. A volume/bind mount of this repo to `./evals` is fine for local
work; subtree add remains an optional bootstrap path.

## Refresh (preferred)

From the host project root, with a checkout of this hub available:

```bash
bash /path/to/evals/scripts/sync-pull.sh --hub /path/to/evals
# after kit lands:
make -C evals sync/pull HUB=/path/to/evals
bash evals/scripts/install-host-adapters.sh
```

`sync/pull` rsyncs the hub into `./evals/` (`--delete`), preserves
`evals/scope.yaml`, and omits `runs/` and `.github/`.

## Add (subtree, optional)

From the host project root (example):

```bash
git subtree add --prefix=evals git@github.com:hutch-fail/evals.git main --squash
# later prefer sync/pull; subtree pull is legacy:
git subtree pull --prefix=evals git@github.com:hutch-fail/evals.git main --squash
```

Or bind-mount / submodule so `./evals` is this tree.

## Install editor adapters

Cursor/Agents look for skills under the **project** `.cursor/skills` and
`.agents/skills`, not under `evals/.cursor`. Once:

```bash
bash evals/scripts/install-host-adapters.sh
```

That links the seven methodology skills and the `meta-dev` / `goal-spec` rules
into the host project.

## Run goals

```bash
make -C evals eval/assert-red GOAL=fixture-token-echo
make -C evals help
```

Optional thin wrappers in the host Makefile:

```make
eval/%:
	@$(MAKE) -C evals $@
```

## Personal process SoT

Scratch / cross-repo goals may live under `~/.hermes/evals` (`EVALS_ROOT` /
`HERMES_EVALS_ROOT`). Hermes may bind that tree as `evals_process/`. Durable
product bars belong under this hub’s `goals/github.com/<org>/<repo>/` inside the
product repo.

## Pre-commit / CI on the host

See the host-consumer snippet in [`evals.md`](evals.md). Point entries at
`evals/tests/unit/…` with `files: ^evals/(fixtures|goals)/`.

### Scoping and reusable workflows

Which goals apply to this product (universe / repo / language / active-dev),
consumer `evals/scope.yaml`, and how to hook GitHub Actions are specified in
[`scoping.md`](scoping.md).

Important: GitHub only runs workflows from the **repository root**
`.github/workflows/`. A subtree’s `evals/.github/` is ignored. Prefer calling
hub reusable workflows with a pin (copy stubs from
[`templates/github-workflows/`](../templates/github-workflows/)):

```yaml
jobs:
  eval-ci:
    uses: hutch-fail/evals/.github/workflows/eval-ci.yml@<pin>
    with:
      evals_path: evals
      hub_ref: <pin>
    secrets:
      OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
```

Prefer `eval-ci.yml` (select then pack). Deprecated: pack gate
(`eval-pack-gate.yml`) and select-only (`eval-select.yml`) — same
`OP_SERVICE_ACCOUNT_TOKEN`. Make-only select: `evals-make-select.yml`. Thin
callers pin the **same** commit/tag on `uses: @…` and `hub_ref` so scripts load
from the hub (stale product `evals/` subtrees are fine). Caller workspace alone
is enough for pack *diff* assertions (`EVALS_PACK_ROOT`), but select+assert
scripts and universe/language seeds still come from the private hub at
`hub_ref` — hence the App token minted after 1Password load.
**GitHub Releases** for pin-able repos live in
[`hutch-fail/actions`](https://github.com/hutch-fail/actions) (reusable
`semantic-release.yml`); copy only
[`templates/github-workflows/release.yml`](../templates/github-workflows/release.yml)
— never fork the release body — no in-repo `CHANGELOG.md`.
Optional product-owned manifest beside the subtree:

```yaml
# evals/scope.yaml
schema: evals-scope/v1
repo: github.com/<org>/<repo>
languages: []
opt_out: []
```

Validate / hint with the shared reader:

```bash
make -C evals eval/doctor-scope
```

Missing file prints a create hint and still exits 0 (`doctor-scope: ready`).
Invalid schema or `opt_out` without `reason` fails closed. When full consumer
`make doctor` lands ([issue #2](https://github.com/hutch-fail/evals/issues/2)),
call this target from that script.
## Hermes migration checklist (follow-up; not done in this hub)

1. Replace in-tree `evals/` with a subtree of this hub.
2. Change root Make `eval/*` to `$(MAKE) -C evals …` (or `bash evals/harness/…`).
3. Point seed / `assert_layout` at the subtree.
4. Stop duplicating the seven skills under `config/guest/skills` — symlink or
   bind from `evals/skills`.
5. Keep Incus disk binds and `evals_process/` personal SoT in Hermes.
