"""Read-only PR version, formatting and local dead-code checks for GitHub CI.

Every tracked Lua source and owned Markdown/JSON/YAML file is checked on every
PR push. No Lua file is loaded or executed. Reports and suggested formatting
patches go to dist/.
"""

import difflib
import html
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import quote

from package import MANIFEST as RUNTIME_MANIFEST, SOURCE, runtime_files
from release_changes import payload_changes


REPORTS = Path("dist/pr-quality")
MANIFEST = REPORTS / "source-files.json"
PRETTIER_SUFFIXES = {".json", ".md", ".markdown", ".yaml", ".yml"}
# Keep the owner's supplied API reference verbatim and upstream attribution
# untouched. These exclusions do not omit any addon Lua sources.
VERBATIM_TEXT = {
    "docs/AzerothSurvivors-Addon-API.md",
    "third_party/WidgetStatusBar-SOURCE.md",
}
DEAD_CODE_WARNINGS = ("211", "213", "231", "241", "311", "331", "511", "512")


def git(*arguments):
    return subprocess.check_output(["git", *arguments])


def collect():
    tracked = git("ls-files", "--cached", "-z").decode().split("\0")
    root = Path.cwd().resolve()
    files = {"lua": [], "prettier": []}
    for name in tracked:
        if not name:
            continue
        path = Path(name)
        if path.is_symlink() or root not in path.resolve().parents:
            raise ValueError("Refusing a symlink or path outside the checkout")
        if not path.is_file():
            continue
        if path.suffix.lower() == ".lua":
            files["lua"].append(name)
        elif path.suffix.lower() in PRETTIER_SUFFIXES and name not in VERBATIM_TEXT:
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
            f"Checking all {len(files['lua'])} tracked Lua file(s) and "
            f"{len(files['prettier'])} owned Markdown/JSON/YAML file(s).\n\n"
            "The complete codebase is checked on every PR push, including unchanged "
            "files. No addon or game code is executed.\n\n"
            "Formatting preserves the verbatim API reference "
            "`docs/AzerothSurvivors-Addon-API.md` and upstream attribution "
            "`third_party/WidgetStatusBar-SOURCE.md` without rewriting them.\n\n"
            "Dead-code analysis covers unused locals/loop variables, unused local "
            "assignments and unreachable or single-iteration loops. It does not prove "
            "that dynamically registered globals, callbacks or assets are unused. "
            "Unused callback arguments and dynamic WoW/DFRL globals are excluded.\n"
        )


def run(command, **kwargs):
    return subprocess.run(command, text=True, capture_output=True, **kwargs)


def toc_version():
    """Compare PR metadata with the current target branch, without running Lua."""
    toc = "SurvivorsDragonUi.toc"

    def version(text):
        text = "\n".join(text.splitlines())
        values = re.findall(r"^##[ \t]*Version[ \t]*:[ \t]*([^\r\n]*)$", text, re.MULTILINE)
        if len(values) != 1:
            raise ValueError(toc + " must have exactly one Version header")
        value = values[0].strip()
        match = re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-survivors", value)
        if not match:
            raise ValueError("Expected major.minor.patch-survivors, got " + repr(value))
        return tuple(int(part) for part in match.groups()), value

    try:
        repository = os.environ["GITHUB_REPOSITORY"]
        branch = os.environ["PR_BASE_REF"]
        commit_endpoint = "repos/" + repository + "/commits/" + quote(branch, safe="")

        def base_head():
            return json.loads(run(["gh", "api", commit_endpoint], check=True).stdout)["sha"]

        base_sha = base_head()
        merge_base = git("merge-base", base_sha, "HEAD").decode().strip()
        manifest_path = RUNTIME_MANIFEST.relative_to(SOURCE).as_posix()
        previous_files = json.loads(git("show", merge_base + ":" + manifest_path))["files"]
        changed = git("diff", "--name-only", "--no-renames", "-z", merge_base, "HEAD", "--").decode().split("\0")
        changes = payload_changes(runtime_files(), previous_files, (name for name in changed if name))
        report = json.dumps(changes, indent=2) + "\n"
        if any(changes.values()):
            previous, previous_label = version(git("show", base_sha + ":" + toc).decode("utf-8-sig"))
            current, current_label = version(Path(toc).read_text(encoding="utf-8-sig"))
            if current <= previous:
                raise ValueError(
                    "PR version " + current_label + " must be higher than " + branch + " version "
                    + previous_label + ". Bump the TOC once per payload-changing PR; default to the next patch version."
                )
            report += "Passed: " + previous_label + " -> " + current_label + " (" + branch + " at " + base_sha + ")\n"
        else:
            report += "No ZIP payload changes; no TOC version bump required.\n"
        if base_head() != base_sha:
            raise ValueError("The target branch changed during the version check; rerun against its latest version")
        failed = False
    except (KeyError, OSError, ValueError, subprocess.CalledProcessError) as error:
        report = "TOC version check failed: " + str(error) + "\n"
        failed = True
    REPORTS.mkdir(parents=True, exist_ok=True)
    (REPORTS / "version.log").write_text(report, encoding="utf-8")
    print(report, end="")
    return failed


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
    messages = []
    failed = False
    for name in files:
        result = run([
            "stylua", "--check", "--output-format=unified",
            "--config-path", ".stylua.toml", "--", name,
        ])
        failed = failed or result.returncode != 0
        reports.append(result.stdout.replace(
            "--- old\n+++ new\n", f"--- a/{name}\n+++ b/{name}\n", 1,
        ))
        messages.append(f"{name}: StyLua exit {result.returncode}\n{result.stderr}")
    report = "".join(reports)
    (REPORTS / "stylua.patch").write_text(report, encoding="utf-8")
    (REPORTS / "stylua.log").write_text("\n".join(messages), encoding="utf-8")
    print("\n".join(messages))
    print(report or "All tracked Lua files use the configured formatting.")
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
    print(report or "No configured local dead-code warnings in tracked Lua files.")
    return failed


def summary():
    checks = (
        ("TOC version increment", "VERSION_OUTCOME"),
        ("Markdown / JSON / YAML formatting", "PRETTIER_OUTCOME"),
        ("Lua formatting", "STYLUA_OUTCOME"),
        ("Local Lua dead code", "DEADCODE_OUTCOME"),
    )
    statuses = {
        "success": "Passed",
        "failure": "Failed",
        "skipped": "Skipped",
        "cancelled": "Cancelled",
    }
    sections = [
        "## Combined quality results\n\n",
        "| Check | Result |\n| --- | --- |\n",
    ]
    for label, variable in checks:
        status = statuses.get(os.environ.get(variable, ""), "Not completed")
        sections.append(f"| {label} | {status} |\n")
    sections.append(
        "\nAll configured checks report before the final result is enforced. "
        "A skipped or incomplete check can indicate a setup failure; inspect its "
        "workflow step. No addon or game code is executed.\n\n"
        "Logs and suggested formatting patches are collected below. "
        "Download the `pr-quality` artifact for the full reports if a section "
        "is truncated.\n\n"
    )
    report_files = (
        ("version.log", "No version diagnostics emitted."),
        ("prettier.log", "No formatting diagnostics emitted."),
        ("stylua.log", "No formatting diagnostics emitted."),
        ("dead-code.log", "No configured dead-code warnings emitted."),
        ("prettier.patch", "No formatting differences."),
        ("stylua.patch", "No formatting differences."),
    )
    # Six sections at <=120 KiB each plus fixed headings stay below 800 KiB,
    # leaving ample space below GitHub's 1 MiB per-step summary limit.
    section_limit = 120 * 1024
    for name, empty_message in report_files:
        path = REPORTS / name
        content = (
            path.read_text(encoding="utf-8", errors="replace") or empty_message
            if path.is_file()
            else "Report not produced. Inspect the setup and check steps."
        )
        escaped = html.escape(content, quote=False).encode("utf-8")
        truncated = len(escaped) > section_limit
        if truncated:
            escaped = escaped[:section_limit]
        displayed = escaped.decode("utf-8", errors="ignore")
        if truncated:
            # Do not leave a partially written HTML entity at the cutoff.
            ampersand = displayed.rfind("&")
            if ampersand > displayed.rfind(";"):
                displayed = displayed[:ampersand]
            displayed += "\n[Truncated here; full content is in the artifact.]"
        sections.append(
            f"<details>\n<summary>{name}</summary>\n\n"
            f"<pre>{displayed}</pre>\n</details>\n\n"
        )
    report = "".join(sections)
    REPORTS.mkdir(parents=True, exist_ok=True)
    (REPORTS / "summary.md").write_text(report, encoding="utf-8")
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as output:
        output.write(report)
    print("Combined quality report written to the job summary and artifact.")


def main():
    operation = sys.argv[1]
    if operation == "collect":
        collect()
        return 0
    if operation == "summary":
        summary()
        return 0
    if operation == "toc-version":
        return int(toc_version())
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
