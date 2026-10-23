#!/usr/bin/env python3
from __future__ import annotations
import os, sys
from pathlib import Path
ROOT = Path(os.environ.get("HERMES_EVAL_REPO_ROOT") or Path.cwd())
PRE_COMMIT = "77030147a25b824e38a5854e1377a3bb28deb750"
EVALS = "eb8be6cdcc36461f658253d485f391e80a8137ce"
ACTIONS = "5904d8f1b618a48659e75b059f984d6cd1feddd0"
FILES = [
    ".github/workflows/pre-commit.yml",
    ".github/workflows/eval-ci.yml"
]
def main() -> int:
    errs = []
    for rel in FILES:
        p = ROOT / rel
        if not p.exists():
            errs.append(f"missing {rel}"); continue
        t = p.read_text()
        if "pre-commit.yml@" in t and f"pre-commit.yml@{PRE_COMMIT}" not in t:
            errs.append(f"{rel}: pre-commit pin not {PRE_COMMIT}")
        if "eval-ci.yml@" in t:
            if f"eval-ci.yml@{EVALS}" not in t:
                errs.append(f"{rel}: eval-ci uses pin not {EVALS}")
            if "hub_ref:" in t and f"hub_ref: {EVALS}" not in t:
                errs.append(f"{rel}: hub_ref not {EVALS}")
        if "semantic-release.yml@" in t and f"semantic-release.yml@{ACTIONS}" not in t:
            errs.append(f"{rel}: semantic-release pin not {ACTIONS}")
        if "ORG_BILLING_TOKEN" in t and "BLACKSMITH_API_TOKEN" not in t:
            errs.append(f"{rel}: missing BLACKSMITH_API_TOKEN")
    if errs:
        print("\n".join(f"error: {e}" for e in errs), file=sys.stderr); return 1
    print("thin_caller_hub_wrapper_pins_ok"); return 0
if __name__ == "__main__":
    raise SystemExit(main())
