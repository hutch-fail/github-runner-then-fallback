---
schema: goal/v1
id: YYYYMMDD-short-name
title: One line a person can read
fixture_dir: evals/fixtures/github.com/<slug>/<repo>/YYYYMMDD-short-name
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
# Optional scope keys: see goals/_schema.md (scope / languages / repos)
---

Write this before any run. Say what decision the result is allowed to support.

# Decision

What a pass lets us do. What a pass does not let us do.

# User outcome

What should be better for the person using the system.

Prefer that each meaningful bullet either shows up as a Success criteria row
(observable) or is called out under Limitations / Scope “Not covered.” Prose
alone is easy to treat as proven when it is not. Wiggle room is fine for
aspirational color — just do not lean on it when closing “works for the user.”

# Scope

| Covered | Not covered |
| --- | --- |
| The cases this test includes | The cases this test leaves out |

# Success criteria

One row per thing we can observe. Do not combine two requirements on one row.

| Criterion | What we look at |
| --- | --- |
|  |  |

When this pack turns a mode **on** for one environment (Boat, Access, etc.),
consider whether the claim also needs the mode **off** (or different) elsewhere.
A second row or a Limitations line is usually enough; skip when out of scope.

# Dataset

Where the cases come from, how many, and which cases we hold back.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
|  | A program check, a person, or a model | What evidence that grader can actually see |

Use a program check when the outcome is directly visible. Use a person or a model only when a program cannot tell.

If the claim is that an agent used a tool, the check starts that agent and reads what it did. Name each agent on its own row. A config file, a projector writing into a throwaway directory, or a library script is not that agent. One agent does not stand in for the others. Inside Hermes, those agents are the ones in the Incus guest.

# Acceptance gates

| Question | Pass | Fail |
| --- | --- | --- |
|  |  |  |

Set these limits before looking at results.

# Execution

How many tries, which model, time limit, and whether a failed try is repeated.

# Limitations

What a pass would still leave unproven.

If live V&V is how you close an outcome the static bar does not cover, prefer
naming that gap here and matching live proof to the outcome (listen/HTML vs
config/mode vs interactive) — see `PROCESS.md` “Live proof levels (soft).”

# Result file

After the run, write `<same-folder>/<same-name>-result.md` beside this goal. The filled example is `evals/goals/github.com/hermes/hermes/20260918-graft-mini-svc-ab-result.md`. Copy `evals/templates/result.md`. A green check with no result file beside the goal is not done. The copy under `evals/runs/` is not that file. Commit the result in a later local commit, not with this goal or its fixture. Both commits may be in one pull request. Squash or merge may combine them.
