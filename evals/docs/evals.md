# Eval harness (this hub)

SoT and operator docs live under [`README.md`](../README.md).

Public API: `make eval/assert-red`, `make eval/verify`, `make eval/solve`,
`make eval/ab`, `make eval/parse`, `make eval/run`, `make eval/report`
(`GOAL=…`). From a host project with this tree at `./evals`, use
`make -C evals eval/…`. CLI skill: `goal`. Hypothesis drafts:
`docs/hypothesis-playground.md`. Consumer install: `docs/consuming.md`.

**Personal goals/fixtures/runs** (optional) live under `EVALS_ROOT` /
`HERMES_EVALS_ROOT` (default `~/.hermes/evals` on the host). This hub keeps the
harness, skills, and a seed copy of goals/fixtures for CI. Hermes (or similar)
may bind-mount the personal tree into each project as `evals_process/` (not
symlinks).

New process goals live under `goals/github.com/<slug>/` (mirrors typical guest
mounts such as `/home/ubuntu/github.com/<slug>/`).

Meta loop (author → develop|solve → judge): skills `meta-dev`, `goal-author`,
`goal-develop`, `goal-solve`, `goal-judge`; Cursor rule `.cursor/rules/meta-dev.mdc`.

A fixture with `check.sh` needs a goal whose `fixture_dir` points at it
(local pre-commit `eval-has-goal`). Commit `<goal>-result.md` in a later local
commit, after the goal and fixture (local pre-commit `result-not-with-eval`).
Both commits may be in one pull request. Squash or merge may combine them.
`eval-has-goal` and `result-not-with-eval` are not a pull-request or merge
check. A behavior-changing diff must also carry the pack. Local pre-commit
`pr-has-eval-pack` (`tests/unit/assert_pr_has_eval_pack.sh`) requires a fixture
check and a pre-run goal already on the branch. It does not require
`<goal>-result.md` in that commit. The pull-request job
`.github/workflows/eval-ci-pr.yml` (reusable `eval-ci.yml`) requires the
fixture, the goal, and the result before merge. `tests/unit/` and `runs/` do
not count. If a goal already covers the change, run it. Doing only the
implementation that turns checks green is forbidden. See [`README.md`](../README.md).
Dependabot (`dependabot[bot]`) skips eval-ci — version bumps are not
behavior PRs; use `make sync-dependabot` (with an eval pack) for policy YAML.

## Host consumer (subtree / mount at `evals/`)

After adding this hub at `<project>/evals`, run
`evals/scripts/install-host-adapters.sh` once so project-root
`.cursor/skills` and `.agents/skills` point into `evals/skills/`.

Host pre-commit snippet (paths relative to the **product** repo root):

```yaml
- id: eval-has-goal
  name: eval fixtures require a goal markdown
  entry: bash evals/tests/unit/assert_eval_has_goal.sh
  language: system
  pass_filenames: false
  files: ^evals/(fixtures|goals)/
- id: result-not-with-eval
  name: result markdown is not in the same local commit as its goal or fixture
  entry: bash evals/tests/unit/assert_result_commit.sh
  language: system
  pass_filenames: false
  files: ^evals/(fixtures|goals)/
- id: pr-has-eval-pack
  name: behavior changes include an eval fixture and a pre-run goal
  entry: bash evals/tests/unit/assert_pr_has_eval_pack.sh
  language: system
  pass_filenames: false
  files: ^(?!evals/)
```

Generic evals pre-commit (add **after** the `hutch-fail/pre-commit`
`platform` hook). One host entry; it runs the pack gate under `PRE_COMMIT=1`
(fixture + pre-run goal; result stays CI-only), then the shared bars dispatcher
(`scripts/eval-bars.sh` / `make eval/bars`):

```yaml
- repo: local
  hooks:
    - id: evals-pre-commit
      name: evals — apply scoped bars for changed paths
      entry: bash evals/scripts/pre-commit-evals.sh
      language: system
      pass_filenames: true
```

Hosts that already use `evals-pre-commit` pick up the pack gate on the next
`sync/pull` — no second local hook required. The dedicated `pr-has-eval-pack`
snippet above remains valid (hub / specialized consumers).

Shared entrypoint (local / pre-commit / CI):

```bash
make eval/bars                          # or: bash scripts/eval-bars.sh
HERMES_EVAL_SCAN_ROOT=/path/to/product make eval/bars
```

Behavior today:

| Trigger | Family | Bars run |
| --- | --- | --- |
| (always) | `universe` | No raw `secrets.GH_APP_ID` / `GH_APP_PRIVATE_KEY` (`20260924-no-gha-app-actions-secrets`) |
| `*.tf` / `*.tf.json` | `opentofu` | Remote-backend language bar (`20260924-remote-backend-locking`) |
| `*.ts` / `*.tsx` / `tsconfig.json` | `typescript` | Stub (family detected; no language bar yet) |
| `design/**`, `docs/design-system/**`, `docs/north-star/**`, `evals/ui/**`, `scripts/ui-*`, own-leaf `ui-process` / `ui-jev` / `ui-visual` / `ui-semantic` | `ui` | Scope-manifest + process-entrypoint language bars |

Language ids for `evals/scope.yaml` / select: `opentofu`, `typescript`,
`python`, `ui` — see [`scoping.md`](scoping.md) registry. `eval/select` is
declaration-only. `eval/bars` selects language families from (1) `languages:`
in the consumer manifest (so CI / `make eval/bars` with no path args still
runs declared UI/OpenTofu bars), (2) changed path args (pre-commit), and
(3) `HERMES_EVAL_FORCE_FAMILIES`. Path-detect still **warns** when paths imply
`ui` / `opentofu` but the manifest omits that id. Do **not** treat `src/**`
alone as org-wide `ui` (too broad).

New UI/UX consumers: declare `languages: [ui]`, keep process fixtures under
own-leaf `ui-process/` (or legacy `evals/ui/`), expose `npm run ui:process` or
`scripts/ui-process-check.*`. Shared bars then apply via `eval-ci` /
`make eval/bars` without a product-specific bars job. Node/Jev-heavy gates stay
optional product workflows.

Universe bars always run against `HERMES_EVAL_SCAN_ROOT` (default cwd).
Extend `scripts/eval-bars.sh` when adding new families.

Rule A for remote-backend: fail `backend "local"` and missing backend; pass any
non-local backend type (including partial `backend "s3" {}`).

When these scripts run from a product repo, they detect the hub at `evals/`
automatically (see script headers).

## Scoping and CI selection

Design and frontmatter rules: [`scoping.md`](scoping.md). `scope` /
`languages` / `repos` are enforced by `harness/lib/scope.sh` on parse and
other harness verbs ([#5](https://github.com/hutch-fail/evals/issues/5)).

Discovery:

```bash
make eval/list                 # human-readable applicable goals
make eval/select               # absolute paths for CI
make eval/doctor-scope         # hint/validate evals/scope.yaml
EVALS_INCLUDE_ACTIVE=1 make eval/select
GOAL=fixture-token-echo make eval/select
```

Implemented in `harness/lib/select.sh` + `harness/lib/manifest.sh`
([#6](https://github.com/hutch-fail/evals/issues/6),
[#7](https://github.com/hutch-fail/evals/issues/7)).
Shared reader soft-defaults when `evals/scope.yaml` is missing; invalid
manifests fail closed. `eval/doctor-scope` prints a create hint when missing
and `doctor-scope: ready` when OK.
- **Eval CI (today):** one reusable [`eval-ci.yml`](../.github/workflows/eval-ci.yml)
  job runs select, then shared bars (`scripts/ci-eval-bars.sh` →
  `make eval/bars`), then pack. Consumers pass `OP_SERVICE_ACCOUNT_TOKEN` so
  `1password/load-secrets-action` can load App credentials from item
  `hutch-fail-platform-github` and checkout this private hub at `hub_ref`. Hub
  PR caller: [`eval-ci-pr.yml`](../.github/workflows/eval-ci-pr.yml). Host stub:
  [`templates/github-workflows/eval-ci.yml`](../templates/github-workflows/eval-ci.yml).
- **Bars (not full select→verify):** `make eval/bars` always runs applicable
  universe checks with `HERMES_EVAL_SCAN_ROOT` set to the caller workspace.
  Language families run when `languages:` in the consumer manifest, matching
  paths, or `HERMES_EVAL_FORCE_FAMILIES` select them.
  This is **not** full select→verify for every selected goal
  ([#8](https://github.com/hutch-fail/evals/issues/8)).
- **Deprecated callables:** [`eval-pack-gate.yml`](../.github/workflows/eval-pack-gate.yml)
  and [`eval-select.yml`](../.github/workflows/eval-select.yml) remain for Wave 2
  consumer migration; new callers must pin `eval-ci.yml`. Actions stay thin —
  Make/scripts only ([issue #2](https://github.com/hutch-fail/evals/issues/2)).

Do **not** enable a required select/verify gate beyond pack assert and shared
`eval/bars` in the hub’s default PR workflow. A later policy may require
applicable universe/language goals to be green or opted out; that remains
separate ([#8](https://github.com/hutch-fail/evals/issues/8)).
