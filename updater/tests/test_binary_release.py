"""CI-only proof that addon releases reuse an immutable DLL rather than rebuild it."""

import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import binary_release as binary


class BinaryReleaseTests(unittest.TestCase):
    def test_first_publication_requests_one_build(self):
        missing = SimpleNamespace(returncode=1, stdout="", stderr="gh: Not Found (HTTP 404)")
        with tempfile.TemporaryDirectory() as directory, patch.object(binary, "gh", return_value=missing) as gh:
            self.assertTrue(binary.prepare(Path(directory)))
            self.assertEqual(gh.call_count, 2)

    def test_missing_release_with_existing_version_tag_refuses_rebuild(self):
        missing = SimpleNamespace(returncode=1, stdout="", stderr="HTTP 404")
        existing_tag = SimpleNamespace(returncode=0, stdout="{}", stderr="")
        with tempfile.TemporaryDirectory() as directory, patch.object(binary, "gh", side_effect=[missing, existing_tag]):
            with self.assertRaisesRegex(ValueError, "restore the frozen artifact"):
                binary.prepare(Path(directory))

    def test_existing_version_reuses_exact_dll_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            dist = Path(directory)
            original = b"one frozen updater binary"
            dll = dist / "avrt.dll"
            dll.write_bytes(original)
            metadata = binary.identity(dll, "a" * 40)
            dll.unlink()

            def gh(*arguments, **kwargs):
                if arguments[0] == "api":
                    return SimpleNamespace(returncode=0, stdout=json.dumps({"draft": False}))
                self.assertEqual(arguments[:2], ("release", "download"))
                dll.write_bytes(original)
                (dist / "updater-binary.json").write_text(json.dumps(metadata), encoding="utf-8")
                return SimpleNamespace(returncode=0)

            with patch.object(binary, "gh", side_effect=gh):
                self.assertFalse(binary.prepare(dist))
            self.assertEqual(dll.read_bytes(), original)

    def test_source_or_binary_changes_fail_without_automatic_rebuild(self):
        with tempfile.TemporaryDirectory() as directory:
            dll = Path(directory) / "avrt.dll"
            dll.write_bytes(b"frozen")
            metadata = binary.identity(dll, "a" * 40)
            dll.write_bytes(b"different bytes")
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                binary.verify(dll, metadata)
            dll.write_bytes(b"frozen")
            metadata["source_sha256"] = "0" * 64
            with self.assertRaisesRegex(ValueError, "bump updater/VERSION"):
                binary.verify(dll, metadata)

    def test_drafts_and_service_errors_do_not_trigger_rebuild(self):
        unavailable = SimpleNamespace(returncode=1, stdout="", stderr="HTTP 503")
        draft = SimpleNamespace(returncode=0, stdout=json.dumps({"draft": True}))
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(binary, "gh", return_value=unavailable):
                with self.assertRaises(RuntimeError):
                    binary.prepare(Path(directory))
            with patch.object(binary, "gh", return_value=draft):
                with self.assertRaises(ValueError):
                    binary.prepare(Path(directory))


if __name__ == "__main__":
    unittest.main()
