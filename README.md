# github-runner-then-fallback

Prefer **GitHub-hosted** runners while included/free Actions minutes remain, then fall back to another label (typically **Blacksmith**).

## Attribution

The workflow shape — a cheap `determine-runner` job whose JSON output feeds `runs-on: ${{ fromJson(...) }}` — follows [mikehardy/runner-fallback-action](https://github.com/mikehardy/runner-fallback-action).

**This is not a fork of that action.** mikehardy’s predicate is “is a self-hosted primary online?”. GitHub-hosted labels like `ubuntu-latest` never appear in the self-hosted runners API, so swapping primary/fallback labels alone cannot implement “burn free GHA minutes, then Blacksmith.” This action replaces the predicate with an **Actions minutes quota** check against org billing usage.

## Billing spike (hutch-fail, 2026-09)

| Endpoint | Result |
| --- | --- |
| `GET /orgs/{org}/settings/billing/actions` (legacy) | **410 Gone** — enhanced billing moved this API |
| `GET /orgs/{org}/settings/billing/usage` | **200** — daily SKU rows (`Actions Linux` minutes, storage, …) |
| `GET /organizations/{org_id}/settings/billing/usage/summary` | **200** — period totals; `actions_linux` has `grossQuantity` / `discountQuantity` / `netQuantity` (minutes) |
| Budgets API (`…/settings/billing/budgets`) | **200** — dollar budgets only; no free-minutes remaining field |

**There is no API field for “included minutes remaining.”** Enhanced usage exposes how many Linux Actions minutes were *used* (`grossQuantity` for `actions_linux`), not the plan’s included allowance.

### Decision: configured `included-minutes`

Consumers set the included/free budget explicitly (org Actions plan allowance), typically via repository/org variable `ACTIONS_INCLUDED_MINUTES` (GitHub Free organizations: **2000** private-repo minutes/month).

This action:

1. Reads current-period `actions_linux` `grossQuantity` from the usage **summary** API
2. If `used < included-minutes` → emit **primary** (`ubuntu-latest`, …)
3. Else → emit **fallback** (`blacksmith-…`)

Token must be a **classic** PAT owned by an org owner or billing manager, with
`admin:org`. Enhanced billing **usage** APIs do **not** support fine-grained
PATs. Default `GITHUB_TOKEN` is **not** enough.

## Pin

Consumers should pin a release tag or commit SHA, for example:

```yaml
uses: hutch-fail/github-runner-then-fallback@v1
# or: uses: hutch-fail/github-runner-then-fallback@<full-sha>
```

See [Releases](https://github.com/hutch-fail/github-runner-then-fallback/releases) for tags.

## Usage

```yaml
jobs:
  determine-runner:
    runs-on: ubuntu-latest
    concurrency:
      group: runner-determination
      cancel-in-progress: false
    outputs:
      runner: ${{ steps.set-runner.outputs.use-runner }}
    steps:
      - id: set-runner
        uses: hutch-fail/github-runner-then-fallback@v1
        with:
          primary-runner: ubuntu-latest
          fallback-runner: blacksmith-2vcpu-ubuntu-2404
          included-minutes: ${{ vars.ACTIONS_INCLUDED_MINUTES }}
          github-token: ${{ secrets.ORG_BILLING_TOKEN }}
          organization: hutch-fail
          fallback-on-error: "true"

  build:
    needs: determine-runner
    runs-on: ${{ fromJson(needs.determine-runner.outputs.runner) }}
    steps:
      - uses: actions/checkout@v4
      # …
```

### Inputs

| Input | Required | Description |
| --- | --- | --- |
| `primary-runner` | yes | Labels while under budget (e.g. `ubuntu-latest`) |
| `fallback-runner` | yes | Labels when budget exhausted (e.g. `blacksmith-2vcpu-ubuntu-2404`) |
| `included-minutes` | yes | Included/free Linux Actions minutes for the period |
| `github-token` | yes | Billing-capable token (not `GITHUB_TOKEN`) |
| `organization` | no | Org login; defaults to `GITHUB_REPOSITORY` owner |
| `fallback-on-error` | no | Default `true` — use fallback if the billing check fails |

### Output

| Output | Description |
| --- | --- |
| `use-runner` | JSON string of labels for `fromJson` (same shape as mikehardy) |

### Secrets / variables consumers need

| Name | Kind | Purpose |
| --- | --- | --- |
| `ORG_BILLING_TOKEN` (name up to you) | **secret** | PAT/app token that can read org enhanced billing usage |
| `ACTIONS_INCLUDED_MINUTES` | **variable** | Included Linux Actions minutes (e.g. `2000`); passed as `included-minutes` |

## This repository’s CI

**Blacksmith-only** for local test CI (`ci.yml`). This repo does **not** dogfood the
prefer-GHA path (avoids burning free minutes and recursive `determine-runner`
while shipping the action).

### Release

Same thin caller as other `hutch-fail` repos — do not copy the implementation:

```yaml
# .github/workflows/release.yml
jobs:
  release:
    uses: hutch-fail/actions/.github/workflows/semantic-release.yml@v1.0.2
```

Push conventional commits to `main` (or `workflow_dispatch`) → GitHub Release tags
(`vX.Y.Z`). Prefer consuming pins like `@v1` / `@v1.0.2` over hand-rolled tags.

### Pre-commit

Org suite from [`hutch-fail/pre-commit`](https://github.com/hutch-fail/pre-commit)
(`id: platform`). After clone:

```bash
pre-commit install
pre-commit run --all-files
```

PR CI: thin `.github/workflows/pre-commit.yml` →
`hutch-fail/pre-commit/.github/workflows/pre-commit.yml@v0.1.4` (needs org
`GH_APP_ID` / `GH_APP_PRIVATE_KEY` secrets, same as other platform repos).

## License

MIT
