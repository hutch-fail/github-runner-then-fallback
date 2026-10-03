# github-runner-then-fallback

Prefer **GitHub-hosted** runners while included/free Actions minutes remain, then fall back to another label (typically **Blacksmith**).

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

Example consumer shape (same structure as upstream’s README):

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
```

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

Decision:

1. Read current-period `actions_linux` `grossQuantity` from the usage **summary** API
2. If `used < included-minutes` → emit **primary**
3. Else → emit **fallback**

Token must be a **classic** PAT owned by an org owner or billing manager, with `admin:org`. Enhanced billing **usage** APIs do **not** support fine-grained PATs. Default `GITHUB_TOKEN` is **not** enough.

## Pin

```yaml
uses: hutch-fail/github-runner-then-fallback@v1
# or: uses: hutch-fail/github-runner-then-fallback@<full-sha>
```

See [Releases](https://github.com/hutch-fail/github-runner-then-fallback/releases).

## Inputs

| Input | Required | Description |
| --- | --- | --- |
| `primary-runner` | yes | Labels while under budget (e.g. `ubuntu-latest`) |
| `fallback-runner` | yes | Labels when budget exhausted (e.g. `blacksmith-2vcpu-ubuntu-2404`) |
| `included-minutes` | yes | Included/free Linux Actions minutes for the period |
| `github-token` | yes | Billing-capable token (not `GITHUB_TOKEN`) |
| `organization` | no | Org login; defaults to `GITHUB_REPOSITORY` owner |
| `fallback-on-error` | no | Default `true` — use fallback if the billing check fails |

## Output

| Output | Description |
| --- | --- |
| `use-runner` | JSON string of labels for `fromJson` (same shape as mikehardy/runner-fallback-action) |

## Secrets / variables consumers need

| Name | Kind | Purpose |
| --- | --- | --- |
| `ORG_BILLING_TOKEN` (name up to you) | **secret** | Token that can read org enhanced billing usage |
| `ACTIONS_INCLUDED_MINUTES` | **variable** | Included Linux Actions minutes (e.g. `2000`); passed as `included-minutes` |

## This repository’s CI

**Blacksmith-only** for local test CI (`ci.yml`). This repo does **not** dogfood the prefer-GHA path (avoids burning free minutes and recursive `determine-runner` while shipping the action).

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
