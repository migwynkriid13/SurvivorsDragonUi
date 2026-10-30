"""Regression fixtures for CI checks; no game, addon or Lua chunk is executed."""

from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import package
from check_runtime_hygiene import check_assets, check_lua_sources, compare_payload, parse_sources, zip_bytes
from pr_quality import DEAD_CODE_WARNINGS


def rules():
    return {"dynamic_roots": {}, "data_roots": {}, "families": [], "source_assets": {}, "reference_lua": {}}


class LuaSourceClassificationTests(unittest.TestCase):
    def test_legacy_references_and_test_tooling_do_not_require_toc_entries(self):
        policy = rules()
        policy["reference_lua"]["modules/chat/filters.lua"] = "Legacy formatter retained as reference; prettify.lua is live."
        tracked = {"core/live.lua", "modules/chat/filters.lua", "tests/layout_geometry.lua",
                   "scripts/tests/fixtures/ui_spec.lua", "scripts/reference/helper.lua"}
        failures = check_lua_sources({"core/live.lua"}, tracked, {"core/live.lua": {}}, policy)
        self.assertEqual(failures, [])

    def test_ordinary_unloaded_lua_still_fails(self):
        for name in ("modules/unloaded.lua", "core/unloaded.lua", "unexpected.lua"):
            with self.subTest(name=name):
                failures = check_lua_sources(set(), {name}, {}, rules())
                self.assertEqual(failures, [name + ": tracked addon Lua is not loaded by the TOC"])

    def test_development_and_reference_lua_cannot_enter_the_payload(self):
        for name in ("tests/layout_geometry.lua", "scripts/tests/fixtures/ui_spec.lua",
                     "scripts/helper.lua", "modules/chat/filters.lua"):
            with self.subTest(name=name):
                policy = rules()
                if name == "modules/chat/filters.lua":
                    policy["reference_lua"][name] = "Retained legacy source."
                failures = check_lua_sources({name}, {name}, {name: {}}, policy)
                self.assertTrue(any("must not be packaged" in row for row in failures))

    def test_reference_classifications_require_a_current_lua_file_and_reason(self):
        for name, tracked, reason in (
            ("modules/missing.lua", set(), "Missing source."),
            ("modules/legacy.txt", {"modules/legacy.txt"}, "Wrong type."),
            ("modules/legacy.lua", {"modules/legacy.lua"}, " "),
            ("modules/legacy.lua", {"modules/legacy.lua"}, {}),
        ):
            with self.subTest(name=name, reason=reason):
                policy = rules()
                policy["reference_lua"][name] = reason
                failures = check_lua_sources(set(), tracked, {}, policy)
                self.assertTrue(any("invalid reference-Lua classification" in row for row in failures))

    def test_a_reference_cannot_be_used_as_loaded_artwork_evidence(self):
        policy = rules()
        policy["reference_lua"]["modules/legacy.lua"] = "Retained legacy source."
        failures = check_lua_sources(set(), {"modules/legacy.lua"}, {"modules/legacy.lua": {}}, policy)
        self.assertTrue(any("must not be loaded as runtime source" in row for row in failures))


class AssetInventoryTests(unittest.TestCase):
    def scan(self, source, files, policy=None, tracked=None):
        inventory = parse_sources({"core/view.lua": source})
        return check_assets(set(files), set(files if tracked is None else tracked), inventory, policy or rules())

    def test_comments_cannot_keep_removed_artwork_alive(self):
        failures, _ = self.scan('-- "meter\\\\Old.blp"\n--[[ "meter\\\\Old.blp" ]]', ["media/tex/meter/Old.blp"])
        self.assertTrue(any("no reference" in row for row in failures))

    def test_bundled_font_requires_live_literal_evidence_and_exact_package_membership(self):
        font = "media/fonts/PT_Serif-Web-Regular.ttf"
        source = r'local face = root .. "media\\fonts\\PT_Serif-Web-Regular.ttf"; label:SetFont(face, 18, "OUTLINE")'
        failures, used = self.scan(source, [font])
        self.assertEqual(failures, [])
        self.assertTrue(used[font])
        failures, _ = self.scan(source, [])
        self.assertTrue(any("missing packaged font" in row for row in failures))
        failures, _ = self.scan('-- ' + source, [font])
        self.assertTrue(any("no reference" in row for row in failures))

    def test_native_paths_do_not_count_as_bundled_artwork(self):
        failures, _ = self.scan(r'icon:SetTexture("Interface\\Icons\\Spell_Test.blp")', [])
        self.assertEqual(failures, [])

    def test_broken_reference_and_unreferenced_asset_both_fail(self):
        failures, _ = self.scan(r'icon:SetTexture(root .. "meter\\Missing.blp")', ["media/tex/meter/Old.blp"])
        self.assertTrue(any("missing packaged texture" in row for row in failures))
        self.assertTrue(any("no reference" in row for row in failures))

    def test_exact_case_is_required(self):
        failures, _ = self.scan(r'icon:SetTexture(root .. "meter\\bar.blp")', ["media/tex/meter/Bar.blp"])
        self.assertTrue(any("missing packaged texture" in row for row in failures))

    def test_dynamic_sheet_does_not_keep_same_named_other_sheet_alive(self):
        policy = rules()
        policy["dynamic_roots"] = {"core/view.lua": "meter"}
        failures, used = self.scan(
            r'local path = root .. "meter\\"; Texture(frame, "Header"); local other = root .. "guardians\\"',
            ["media/tex/meter/Header.blp", "media/tex/guardians/Header.blp"], policy,
        )
        self.assertTrue(used["media/tex/meter/Header.blp"])
        self.assertFalse(used["media/tex/guardians/Header.blp"])
        self.assertEqual(len(failures), 1)

    def test_only_loaded_lua_can_own_artwork(self):
        failures, _ = self.scan('', [], tracked=["modules/retired.lua"])
        self.assertTrue(any("not loaded by the TOC" in row for row in failures))

    def test_reference_and_test_sources_do_not_keep_unused_artwork_alive(self):
        policy = rules()
        policy["reference_lua"]["modules/chat/filters.lua"] = "Retained legacy formatter."
        texture = "media/tex/meter/Old.blp"
        failures, used = self.scan('', [texture], policy,
                                   tracked=[texture, "modules/chat/filters.lua", "tests/layout_geometry.lua"])
        self.assertEqual(len(failures), 1)
        self.assertIn("no reference in loaded Lua", failures[0])
        self.assertEqual(used[texture], [])

    def test_authoring_input_is_retained_but_extra_binary_is_rejected(self):
        failures, _ = self.scan(
            r'icon:SetTexture(root .. "meter\\Bar.blp")', ["media/tex/meter/Bar.blp"],
            tracked=["media/tex/meter/Bar.tga", "media/tex/meter/Bar.blp", "media/tex/meter/extra.png"],
        )
        self.assertEqual(len(failures), 1)
        self.assertIn("extra.png", failures[0])

    def test_stale_preparation_exception_fails(self):
        policy = rules()
        policy["source_assets"]["media/old.png"] = {"output": "media/tex/old.blp", "reason": "Original"}
        failures, _ = self.scan('', [], policy)
        self.assertTrue(any("Stale preparation-source" in row for row in failures))

    def test_dynamic_family_requires_live_caller_and_helper(self):
        policy = rules()
        policy["families"] = [{
            "source": "core/view.lua", "call": "DFRL.tools.Style", "helper": "core/helper.lua",
            "definition": "DFRL.tools.Style", "root": "minimap", "stems": ["Zoom"], "suffixes": ["-over.blp"],
        }]
        files = {"media/tex/minimap/Zoom-over.blp"}
        inventory = parse_sources({
            "core/view.lua": 'local name = "Zoom"; T.Style(button, name)',
            "core/helper.lua": r'function DFRL.tools.Style() local root = "minimap\\"; local suffix = "-over.blp" end',
        })
        failures, _ = check_assets(files, files, inventory, policy)
        self.assertEqual(failures, [])
        inventory["core/view.lua"]["calls"] = []
        failures, _ = check_assets(files, files, inventory, policy)
        self.assertTrue(any("Stale dynamic texture family" in row for row in failures))

    def test_member_inventory_keeps_dynamic_table_reads(self):
        data = parse_sources({"fixture.lua": 'local item = DFRL.styles[index]; T.Paint(item)'})["fixture.lua"]
        names = {row["name"] for row in data["reads"]}
        self.assertIn("DFRL.styles", names)
        self.assertIn("DFRL.tools.Paint", names)

    def test_invalid_lua_reports_its_source_without_executing_it(self):
        with self.assertRaises(subprocess.CalledProcessError) as raised:
            parse_sources({"broken.lua": "local ="})
        self.assertIn("broken.lua", raised.exception.stderr)


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.manifest = self.root / "runtime-files.json"
        self.toc = "SurvivorsDragonUi.toc"
        (self.root / self.toc).write_text("core\\view.lua\n", encoding="utf-8")
        (self.root / "core").mkdir()
        (self.root / "core/view.lua").write_text("-- fixture\n", encoding="utf-8")
        self.files = [self.toc, "core/view.lua"]
        for attribute, value in (("SOURCE", self.root), ("MANIFEST", self.manifest)):
            patcher = patch.object(package, attribute, value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def inspect(self, files=None):
        self.manifest.write_text(json.dumps({"format_version": 1, "files": self.files if files is None else files}), encoding="utf-8")
        return package.runtime_files()

    def test_toc_and_manifest_must_match(self):
        self.assertEqual(self.inspect(), sorted(self.files))
        with self.assertRaisesRegex(ValueError, "match the TOC"):
            self.inspect([self.toc])

    def test_duplicate_and_unsafe_paths_fail(self):
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            self.inspect(self.files + [self.files[1]])
        for path in ("../outside.blp", "/outside.blp", "core\\view.lua", "C:/outside.blp"):
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "Invalid runtime manifest path"):
                self.inspect(self.files + [path])

    def test_missing_files_and_duplicate_toc_entries_fail(self):
        with self.assertRaises(FileNotFoundError):
            self.inspect(self.files + ["missing.blp"])
        (self.root / self.toc).write_text("core\\view.lua\ncore\\view.lua\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Duplicate Lua entry"):
            self.inspect()

    def test_case_collisions_and_symlinks_fail(self):
        with self.assertRaisesRegex(ValueError, "Case-colliding"):
            self.inspect(self.files + ["Core/other.lua"])
        (self.root / "alias.lua").symlink_to(self.root / "core/view.lua")
        with self.assertRaisesRegex(ValueError, "symlinks"):
            self.inspect(self.files + ["alias.lua"])

    def test_zip_is_deterministic_and_has_only_the_reviewed_payload(self):
        payload = {"core/view.lua": b"-- fixture\n", "media/tex/a.blp": b"art", "media/fonts/face.ttf": b"font"}
        self.assertEqual(zip_bytes(payload), zip_bytes(dict(reversed(list(payload.items())))))
        with zipfile.ZipFile(io.BytesIO(zip_bytes(payload))) as archive:
            self.assertEqual(set(archive.namelist()), {"SurvivorsDragonUi/" + name for name in payload})
            for name, data in payload.items():
                self.assertEqual(archive.read("SurvivorsDragonUi/" + name), data)

    def test_real_packager_excludes_files_outside_the_fixture_manifest(self):
        self.inspect()
        (self.root / "unused.tga").write_bytes(b"authoring input")
        output = self.root / "fixture.zip"
        with patch.object(sys, "argv", ["package.py", str(output)]), redirect_stdout(io.StringIO()):
            package.main()
        with zipfile.ZipFile(output) as archive:
            self.assertEqual(set(archive.namelist()), {"SurvivorsDragonUi/" + name for name in self.files})

    def test_new_identical_copy_fails_but_existing_group_is_reported(self):
        previous = {"a.blp": b"pixels", "b.blp": b"pixels"}
        failures, report = compare_payload(previous, previous)
        self.assertEqual(failures, [])
        self.assertTrue(report["identical_runtime_files"])
        failures, _ = compare_payload(previous | {"c.blp": b"pixels"}, previous)
        self.assertEqual(len(failures), 1)
        failures, _ = compare_payload(previous | {"c.blp": b"other"}, previous)
        self.assertEqual(failures, [])

    def test_new_identical_font_copy_fails(self):
        previous = {"media/fonts/face.ttf": b"font"}
        failures, _ = compare_payload(previous | {"media/fonts/copy.ttf": b"font"}, previous)
        self.assertEqual(len(failures), 1)

    def test_removed_and_changed_files_are_in_size_report(self):
        _, report = compare_payload({"keep.lua": b"larger"}, {"keep.lua": b"x", "old.blp": b"old"})
        deltas = {row["file"]: row["delta"] for row in report["changed_files"]}
        self.assertEqual(deltas, {"keep.lua": 5, "old.blp": -3})


class DeadCodePolicyTests(unittest.TestCase):
    def check(self, source):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "fixture.lua"
            path.write_text(source, encoding="utf-8")
            return subprocess.run([
                "luacheck", "--no-config", "--no-default-config", "--no-cache", "--no-color", "--codes",
                "--std", "lua51", "--no-unused-secondaries", "--only", *DEAD_CODE_WARNINGS, "--", str(path),
            ], text=True, capture_output=True)

    def test_unused_local_and_overwritten_value_fail(self):
        for source, code in (("local abandoned = 42", "211"), ("local value = 1; value = 2; print(value)", "311")):
            with self.subTest(code=code):
                result = self.check(source)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn(code, result.stdout)

    def test_native_callback_argument_can_remain_unused(self):
        result = self.check("local function OnEvent(self, event) print(event) end; Register(OnEvent)")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
