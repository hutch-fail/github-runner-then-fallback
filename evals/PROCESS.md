# Process evals

This file ships inside the shared `evals` hub (org **file sync** primary; git
**subtree** or volume **mount** also fine). It is the agent-facing process guide.

| Path in a product workspace | What it is | Commit to the product repo? |
| --- | --- | --- |
| `evals/` (sync / subtree / mount) | Shared harness, skills, templates, methodology + product claim packs | **Yes** for product goals/fixtures under `evals/goals/github.com/<org>/<repo>/` (harvest to hub for org SoT — [`docs/syncing.md`](docs/syncing.md)) |
| `evals_process/` (optional bind) | Host scratch SoT (`~/.hermes/evals`) | **No** (gitignored) |

This hub owns `make eval/…`, `harness/`, and `skills/`. From a host project:

```bash
make -C evals eval/assert-red GOAL=…
# after sync/subtree/mount, once:
bash evals/scripts/install-host-adapters.sh
```

## Pre-run report

The pre-run report **is** the goal file, not a recap. Copy
`evals/templates/goal.md` and keep the same headings. After the run, write
`<goal>-result.md` beside the goal. A green check with no result file is not
done. Commit the result in a later local commit, not with the goal or fixture.
Both commits may be in one pull request. Squash or merge may combine them.

If the claim is that an agent used a tool, the check starts that agent in the
runtime under test. A config file, a throwaway projector run, or a library
script is not that agent.

## Where to put a new product goal

Mirror the GitHub org/repo leaf you are editing:

```text
goals/github.com/<org>/<repo>/YYYYMMDD-<kebab>.md
fixtures/github.com/<org>/<repo>/YYYYMMDD-<kebab>/
```

**Date-prefix required** (`YYYYMMDD-`). Do not invent flat names at
`goals/<name>.md` for product work (smoke goals like `fixture-token-echo` are
the exception).

### Example

```text
evals/
├── PROCESS.md
├── goals/github.com/<org>/<repo>/YYYYMMDD-<kebab>.md
└── fixtures/github.com/<org>/<repo>/YYYYMMDD-<kebab>/
    ├── check.sh
    └── p2p-smoke.sh
```

```yaml
id: YYYYMMDD-<org>-<repo>-<kebab>
fixture_dir: evals/fixtures/github.com/<org>/<repo>/YYYYMMDD-<kebab>
```

```bash
make -C evals eval/assert-red GOAL=github.com/<org>/<repo>/YYYYMMDD-<kebab>
```

### Other org examples

| Workspace | Goal path under `evals/goals/` |
| --- | --- |
| HockeyMind | `github.com/hockeymind/hockeymind/YYYYMMDD-…` |
| Hermes | `github.com/hermes/hermes/YYYYMMDD-…` |
| Function-Health app | `github.com/function-health/applications/<app>/YYYYMMDD-…` |

## Distribution

- **Subtree (primary):** vendor this hub into `<product>/evals/`. Product PRs
  carry harness/skill updates (when pulled) and product goals.
- **Volume mount:** mount the shared hub at `evals/`; still commit durable
  product packs into the product repo’s tracked tree when the bar should ship.
- **Personal SoT:** leave scratch under `~/.hermes/evals` / `evals_process/`;
  do not treat it as the long-term home for product bars.

See [`docs/consuming.md`](docs/consuming.md).

## Harness commands

```bash
# hub root
make eval/assert-red GOAL=github.com/<org>/<repo>/YYYYMMDD-<kebab>
make eval/report GOAL=github.com/<org>/<repo>/YYYYMMDD-<kebab>

# host
make -C evals eval/assert-red GOAL=github.com/<org>/<repo>/YYYYMMDD-<kebab>
EVALS_ROOT=/path/to/evals bash evals/harness/goal.sh assert-red …
```

Author from `evals/templates/goal.md` before the run. Never weaken checks to
force green.

## Outcome vs check (soft)

Harness green means the **written criteria** passed — not every sentence under
User outcome. Prefer that meaningful outcome bullets either map to a Success
criteria row (observable) or sit honestly under Limitations / Scope “Not
covered.” Ambient README hope (“local login form works”) without either is easy
to misread as proven.

When a pack asserts one environment enables a mode (e.g. Boat trusted-header
SSO), consider whether the opposite mode matters for the claim (e.g. local
without that mode). A sibling criterion or an explicit Limitations line is
usually enough; not every dual-mode needs a second pack.

### Live proof levels (soft)

Ad-hoc live curls in a PR test plan are outside harness judge. When you do live
V&V, prefer matching the level to the outcome you care about — not only the
cheapest green:

| Level | Roughly | Example |
| --- | --- | --- |
| L0 | Process listens / document GET | `curl` → HTTP 200 HTML |
| L1 | Product mode / config shape | API or inspect shows auth mode, feature flags |
| L2 | Interactive path | Signup/login or equivalent happy path |

“UI loads” for an auth-gated surface often wants at least L1. L0 alone is fine
when the claim is truly “something answers on that Host.” Avoid treating L0 as
Done for outcomes that need a mode or session unless Limitations says so.

## Skills

Use hub skills: `goal-author` → `goal-develop`|`goal-solve` → `goal-judge`,
orchestrator `meta-dev`, CLI shim `goal`. Host projects: run
`evals/scripts/install-host-adapters.sh` so editors discover them.
