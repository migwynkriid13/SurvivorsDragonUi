"""Gate releases on changes to the addon payload or optional updater."""

import json
import os
import re
import subprocess

from package import MANIFEST, SOURCE, runtime_files


def updater_changed(changed):
    return any(
        name.startswith("updater/") or name in {
            ".github/workflows/release.yml", "scripts/package.py", "scripts/release_changes.py"
        }
        for name in changed
    )


def git(*arguments):
    return subprocess.check_output(["git", *arguments], cwd=SOURCE)


def payload_changes(current, previous, changed):
    """Describe shipped-file and membership changes for releases and PR versions."""
    current, previous, changed = set(current), set(previous), set(changed)
    return {
        "changed_payload_files": sorted(changed & (current | previous)),
        "payload_membership_changes": sorted(current ^ previous),
    }


def payload_changed():
    current = set(runtime_files())
    if os.environ["EVENT_NAME"] == "workflow_dispatch":
        print("Manual main-branch package requested.")
        return True

    head = os.environ["HEAD_SHA"]
    before = os.environ.get("BEFORE_SHA", "")
    if not re.fullmatch(r"[0-9a-fA-F]{40}", head):
        raise ValueError("Expected a complete pushed Git SHA")
    if not before or set(before) == {"0"}:
        print("Initial runtime payload.")
        return True
    if not re.fullmatch(r"[0-9a-fA-F]{40}", before):
        raise ValueError("Expected a complete previous Git SHA")
    git("cat-file", "-e", before + "^{commit}")

    relative_manifest = MANIFEST.relative_to(SOURCE).as_posix()
    previous_file = subprocess.run(
        ["git", "show", before + ":" + relative_manifest],
        cwd=SOURCE, capture_output=True, text=True,
    )
    if previous_file.returncode:
        print("Introducing the explicit runtime-only package.")
        return True
    previous = set(json.loads(previous_file.stdout)["files"])
    changed = set(git("diff", "--name-only", "--no-renames", "-z", before, head, "--").decode().split("\0"))
    changed.discard("")
    changes = payload_changes(current, previous, changed)
    print(json.dumps(changes, indent=2))
    return any(changes.values()) or updater_changed(changed)


def main():
    changed = payload_changed()
    value = "true" if changed else "false"
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        output.write("payload_changed=" + value + "\n")
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
        summary.write(
            "## Release payload\n\n"
            + ("Addon or updater changed; building the ZIP and separate optional DLL.\n" if changed else
               "No addon or updater changes; release skipped.\n")
        )


if __name__ == "__main__":
    main()
