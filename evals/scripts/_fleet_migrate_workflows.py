#!/usr/bin/env python3
"""Migrate consumer workflows: eval-ci/pre-commit pins + secrets.GH_APP_* → OP."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

OP_LOAD = """\
      - name: Load GitHub App credentials from 1Password
        id: op
        uses: 1password/load-secrets-action@v5
        with:
          export-env: false
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
          GH_APP_ID: op://hutch.fail users/hutch-fail-platform-github/GH_APP_ID
          GH_APP_INSTALLATION_ID: op://hutch.fail users/hutch-fail-platform-github/GH_APP_INSTALLATION_ID
          GH_APP_PRIVATE_KEY: op://hutch.fail users/hutch-fail-platform-github/hutch-fail-platform-github.private-key.pem

"""

EVALS_HOOK = """
  - repo: local
    hooks:
      - id: evals-pre-commit
        name: evals — apply scoped bars for changed paths
        entry: bash evals/scripts/pre-commit-evals.sh
        language: system
        pass_filenames: true
"""

SECRETS_PAIR = re.compile(
    r"(?m)^(?P<i>\s*)GH_APP_ID:\s*\$\{\{\s*secrets\.GH_APP_ID\s*\}\}\s*\n"
    r"(?P=i)GH_APP_PRIVATE_KEY:\s*\$\{\{\s*secrets\.GH_APP_PRIVATE_KEY\s*\}\}\s*\n"
)
SECRETS_PAIR_REV = re.compile(
    r"(?m)^(?P<i>\s*)GH_APP_PRIVATE_KEY:\s*\$\{\{\s*secrets\.GH_APP_PRIVATE_KEY\s*\}\}\s*\n"
    r"(?P=i)GH_APP_ID:\s*\$\{\{\s*secrets\.GH_APP_ID\s*\}\}\s*\n"
)
SECRET_DECL = re.compile(
    r"(?m)^(?P<i>\s*)GH_APP_ID:\n"
    r"(?P=i)  description:.*\n"
    r"(?P=i)  required:.*\n"
    r"(?P=i)GH_APP_PRIVATE_KEY:\n"
    r"(?P=i)  description:.*\n"
    r"(?P=i)  required:.*\n"
)


def replace_secret_pairs(text: str) -> str:
    def repl(m: re.Match[str]) -> str:
        return f"{m.group('i')}OP_SERVICE_ACCOUNT_TOKEN: ${{{{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}}}\n"

    text = SECRETS_PAIR.sub(repl, text)
    text = SECRETS_PAIR_REV.sub(repl, text)
    return text


def replace_secret_decls(text: str) -> str:
    def repl(m: re.Match[str]) -> str:
        i = m.group("i")
        return (
            f"{i}OP_SERVICE_ACCOUNT_TOKEN:\n"
            f"{i}  description: 1Password service account token "
            f"(vault hutch.fail users / item hutch-fail-platform-github)\n"
            f"{i}  required: true\n"
        )

    return SECRET_DECL.sub(repl, text)


def migrate_eval_ci(text: str, hub_sha: str) -> str:
    text = re.sub(
        r"(hutch-fail/evals/\.github/workflows/eval-ci\.yml@)[^\s]+",
        rf"\g<1>{hub_sha}",
        text,
    )
    text = re.sub(r"(^\s+hub_ref:\s*)[^\s]+", rf"\g<1>{hub_sha}", text, flags=re.M)
    text = replace_secret_pairs(text)
    text = text.replace(
        "Pass GH_APP_* (same org App as pre-commit)",
        "Pass OP_SERVICE_ACCOUNT_TOKEN (1Password → App credentials)",
    )
    text = text.replace("Pass GH_APP_ID + GH_APP_PRIVATE_KEY", "Pass OP_SERVICE_ACCOUNT_TOKEN")
    return text


def migrate_pre_commit_caller(text: str, pc_tag: str) -> str:
    text = re.sub(
        r"(hutch-fail/pre-commit/\.github/workflows/pre-commit\.yml@)[^\s]+",
        rf"\g<1>{pc_tag}",
        text,
    )
    return replace_secret_pairs(text)


def migrate_inline_mint(text: str) -> str:
    if "secrets.GH_APP_ID" not in text and "secrets.GH_APP_PRIVATE_KEY" not in text:
        text = replace_secret_decls(text)
        return replace_secret_pairs(text)

    text = text.replace(
        "app-id: ${{ secrets.GH_APP_ID }}",
        "app-id: ${{ steps.op.outputs.GH_APP_ID }}",
    )
    text = text.replace(
        "private-key: ${{ secrets.GH_APP_PRIVATE_KEY }}",
        "private-key: ${{ steps.op.outputs.GH_APP_PRIVATE_KEY }}",
    )

    needle = (
        "app-id: ${{ steps.op.outputs.GH_APP_ID }}\n"
        "          private-key: ${{ steps.op.outputs.GH_APP_PRIVATE_KEY }}"
    )
    repl = (
        "app-id: ${{ steps.op.outputs.GH_APP_ID }}\n"
        "          installation-id: ${{ steps.op.outputs.GH_APP_INSTALLATION_ID }}\n"
        "          private-key: ${{ steps.op.outputs.GH_APP_PRIVATE_KEY }}"
    )
    if "installation-id: ${{ steps.op.outputs.GH_APP_INSTALLATION_ID }}" not in text:
        text = text.replace(needle, repl)

    lines = text.splitlines(keepends=True)
    # Find step start indices (lines beginning with "      - ")
    step_starts = [i for i, ln in enumerate(lines) if re.match(r"^      - ", ln)]
    step_starts.append(len(lines))

    inject_at: set[int] = set()
    for s, e in zip(step_starts, step_starts[1:]):
        block = "".join(lines[s:e])
        if "uses: actions/create-github-app-token" not in block:
            continue
        if "steps.op.outputs.GH_APP_ID" not in block:
            continue
        # Look backward within the same job for an existing id: op step
        # Job boundary: line matching "^  name:" at 2-space indent
        job_start = 0
        for j in range(s, -1, -1):
            if re.match(r"^  [a-zA-Z0-9_-]+:\s*$", lines[j]):
                job_start = j
                break
        prior = "".join(lines[job_start:s])
        if "id: op" in prior or "1password/load-secrets-action" in prior:
            continue
        inject_at.add(s)

    out: list[str] = []
    for i, ln in enumerate(lines):
        if i in inject_at:
            out.append(OP_LOAD)
        out.append(ln)
    text = "".join(out)

    text = replace_secret_decls(text)
    text = replace_secret_pairs(text)
    return text


def ensure_precommit_config(path: Path, pc_tag: str) -> None:
    pc = path / ".pre-commit-config.yaml"
    if not pc.exists():
        return
    text = pc.read_text()
    text2 = re.sub(
        r"(repo: https://github.com/hutch-fail/pre-commit\n\s+rev:\s*)\S+",
        rf"\g<1>{pc_tag}",
        text,
    )
    if "evals-pre-commit" not in text2 and (path / "evals" / "scripts" / "pre-commit-evals.sh").exists():
        if not text2.endswith("\n"):
            text2 += "\n"
        text2 += EVALS_HOOK
    if text2 != text:
        pc.write_text(text2)
        print(f"updated {pc.relative_to(path)}")


def still_forbidden(text: str) -> bool:
    return bool(
        re.search(r"secrets\.GH_APP_ID|secrets\.GH_APP_PRIVATE_KEY", text)
        or re.search(r"(?m)^\s+GH_APP_ID:\s*$", text)
        or re.search(r"(?m)^\s+GH_APP_PRIVATE_KEY:\s*$", text)
    )


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--hub-sha", required=True)
    ap.add_argument("--pre-commit-tag", default="v0.1.5")
    args = ap.parse_args()
    root = Path(args.root)

    wf_dir = root / ".github" / "workflows"
    if wf_dir.is_dir():
        for f in sorted(wf_dir.glob("*.y*ml")):
            raw = f.read_text()
            new = raw
            if "hutch-fail/evals/.github/workflows/eval-ci.yml@" in raw or f.name == "eval-ci.yml":
                new = migrate_eval_ci(new, args.hub_sha)
            if (
                "hutch-fail/pre-commit/.github/workflows/pre-commit.yml@" in raw
                or f.name == "pre-commit.yml"
            ):
                new = migrate_pre_commit_caller(new, args.pre_commit_tag)
            new = migrate_inline_mint(new)
            if new != raw:
                f.write_text(new)
                print(f"migrated {f.relative_to(root)}")
            if still_forbidden(new):
                print(f"WARN still-forbidden patterns in {f.relative_to(root)}")

    ensure_precommit_config(root, args.pre_commit_tag)
    print(f"done {root.name}")


if __name__ == "__main__":
    main()
