"""CI runner regressions over fake processes; never execute Lua or client code."""

from contextlib import redirect_stderr
import io
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import run_ui_contracts


class UiContractRunnerTests(unittest.TestCase):
    def run_with_results(self, failures):
        visited, stderr = [], io.StringIO()

        def process(command, **options):
            self.assertEqual(command[0], "lua5.1")
            self.assertEqual(options["cwd"], run_ui_contracts.SOURCE)
            fixture = Path(command[1]).name
            visited.append(fixture)
            return SimpleNamespace(returncode=failures.get(fixture, 0))

        with patch.object(run_ui_contracts, "extract_source", return_value="\nreturn {}\n"), \
                patch.object(run_ui_contracts.subprocess, "run", side_effect=process), redirect_stderr(stderr):
            code = run_ui_contracts.main()
        return code, visited, stderr.getvalue()

    def test_failures_in_both_groups_do_not_skip_later_fixtures(self):
        failures = {"ui_settings_visibility_spec.lua": 2, "ui_retail_layout_spec.lua": 3}
        code, visited, stderr = self.run_with_results(failures)
        self.assertEqual(code, 1)
        self.assertIn("ui_settings_visibility_spec.lua", visited)
        self.assertIn("ui_retail_layout_spec.lua", visited)
        self.assertEqual(visited[-1], "ui_sct_metadata_perf_spec.lua")
        self.assertIn("Failed UI fixtures:", stderr)
        for fixture, status in failures.items():
            self.assertIn(f"{fixture} (exit {status})", stderr)

    def test_all_successful_fixtures_return_success(self):
        code, visited, stderr = self.run_with_results({})
        self.assertEqual(code, 0)
        self.assertEqual(visited[-1], "ui_sct_metadata_perf_spec.lua")
        self.assertEqual(stderr, "")

    def test_source_preparation_failure_stops_before_processes_start(self):
        stderr = io.StringIO()
        with patch.object(run_ui_contracts, "extract_source", side_effect=RuntimeError("missing source")), \
                patch.object(run_ui_contracts.subprocess, "run") as process, redirect_stderr(stderr):
            self.assertEqual(run_ui_contracts.main(), 1)
        process.assert_not_called()
        self.assertIn("missing source", stderr.getvalue())
