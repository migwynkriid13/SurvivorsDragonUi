#!/usr/bin/env python3
"""Write versioned release notes and print the release title."""

from pathlib import Path
import argparse
import json


def main():
    source = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("commit")
    parser.add_argument("output")
    parser.add_argument("--manifest", type=Path, default=source / "dist/updater-manifest.json")
    arguments = parser.parse_args()
    manifest = json.loads(arguments.manifest.read_text(encoding="utf-8"))
    if manifest["tag"] != "build-" + arguments.commit:
        raise ValueError("Release notes must describe the packaged commit")
    version = manifest["version"].removesuffix("-survivors")
    title = "SurvivorsDragonUi " + version
    readme = (source / "README.md").read_text(encoding="utf-8")
    instructions = readme.split("## Install\n", 1)[1].split("\n## ", 1)[0].strip()
    output = Path(arguments.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        "Addon package for **" + title + "**.\n\n"
        + "## Install\n\n" + instructions + "\n",
        encoding="utf-8",
    )
    print(title)


if __name__ == "__main__":
    main()
