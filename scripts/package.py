#!/usr/bin/env python3
"""Package the installable addon without executing Lua or launching the game."""

from pathlib import Path
import argparse
import json
import zipfile


SOURCE = Path(__file__).resolve().parents[1]
MANIFEST = SOURCE / "packaging/runtime-files.json"
ADDON_DIRECTORY = "SurvivorsDragonUi"


def runtime_files():
    """Return the reviewed package inputs used by releases and release gating."""
    with MANIFEST.open(encoding="utf-8") as handle:
        manifest = json.load(handle)
    if manifest.get("format_version") != 1:
        raise ValueError("Unsupported runtime manifest format")

    files = manifest["files"]
    if not isinstance(files, list) or not all(isinstance(name, str) for name in files):
        raise ValueError("Runtime manifest files must be a list of paths")
    if len(files) != len(set(files)):
        raise ValueError("Duplicate file in runtime manifest")
    portable_paths = {}
    for name in files:
        path = Path(name)
        if path.is_absolute() or ".." in path.parts or path.as_posix() != name or "\\" in name or ":" in name:
            raise ValueError("Invalid runtime manifest path: " + name)
        for prefix in (path, *path.parents):
            label = prefix.as_posix()
            previous = portable_paths.setdefault(label.casefold(), label)
            if previous != label:
                raise ValueError("Case-colliding runtime paths: " + previous + " and " + label)
        source_file = SOURCE / path
        if source_file.resolve(strict=True) != source_file:
            raise ValueError("Runtime manifest paths must not contain symlinks: " + name)
        if not source_file.is_file():
            raise ValueError("Runtime manifest entry is not a file: " + name)

    toc_name = ADDON_DIRECTORY + ".toc"
    if toc_name not in files:
        raise ValueError("Runtime manifest must include " + toc_name)
    toc_lua = []
    for line in (SOURCE / toc_name).read_text(encoding="utf-8-sig").splitlines():
        entry = line.strip()
        if not entry or entry.startswith("#"):
            continue
        entry = entry.replace("\\", "/")
        if not entry.endswith(".lua"):
            raise ValueError("Unexpected non-Lua TOC entry: " + entry)
        toc_lua.append(entry)
    if len(toc_lua) != len(set(toc_lua)):
        raise ValueError("Duplicate Lua entry in the TOC")
    packaged_lua = {name for name in files if name.endswith(".lua")}
    if packaged_lua != set(toc_lua):
        raise ValueError(
            "Runtime manifest Lua must match the TOC exactly; missing="
            + repr(sorted(set(toc_lua) - packaged_lua))
            + "; unloaded="
            + repr(sorted(packaged_lua - set(toc_lua)))
        )
    return sorted(files)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", nargs="?", default="dist/SurvivorsDragonUi.zip")
    parser.add_argument(
        "--list",
        action="store_true",
        help="List exactly the repository paths included in the ZIP, without packaging",
    )
    arguments = parser.parse_args()
    files = runtime_files()
    if arguments.list:
        print("\n".join(files))
        return

    output = Path(arguments.output).expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for relative in files:
            archive.write(SOURCE / relative, arcname=ADDON_DIRECTORY + "/" + relative)

    print(str(output))
    print(str(output.stat().st_size) + " bytes")


if __name__ == "__main__":
    main()
