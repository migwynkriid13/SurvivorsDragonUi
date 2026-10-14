#!/usr/bin/env python3
"""Package the installable addon without executing Lua or launching the game."""

from pathlib import Path
import argparse
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", nargs="?", default="dist/SurvivorsDragonUi.zip")
    arguments = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    output = Path(arguments.output).expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    files = [source / name for name in ("SurvivorsDragonUi.toc", "README.md", "LICENSE")]
    for directory in ("core", "modules", "media", "third_party", "docs"):
        files.extend(
            path for path in (source / directory).rglob("*")
            if path.is_file() and not any(part.startswith(".") for part in path.relative_to(source).parts)
        )

    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(files):
            relative = path.relative_to(source).as_posix()
            archive.write(path, arcname="SurvivorsDragonUi/" + relative)

    print(str(output))
    print(str(output.stat().st_size) + " bytes")


if __name__ == "__main__":
    main()
