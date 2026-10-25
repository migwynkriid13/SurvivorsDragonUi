#!/usr/bin/env python3
"""Build an updater version once, then reuse its exact published DLL bytes."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = "migwynkriid13/SurvivorsDragonUi"


def version():
    value = (ROOT / "updater/VERSION").read_text(encoding="ascii").strip()
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", value):
        raise ValueError("Expected an explicit updater major.minor.patch version")
    return value


def source_digest():
    updater = ROOT / "updater"
    paths = [updater / name for name in ("VERSION", "CMakeLists.txt", "resources.rc.in", "version.hpp.in")]
    paths += [path for folder in ("src", "third_party") for path in (updater / folder).rglob("*") if path.is_file()]
    digest = hashlib.sha256()
    for path in sorted(paths):
        if path.is_symlink():
            raise ValueError("Updater build inputs must not be links")
        digest.update(path.relative_to(updater).as_posix().encode() + b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def identity(dll, commit):
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Expected the complete updater source commit")
    return {
        "schema": 1,
        "version": version(),
        "source_commit": commit,
        "source_sha256": source_digest(),
        "dll_sha256": hashlib.sha256(dll.read_bytes()).hexdigest(),
    }


def verify(dll, metadata):
    if metadata.get("schema") != 1 or metadata.get("version") != version():
        raise ValueError("Wrong frozen updater version")
    if not re.fullmatch(r"[0-9a-f]{40}", metadata.get("source_commit", "")):
        raise ValueError("Missing frozen updater source commit")
    if metadata.get("source_sha256") != source_digest():
        raise ValueError("Published updater sources differ; bump updater/VERSION explicitly before replacing its binary")
    if metadata.get("dll_sha256") != hashlib.sha256(dll.read_bytes()).hexdigest():
        raise ValueError("Frozen updater DLL SHA-256 mismatch")


def gh(*arguments, check=True):
    return subprocess.run(["gh", *arguments], capture_output=True, text=True, check=check)


def prepare(dist):
    tag = "updater-v" + version()
    result = gh("api", "repos/" + REPOSITORY + "/releases/tags/" + tag, check=False)
    if result.returncode:
        if "HTTP 404" not in result.stderr:
            raise RuntimeError("Cannot inspect the frozen updater release: " + result.stderr)
        reference = gh("api", "repos/" + REPOSITORY + "/git/ref/tags/" + tag, check=False)
        if not reference.returncode:
            raise ValueError("Updater tag already exists without its release; restore the frozen artifact instead of rebuilding")
        if "HTTP 404" not in reference.stderr:
            raise RuntimeError("Cannot inspect the updater tag: " + reference.stderr)
        return True
    release = json.loads(result.stdout)
    if release.get("draft"):
        raise ValueError("The updater version has an unfinished draft; do not replace its assets automatically")
    dist.mkdir(parents=True, exist_ok=True)
    gh("release", "download", tag, "--repo", REPOSITORY, "--dir", str(dist),
       "--pattern", "avrt.dll", "--pattern", "updater-binary.json")
    verify(dist / "avrt.dll", json.loads((dist / "updater-binary.json").read_text(encoding="utf-8")))
    return False


def record(dist, commit):
    metadata = identity(dist / "avrt.dll", commit)
    path = dist / "updater-binary.json"
    path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    return path


def publish(dist, commit):
    shutil.copy2(dist / "updater-build/Release/avrt.dll", dist / "avrt.dll")
    metadata = record(dist, commit)
    tag = "updater-v" + version()
    gh("release", "create", tag, str(dist / "avrt.dll"), str(metadata),
       "--repo", REPOSITORY, "--target", commit, "--draft", "--latest=false",
       "--title", "Optional addon updater " + version(),
       "--notes", "Frozen Windows x64 addon updater. Addon releases reuse this exact avrt.dll and verify its SHA-256. The addon ZIP is published separately in addon releases.")
    gh("release", "edit", tag, "--repo", REPOSITORY, "--draft=false", "--latest=false")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("prepare", "publish", "record"))
    parser.add_argument("--dist", type=Path, default=Path("dist"))
    parser.add_argument("--commit", default=os.environ.get("BUILD_SHA"))
    arguments = parser.parse_args()
    if arguments.mode == "prepare":
        build = prepare(arguments.dist)
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
            output.write("needs_build=" + str(build).lower() + "\n")
            output.write("reused=" + str(not build).lower() + "\n")
        print("First publication: build this updater version." if build else "Reusing the exact frozen updater DLL.")
    elif arguments.mode == "record":
        record(arguments.dist, arguments.commit)
    else:
        publish(arguments.dist, arguments.commit)


if __name__ == "__main__":
    main()
