#!/usr/bin/env python3
"""Describe the exact addon ZIP consumed by the optional Windows updater."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from package import ADDON_DIRECTORY, SOURCE, runtime_files


def build_manifest(archive, commit):
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Expected a full lowercase release commit")
    expected = runtime_files()
    with zipfile.ZipFile(archive) as package:
        names = [ADDON_DIRECTORY + "/" + name for name in expected]
        if sorted(package.namelist()) != sorted(names):
            raise ValueError("ZIP must contain exactly the shared runtime manifest")
        files = []
        for name in expected:
            data = package.read(ADDON_DIRECTORY + "/" + name)
            if data != (SOURCE / name).read_bytes():
                raise ValueError("ZIP differs from the release source: " + name)
            files.append({"path": name, "size": len(data), "sha256": hashlib.sha256(data).hexdigest()})
    toc = (SOURCE / (ADDON_DIRECTORY + ".toc")).read_text(encoding="utf-8-sig")
    versions = re.findall(r"^## Version:\s*([^\r\n]+)", toc, re.MULTILINE)
    if len(versions) != 1:
        raise ValueError("Expected one TOC version")
    data = archive.read_bytes()
    return {
        "schema": 1,
        "repository": "migwynkriid13/SurvivorsDragonUi",
        "tag": "build-" + commit,
        "version": versions[0],
        "archive": {"size": len(data), "sha256": hashlib.sha256(data).hexdigest()},
        "files": files,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("commit")
    parser.add_argument("--dll", type=Path, required=True)
    arguments = parser.parse_args()
    archive = arguments.archive
    manifest = archive.parent / "updater-manifest.json"
    manifest.write_text(json.dumps(build_manifest(archive, arguments.commit), indent=2) + "\n", encoding="utf-8")
    artifacts = (archive, arguments.dll, manifest, archive.parent / "updater-binary.json")
    (archive.parent / "SHA256SUMS.txt").write_text(
        "".join(hashlib.sha256(path.read_bytes()).hexdigest() + "  " + path.name + "\n" for path in artifacts),
        encoding="ascii",
    )


if __name__ == "__main__":
    main()
