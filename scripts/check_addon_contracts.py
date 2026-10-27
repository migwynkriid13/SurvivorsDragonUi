"""CI source contracts and orphan regressions; no addon Lua executes here."""

import json
import os
import re
import subprocess
import sys

from package import SOURCE, runtime_files
from check_runtime_hygiene import REPORTS, git


def analyze(sources, captions):
    result = subprocess.run(
        ["node", str(SOURCE / "scripts/addon_contracts.cjs")],
        input=json.dumps({"sources": sources, "captions": captions}),
        text=True, capture_output=True, check=True,
    )
    return json.loads(result.stdout)


def caption_keys(tsv):
    return [line.split("\t", 1)[0] for line in tsv.splitlines() if line and not line.startswith("#")]


def orphan_regressions(current, previous):
    failures = []
    for field, description in (("unusedSettings", "setting without a recognized reader"),
                               ("unusedCaptions", "caption without a loaded-source literal")):
        for name in sorted(set(current[field]) - set(previous[field])):
            failures.append(f"Newly orphaned {description}: {name}")
    return failures


def main():
    REPORTS.mkdir(parents=True, exist_ok=True)
    failures = []
    try:
        sources = {name: (SOURCE / name).read_text(encoding="utf-8")
                   for name in runtime_files() if name.endswith(".lua")}
        current = analyze(sources, caption_keys((SOURCE / "localization/ui.tsv").read_text(encoding="utf-8")))
        failures.extend(current["failures"])
        base_sha = os.environ["PR_BASE_SHA"]
        if not re.fullmatch(r"[0-9a-f]{40}", base_sha):
            raise ValueError("PR_BASE_SHA must be the PR event's full base SHA")
        base = git("merge-base", base_sha, "HEAD").decode().strip()
        manifest = json.loads(git("show", base + ":packaging/runtime-files.json"))
        before_sources = {name: git("show", base + ":" + name).decode("utf-8")
                          for name in manifest["files"] if name.endswith(".lua")}
        previous = analyze(before_sources, caption_keys(git("show", base + ":localization/ui.tsv").decode("utf-8")))
        failures.extend(orphan_regressions(current, previous))
        current["base_commit"] = base
        current["new_orphans"] = orphan_regressions(current, previous)
        (REPORTS / "addon-contracts.json").write_text(json.dumps(current, indent=2) + "\n", encoding="utf-8")
        report = (
            "## Addon source contracts\n\n"
            f"Settings without recognized readers: {len(current['unusedSettings'])}. "
            f"Captions without literal references: {len(current['unusedCaptions'])}. "
            f"Dynamic references for review: {len(current['dynamic'])}.\n\n"
            "All candidates and source references are in addon-contracts.json. New orphan candidates "
            "fail against the PR merge base; existing candidates remain visible. Duplicate table/registration "
            "keys, settings/normalization mismatches, unknown shared APIs and broken concrete callbacks fail outright. "
            "Dynamic expressions are conservative source evidence, not execution-path or native-API proof.\n\n"
        )
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        detail = error.stderr if isinstance(error, subprocess.CalledProcessError) and error.stderr else str(error)
        failures.append(str(detail))
        report = "## Addon source contracts\n\nSource inventory could not complete.\n\n"
    report += "\n".join("- " + failure for failure in failures) if failures else "Passed source contracts and orphan regression checks."
    report += "\n"
    (REPORTS / "addon-contracts.log").write_text(report, encoding="utf-8")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as output:
            output.write(report)
    print(report)
    return bool(failures)


if __name__ == "__main__":
    sys.exit(main())
