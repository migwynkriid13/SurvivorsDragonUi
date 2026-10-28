"""Synthetic mutation fixtures for source contracts; run in GitHub Actions."""

import json
from pathlib import Path
import subprocess
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from check_addon_contracts import analyze, orphan_regressions
from package import SOURCE


DISPLAY = '''
local display = {}
DFRL.display = display
local defaults = { enabled = true }
local ranges = {}
local function Normalize(source) return { enabled = Read(source, "enabled") } end
function display.Get(key) return defaults[key] end
function display.Set(key, value) end
'''


class SourceContractTests(unittest.TestCase):
    def scan(self, source, display=DISPLAY, captions=None):
        return analyze({"core/display.lua": display, "view.lua": source}, captions or [])

    def test_real_reader_keeps_a_setting_live_but_editor_write_does_not(self):
        result = self.scan('DFRL.display.Get("enabled")')
        self.assertEqual(result["failures"], [])
        self.assertEqual(result["unusedSettings"], [])
        result = self.scan('DFRL.display.Set("enabled", true)')
        self.assertEqual(result["unusedSettings"], ["enabled"])

    def test_comments_cannot_keep_settings_or_captions_alive(self):
        result = self.scan('-- DFRL.display.Get("enabled"); "Old caption"', captions=["Old caption"])
        self.assertEqual(result["unusedSettings"], ["enabled"])
        self.assertEqual(result["unusedCaptions"], ["Old caption"])

    def test_duplicate_setting_and_inconsistent_normalization_fail(self):
        result = self.scan('', display=DISPLAY.replace('enabled = true', 'enabled = true, enabled = false'))
        self.assertTrue(any("duplicate table key" in row for row in result["failures"]))
        result = self.scan('', display=DISPLAY.replace('Read(source, "enabled")', 'Read(source, "retired")'))
        self.assertTrue(any("wrong key" in row for row in result["failures"]))

    def test_unknown_setting_and_shared_api_fail(self):
        result = self.scan('DFRL.display.Get("typo"); T.MisspelledHelper()')
        self.assertTrue(any("unknown setting typo" in row for row in result["failures"]))
        self.assertTrue(any("unknown shared API DFRL.tools.MisspelledHelper" in row for row in result["failures"]))

    def test_duplicate_modules_and_undefined_callbacks_fail(self):
        result = self.scan('''
DFRL:NewMod("Example", 1, function() end)
DFRL:NewMod("Example", 2, function() end)
frame:SetScript("OnUpdate", MissingHandler)
''')
        self.assertTrue(any("duplicate registration" in row for row in result["failures"]))
        self.assertTrue(any("MissingHandler" in row for row in result["failures"]))

    def test_callback_function_nil_and_dynamic_arguments_are_distinguished(self):
        result = self.scan('''
local function Tick() end
frame:SetScript("OnUpdate", Tick)
frame:SetScript("OnUpdate", nil)
local function Bind(callback) frame:SetScript("OnUpdate", callback) end
frame:SetScript("OnUpdate", condition and Tick or nil)
''')
        self.assertEqual(result["failures"], [])
        self.assertTrue(result["dynamic"])
        result = self.scan('local handler = "Tick"; frame:SetScript("OnUpdate", handler)')
        self.assertTrue(any("non-functions" in row for row in result["failures"]))

    def test_dynamic_option_table_values_resolve_without_an_allowlist(self):
        result = self.scan('''
local keys = { flag = "enabled" }
for _, setting in pairs(keys) do DFRL.display.Get(setting) end
''')
        self.assertEqual(result["unusedSettings"], [])

    def test_unread_layout_flags_and_broken_option_callbacks_fail(self):
        result = analyze({
            "core/display.lua": DISPLAY,
            "core/layout.lua": '''
local layout = {}; DFRL.layout = layout
function layout.Register(key, frame, anchor, options)
  if options.onEdit then options.onEdit(true) end
end
''',
            "view.lua": 'DFRL.layout.Register("view", frame, nil, { typoFlag = true, onEdit = Missing })',
        }, [])
        self.assertTrue(any("typoFlag has no reader" in row for row in result["failures"]))
        self.assertTrue(any("callback Missing" in row for row in result["failures"]))

    def test_preexisting_candidates_remain_reported_but_new_orphans_fail(self):
        previous = {"unusedSettings": ["old"], "unusedCaptions": ["Old"]}
        self.assertEqual(orphan_regressions(previous, previous), [])
        current = {"unusedSettings": ["old", "enabled"], "unusedCaptions": ["Old", "New"]}
        self.assertEqual(len(orphan_regressions(current, previous)), 2)

    def test_extraction_keeps_exact_utf8_source_and_requires_unique_declarations(self):
        def extract(source, names):
            result = subprocess.run(["node", str(SOURCE / "scripts/addon_contracts.cjs")],
                                    input=json.dumps({"source": source, "extract": names}),
                                    text=True, capture_output=True, check=True)
            return json.loads(result.stdout)
        body = 'local function Paint() return "unchanged" end'
        self.assertEqual(extract('-- čínština\n' + body, ["Paint"]), body + '\nreturn Paint\n')
        constants = 'local LEFT, RIGHT = 1, 2'
        self.assertEqual(extract(constants, ["RIGHT"]), constants + '\nreturn RIGHT\n')
        self.assertEqual(extract(constants, ["RIGHT", "LEFT"]), constants + '\nreturn LEFT\n')
        with self.assertRaises(subprocess.CalledProcessError):
            extract(body + '\n' + body, ["Paint"])
        with self.assertRaises(subprocess.CalledProcessError):
            extract(constants + '\n' + constants, ["RIGHT"])


if __name__ == "__main__":
    unittest.main()
