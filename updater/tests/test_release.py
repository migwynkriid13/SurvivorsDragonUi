"""CI-only checks of the actual ZIP/manifest contract; never execute addon Lua."""

import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from package import runtime_files
from release_changes import payload_changes, updater_changed

spec = importlib.util.spec_from_file_location("release_manifest", ROOT / "updater/release_manifest.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def test_native_reader_installs_actual_release(self):
        subprocess.run([
            str(ROOT / "dist/updater-build/Release/UpdaterTests.exe"),
            "--release", str(ROOT / "dist"),
        ], check=True, timeout=60)

    def test_actual_release_contract(self):
        archive = ROOT / "dist/SurvivorsDragonUi.zip"
        manifest = json.loads((archive.parent / "updater-manifest.json").read_text())
        self.assertEqual(release.build_manifest(archive, manifest["tag"][6:]), manifest)
        self.assertEqual(manifest["archive"]["sha256"], hashlib.sha256(archive.read_bytes()).hexdigest())
        self.assertEqual([row["path"] for row in manifest["files"]], runtime_files())
        with zipfile.ZipFile(archive) as package:
            self.assertTrue(all(name.startswith("SurvivorsDragonUi/") for name in package.namelist()))
            self.assertFalse(any(name.endswith(".dll") or "/updater/" in name for name in package.namelist()))
        self.assertTrue((archive.parent / "avrt.dll").is_file())
        for line in (archive.parent / "SHA256SUMS.txt").read_text().splitlines():
            digest, name = line.split("  ", 1)
            self.assertEqual(digest, hashlib.sha256((archive.parent / name).read_bytes()).hexdigest())

    def test_reject_incomplete_or_extra_zip(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "incomplete.zip"
            with zipfile.ZipFile(archive, "w") as package:
                package.writestr("SurvivorsDragonUi/SurvivorsDragonUi.toc", "incomplete")
                package.writestr("OtherAddon/OtherAddon.toc", "unrelated")
            with self.assertRaises(ValueError):
                release.build_manifest(archive, "a" * 40)

    def test_updater_only_changes_release_without_toc_bump(self):
        current = runtime_files()
        changed = ["updater/src/update.cpp"]
        self.assertFalse(any(payload_changes(current, current, changed).values()))
        self.assertTrue(updater_changed(changed))
        self.assertTrue(updater_changed([".github/workflows/release.yml"]))
        self.assertFalse(updater_changed(["README.md"]))


if __name__ == "__main__":
    unittest.main()
