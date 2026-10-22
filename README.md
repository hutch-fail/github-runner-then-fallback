# github-runner-then-fallback

By default: use **GitHub-hosted** up to **80%** of included Actions minutes, then **Blacksmith** up to **80%** of its included minutes, then **usejoy** for overage. The determine-runner (detect) job itself runs on **GitHub-hosted** (`ubuntu-latest`) so metering does not depend on usejoy being online.

Pass `final-runner: ""` for the older two-way switch (GitHub until the full allowance, then Blacksmith).

## Credit and adaptation

This action is **adapted from** [mikehardy/runner-fallback-action](https://github.com/mikehardy/runner-fallback-action) by [Mike Hardy](https://github.com/mikehardy). That project (and its predecessors) deserve the credit for the workflow pattern we reuse.

Upstream lineage, as documented there:

- Pattern described by [@ianpurton](https://github.com/ianpurton) in [GitHub community discussion #20019](https://github.com/orgs/community/discussions/20019#discussioncomment-5414593)
- Original implementation by [@jimmygchen](https://github.com/jimmygchen) ([jimmygchen/runner-fallback-action](https://github.com/jimmygchen/runner-fallback-action); now archived)
- Successor maintained by Mike Hardy, with organization/enterprise runner support from [@O-Mutt](https://github.com/O-Mutt)

**This repository is not a fork** of mikehardy’s action. We kept the *shape* of the solution and replaced the *decision predicate* so it fits “burn free GitHub Actions minutes, then Blacksmith.”

### What we kept from mikehardy/runner-fallback-action

| Idea | Why it matters |
| --- | --- |
| Cheap `determine-runner` job | Chooses labels before expensive jobs start |
| `runs-on: ${{ fromJson(...) }}` | Label lists must be a JSON string for Actions |
| `use-runner` output | Same consumer contract as upstream |
| `primary-runner` / `fallback-runner` inputs | Familiar comma-separated label lists |
| `github-token` + optional `organization` | Org-scoped API checks |
| `fallback-on-error` | Prefer fallback over hard-failing CI when the check breaks |
| Serial `concurrency` group on determine-runner | Avoid racing parallel workflows when choice must be consistent |

### Recommended: reusable workflow (detect on GitHub-hosted)

Defaults: detect on `ubuntu-latest`; work jobs 80% GitHub (`2000`) → 80% Blacksmith (`3000`) → final `usejoy-2vcpu-ubuntu-2404`.

```yaml
jobs:
  determine-runner:
    uses: hutch-fail/github-runner-then-fallback/.github/workflows/determine-runner.yml@v1
    with:
      # Same ref as the uses: pin above (required for cross-repo callers).
      action-ref: v1
    secrets:
      ORG_BILLING_TOKEN: ${{ secrets.ORG_BILLING_TOKEN }}
      BLACKSMITH_API_TOKEN: ${{ secrets.BLACKSMITH_API_TOKEN }}

  build:
    needs: determine-runner
    runs-on: ${{ fromJson(needs.determine-runner.outputs.runner) }}
    steps:
      - uses: actions/checkout@v4
```

### Inline composite (same defaults)

Run the detect job on `ubuntu-latest`. Only `github-token` is required; pass `blacksmith-api-token` so the Blacksmith pool is metered.

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
          github-token: ${{ secrets.ORG_BILLING_TOKEN }}
          blacksmith-api-token: ${{ secrets.BLACKSMITH_API_TOKEN }}

  build:
    needs: determine-runner
    runs-on: ${{ fromJson(needs.determine-runner.outputs.runner) }}
    steps:
      - uses: actions/checkout@v4
```

Replace `usejoy-2vcpu-ubuntu-2404` if your usejoy install registers a different label. Opt out of chain with `final-runner: ""` (two-way GitHub→Blacksmith).

### What we changed

mikehardy’s predicate is: **are matching self-hosted primaries online (and optionally free)?** It calls the [self-hosted runners API](https://docs.github.com/en/rest/actions/self-hosted-runners).

That cannot implement “prefer `ubuntu-latest` until the free-minute budget is gone.” GitHub-hosted labels never appear in the self-hosted runners API, so swapping primary/fallback labels alone is not enough.

This action’s predicate is: **has the org used fewer Linux Actions minutes than a configured included budget?**

| | mikehardy/runner-fallback-action | this action |
| --- | --- | --- |
| Primary meaning | Self-hosted labels that must be online | GitHub-hosted labels while under budget |
| Fallback meaning | Public/other labels if primary offline/busy | Blacksmith (or other) when budget exhausted |
| API | List self-hosted runners | Org enhanced billing **usage summary** |
| Extra inputs | `primaries-required`, `enterprise`, … | `included-minutes` (required) |
| Typical token need | Org admin for runner list | Classic PAT with `admin:org` for billing usage |

If you need “use self-hosted when online, else GitHub-hosted,” use [mikehardy/runner-fallback-action](https://github.com/mikehardy/runner-fallback-action). Use this action when the switch is **quota-driven**, not **online-status-driven**.

## Billing: why `included-minutes` is an input

(Notes from hutch-fail, 2026-09, while GitHub enhanced billing was in place.)

| Endpoint | Result |
| --- | --- |
| `GET /orgs/{org}/settings/billing/actions` (legacy) | **410 Gone** — enhanced billing moved this API |
| `GET /orgs/{org}/settings/billing/usage` | **200** — daily SKU rows |
| `GET /organizations/{org_id}/settings/billing/usage/summary` | **200** — period totals; `actions_linux` has `grossQuantity` / `discountQuantity` / `netQuantity` |
| Budgets API (`…/settings/billing/budgets`) | **200** — dollar budgets only; no free-minutes remaining field |

There is **no API field for “included minutes remaining.”** Usage exposes minutes *used* (`grossQuantity` for `actions_linux`), not the plan allowance.

So consumers set the included/free budget explicitly (org plan allowance), typically via repository/org variable `ACTIONS_INCLUDED_MINUTES` (GitHub Free orgs: **2000** private-repo minutes/month).

Decision (**chain**, default — `final-runner` non-empty, `usage-threshold` = 80):

1. Read current-period `actions_linux` `grossQuantity`; if `used < included-minutes * 0.8` → emit **primary** (default included `2000`)
2. Else read Blacksmith billable minutes via CLI + org token; if under 80% of `blacksmith-included-minutes` (default `3000`) → emit **fallback**
3. Else → emit **final** (default usejoy). GitHub meter failure skips to Blacksmith; Blacksmith meter missing/failed emits final.

Decision (**two-way**, `final-runner: ""`):

1. Same GitHub meter; if `used < included-minutes` → **primary**
2. Else → **fallback**

Neither API returns minutes remaining. Allowances default in the action; override with inputs/vars when the plan differs.

GitHub token must be a **classic** PAT owned by an org owner or billing manager, with `admin:org`. Enhanced billing **usage** APIs do **not** support fine-grained PATs. Default `GITHUB_TOKEN` is **not** enough.

## Pin

```yaml
uses: hutch-fail/github-runner-then-fallback@v1
# or: uses: hutch-fail/github-runner-then-fallback@<full-sha>
```

See [Releases](https://github.com/hutch-fail/github-runner-then-fallback/releases).

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `github-token` | yes | — | Billing-capable token (not `GITHUB_TOKEN`) |
| `primary-runner` | no | `ubuntu-latest` | Labels while under GitHub headroom |
| `fallback-runner` | no | `blacksmith-2vcpu-ubuntu-2404` | Labels while under Blacksmith headroom |
| `final-runner` | no | `usejoy-2vcpu-ubuntu-2404` | Overage labels; `""` = two-way only |
| `included-minutes` | no | `2000` | GitHub Free included Linux minutes |
| `blacksmith-included-minutes` | no | `3000` | Blacksmith free minutes |
| `usage-threshold` | no | `80` | Percent of each allowance before leaving that pool |
| `blacksmith-api-token` | no | empty | Blacksmith org token; if empty, skip Blacksmith pool |
| `organization` | no | repo owner | Org login for billing usage |
| `fallback-on-error` | no | `true` | Last-resort runner if a required check fails |

## Output

| Output | Description |
| --- | --- |
| `use-runner` | JSON string of labels for `fromJson` (same shape as mikehardy/runner-fallback-action) |

## Secrets / variables consumers need

| Name | Kind | Purpose |
| --- | --- | --- |
| `ORG_BILLING_TOKEN` | **secret** (required) | Org enhanced billing usage |
| `BLACKSMITH_API_TOKEN` | **secret** (recommended) | Meter Blacksmith; without it, after GHA headroom → usejoy |
| `ACTIONS_INCLUDED_MINUTES` | **variable** (optional) | Override default `2000` |
| `BLACKSMITH_INCLUDED_MINUTES` | **variable** (optional) | Override default `3000` |

## This repository’s CI

**Pinned `ubuntu-latest`** for required test CI (`ci.yml`). The ship gate must not call `determine-runner` — a broken picker, missing usejoy, or billing failure must not block fixing the action.

Optional **non-blocking** smoke (`smoke-determine-runner.yml`) calls the reusable workflow with org secrets and logs the chosen labels (`continue-on-error`). Do not make that workflow a required status check.

### Release

Thin caller — implementation lives in `hutch-fail/actions`:

```yaml
# .github/workflows/release.yml
jobs:
  release:
    uses: hutch-fail/actions/.github/workflows/semantic-release.yml@v1.0.2
```

Push conventional commits to `main` (or `workflow_dispatch`) → GitHub Release tags (`vX.Y.Z`). Prefer `@v1` / `@v1.0.2` over hand-rolled tags.

### Pre-commit

Org suite from [`hutch-fail/pre-commit`](https://github.com/hutch-fail/pre-commit) (`id: platform`). After clone:

```bash
pre-commit install
pre-commit run --all-files
```

## License

MIT — same license family as the upstream action we adapted from. See [LICENSE](LICENSE).
