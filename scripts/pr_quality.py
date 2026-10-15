"""Read-only PR formatting and local dead-code checks, run only in GitHub CI.

Only changed files are checked, not the unchanged legacy baseline. No Lua file
is loaded or executed. Reports and suggested formatting patches go to dist/.
"""

import difflib
import json
import os
from pathlib import Path
import re
import subprocess
import sys


REPORTS = Path("dist/pr-quality")
MANIFEST = REPORTS / "changed-files.json"
PRETTIER_SUFFIXES = {".json", ".md", ".markdown", ".yaml", ".yml"}
DEAD_CODE_WARNINGS = ("211", "213", "231", "241", "311", "331", "511", "512")


def git(*arguments):
    return subprocess.check_output(["git", *arguments])


def collect():
    base = os.environ["PR_BASE_SHA"]
    head = os.environ["PR_HEAD_SHA"]
    for revision in (base, head):
        if not re.fullmatch(r"[0-9a-fA-F]{40}", revision):
            raise ValueError("Expected a complete Git SHA from PR metadata")
    ancestor = git("merge-base", base, head).decode().strip()
    changed = git(
        "diff", "--name-only", "--diff-filter=ACMR", "--no-renames", "-z",
        ancestor, head, "--",
    ).decode().split("\0")
    root = Path.cwd().resolve()
    files = {"lua": [], "prettier": []}
    for name in changed:
        if not name:
            continue
        path = Path(name)
        if path.is_symlink() or root not in path.resolve().parents:
            raise ValueError("Refusing a symlink or path outside the checkout")
        if not path.is_file():
            continue
        if path.suffix.lower() == ".lua":
            files["lua"].append(name)
        elif path.suffix.lower() in PRETTIER_SUFFIXES:
            files["prettier"].append(name)
    REPORTS.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(files, indent=2) + "\n", encoding="utf-8")
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        for kind, names in files.items():
            output.write(f"{kind}_count={len(names)}\n")
    print(json.dumps(files, indent=2))
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
        summary.write(
            "## PR code quality\n\n"
            f"Checking {len(files['lua'])} changed Lua file(s) and "
            f"{len(files['prettier'])} changed Markdown/JSON/YAML file(s).\n\n"
            "Checks cover whole changed files; untouched legacy files are excluded. "
            "Existing formatting in a file may need updating when it is first touched. "
            "No addon or game code is executed.\n\n"
            "Dead-code analysis covers unused locals/loop variables, unused local "
            "assignments and unreachable or single-iteration loops. It does not prove "
            "that dynamically registered globals, callbacks or assets are unused. "
            "Unused callback arguments and dynamic WoW/DFRL globals are excluded.\n"
        )


def run(command, **kwargs):
    return subprocess.run(command, text=True, capture_output=True, **kwargs)


def prettier(files):
    patches = []
    messages = []
    failed = False
    binary = os.environ["PR_PRETTIER"]
    for name in files:
        original = Path(name).read_bytes().decode("utf-8")
        result = run(
            [binary, "--config", ".prettierrc.json", "--no-editorconfig",
             "--ignore-path", "/dev/null", "--stdin-filepath", name],
            input=original,
        )
        if result.returncode:
            failed = True
            messages.append(f"{name}: Prettier failed\n{result.stderr}")
        elif original != result.stdout:
            failed = True
            messages.append(f"{name}: formatting changes required")
            patches.extend(difflib.unified_diff(
                original.splitlines(keepends=True),
                result.stdout.splitlines(keepends=True),
                fromfile="a/" + name, tofile="b/" + name,
            ))
        else:
            messages.append(f"{name}: formatting OK")
    (REPORTS / "prettier.patch").write_text("".join(patches), encoding="utf-8")
    (REPORTS / "prettier.log").write_text("\n".join(messages) + "\n", encoding="utf-8")
    print("\n".join(messages))
    if patches:
        print("".join(patches))
    return failed


def lua_format(files):
    reports = []
    failed = False
    for name in files:
        result = run([
            "stylua", "--check", "--output-format=unified",
            "--config-path", ".stylua.toml", "--", name,
        ])
        failed = failed or result.returncode != 0
        reports.append(result.stdout + result.stderr)
    report = "".join(reports)
    (REPORTS / "stylua.patch").write_text(report, encoding="utf-8")
    print(report or "All changed Lua files use the configured formatting.")
    return failed


def dead_code(files):
    reports = []
    failed = False
    for name in files:
        result = run([
            "luacheck", "--no-config", "--no-default-config", "--no-cache",
            "--no-color", "--codes", "--formatter", "plain", "--std", "lua51",
            "--no-unused-secondaries", "--only", *DEAD_CODE_WARNINGS, "--", name,
        ])
        failed = failed or result.returncode != 0
        reports.append(result.stdout + result.stderr)
    report = "".join(reports)
    (REPORTS / "dead-code.log").write_text(report, encoding="utf-8")
    print(report or "No configured local dead-code warnings in changed Lua files.")
    return failed


def main():
    operation = sys.argv[1]
    if operation == "collect":
        collect()
        return 0
    files = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if operation == "prettier":
        return int(prettier(files["prettier"]))
    if operation == "lua-format":
        return int(lua_format(files["lua"]))
    if operation == "dead-code":
        return int(dead_code(files["lua"]))
    raise ValueError("Unknown quality-check operation")


if __name__ == "__main__":
    sys.exit(main())
