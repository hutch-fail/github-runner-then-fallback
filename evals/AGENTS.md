## Learned User Preferences

- Prefer skills that do one atomic piece of work, composed by orchestrators
  (e.g. `meta-dev` → `goal-author` / `goal-develop`|`goal-solve` / `goal-judge`)
  rather than monolithic skill bodies.
- This repository is the **templates, processes, scripts, and skills** for
  architecting, designing, and running goals (`harness/`, `goal*` / `meta-dev`
  skills, schema). A behavior change here is still eval work. Doing only the
  implementation that turns checks green is forbidden. If a goal already covers
  the claim, run it.
- Prefer a personal/process eval workspace under host `~/.hermes/evals`
  (often bind-mounted into each project as `evals_process/`) for scratch and
  cross-repo process goals; harness + `make eval/...` stay in this hub (or
  `make -C evals` from a host). New process goals live at
  `evals_process/goals/github.com/<slug>/<repo>/YYYYMMDD-<kebab>.md`
  (date-prefix required). Agents with only product-repo context: start at
  `evals_process/PROCESS.md`.
- When a claim should persist with a product, land **in-repo** eval packs under
  that repository’s own `evals/` (+ `docs/goals/` when that project uses the
  NNN-MM convention)—not only under `~/.hermes/evals`.
- Meta (agent-eval / agent-improvement) work goes through `meta-dev` →
  `goal-author` → `goal-develop`|`goal-solve` → `goal-judge` (Cursor rule
  `.cursor/rules/meta-dev.mdc`); never weaken evals or adopt tools without a
  green judge verdict.
- The pre-run report is the goal markdown file, not a chat recap. The example is
  `goals/github.com/hermes/hermes/20260918-graft-mini-svc-ab.md` (Cursor rule
  `.cursor/rules/goal-spec.mdc`). After the run, write `<goal>-result.md` beside
  the goal. Commit that result in a later local commit, not in the same
  `git commit` as the goal or the fixture. Both commits may be in one pull
  request. If the claim is that an agent used a tool, the check starts that
  agent in the runtime under test. A config file, a throwaway projector run, or
  a library script is not that agent.

## Learned Workspace Facts

- Skills SoT is `skills/`; host editors use tracked relative adapters in
  `.cursor/skills/` and `.agents/skills/`. Host projects that sync/subtree this
  hub at `evals/` should run `evals/scripts/install-host-adapters.sh` once.
  Org-wide harvest/redistribute: `docs/syncing.md` (`make sync/list|harvest|pull|doctor`).
- Process evals SoT is host `~/.hermes/evals` (`EVALS_ROOT` /
  `HERMES_EVALS_ROOT`). Leaf name **`evals_process`** avoids colliding with a
  product’s tracked **`evals/`** (often this hub as a git subtree).
- Dynamic agent-solver (TB2a): `make eval/solve` / skill **goal-solve** runs a
  goal’s `solver_bin` (coding-agent CLIs or a fixture mock `.sh`) in a fixture
  copy, then the same F2P/P2P shell checks; the harness does not call LLM
  provider APIs or require API keys. Soft trajectory/rubric LLM judges remain
  deferred.
