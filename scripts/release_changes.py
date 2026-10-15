"""Gate release packaging on changes to the manifest's actual ZIP payload."""

import json
import os
import re
import subprocess

from package import MANIFEST, SOURCE, runtime_files


def git(*arguments):
    return subprocess.check_output(["git", *arguments], cwd=SOURCE)


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
    included_changes = sorted(changed & (current | previous))
    membership_changes = sorted(current ^ previous)
    print(json.dumps({
        "changed_payload_files": included_changes,
        "payload_membership_changes": membership_changes,
    }, indent=2))
    return bool(included_changes or membership_changes)


def main():
    changed = payload_changed()
    value = "true" if changed else "false"
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        output.write("payload_changed=" + value + "\n")
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
        summary.write(
            "## Release payload\n\n"
            + ("The installable payload changed; building one ZIP.\n" if changed else
               "No packaged file or payload membership changed; ZIP and release skipped.\n")
        )


if __name__ == "__main__":
    main()
