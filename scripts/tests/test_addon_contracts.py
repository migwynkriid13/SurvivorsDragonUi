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

    def test_native_closure_limit_accepts_32_and_rejects_33_distinct_bindings(self):
        for count in (32, 33):
            names = ", ".join(f"value{index}" for index in range(count))
            source = f"local {names}\nreturn function() return {names}, value0 end"
            result = self.scan(source)
            failures = [row for row in result["failures"] if "upvalues" in row]
            self.assertEqual(len(failures), int(count > 32))
            if failures:
                self.assertIn("captures 33 upvalues (limit 32)", failures[0])

    def test_deeper_closure_captures_are_carried_by_intermediate_closures(self):
        names = ", ".join(f"value{index}" for index in range(33))
        result = self.scan(f"local {names}\nreturn function() return function() return {names} end end")
        self.assertEqual(sum("captures 33 upvalues" in row for row in result["failures"]), 2)

    def test_field_names_globals_and_current_function_locals_are_not_upvalues(self):
        names = ", ".join(f"value{index}" for index in range(40))
        fields = ", ".join(f"value{index} = outside.value{index}" for index in range(40))
        source = f"""local {names}
return function()
  local {names}
  return {names}, {{ {fields} }}
end"""
        self.assertEqual(self.scan(source)["failures"], [])

    def test_block_bindings_remain_distinct_and_initializers_keep_outer_scope(self):
        locals_ = ", ".join(f"value{index}" for index in range(31))
        source = f"""local {locals_}, value
do
  local read = function() return {locals_}, value end
  local value = function() return {locals_}, value, read end
end"""
        result = self.scan(source)
        self.assertEqual(sum("captures 33 upvalues" in row for row in result["failures"]), 1)

    def test_native_method_self_varargs_loops_and_repeat_scopes(self):
        source = '''local object = {}
function object:Read(...)
  local callbacks = {}
  for index = 1, 2 do callbacks[index] = function() return self, arg, index end end
  for key, value in pairs(object) do callbacks[key] = function() return value end end
  repeat
    local ready = true
    callbacks.check = function() return ready end
  until ready
  return callbacks
end'''
        self.assertEqual(self.scan(source)["failures"], [])

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

    def test_defaults_driven_normalization_requires_a_complete_matching_copy(self):
        original = 'local function Normalize(source) return { enabled = Read(source, "enabled") } end'
        copy = '''local function Normalize(source)
    local result = {}
    for key in pairs(defaults) do result[key] = Read(source, key) end
    return result
end'''
        display = DISPLAY.replace(original, copy)
        self.assertEqual(self.scan('DFRL.display.Get("enabled")', display=display)["failures"], [])
        for broken in (
            copy.replace('pairs(defaults)', 'pairs(source)'),
            copy.replace('Read(source, key)', 'Read(source, "retired")'),
            copy.replace('result[key] =', 'result.other ='),
            copy.replace('return result', 'return {}'),
            copy.replace('result[key] = Read(source, key)', 'if source[key] then result[key] = Read(source, key) end'),
        ):
            with self.subTest(broken=broken):
                result = self.scan('', display=DISPLAY.replace(original, broken))
                self.assertTrue(any("missing from Normalize" in row for row in result["failures"]))

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
