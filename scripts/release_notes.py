#!/usr/bin/env python3
"""Write release installation notes from the README's install section."""

from pathlib import Path
import argparse


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("commit")
    parser.add_argument("output")
    arguments = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    readme = (source / "README.md").read_text(encoding="utf-8")
    instructions = readme.split("## Install\n", 1)[1].split("\n## ", 1)[0].strip()
    output = Path(arguments.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        "Addon package for commit `" + arguments.commit + "`.\n\n"
        + "## Install\n\n" + instructions + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
