#!/usr/bin/env python3
"""Keep addon asset roots centralized; run by GitHub Actions, never addon Lua."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PREFIX = r"Interface\\AddOns\\"
ADDON_ROOT = PREFIX + r"SurvivorsDragonUi\\"


def main():
    manifest = json.loads((ROOT / "packaging/runtime-files.json").read_text())
    lua_files = [name for name in manifest["files"] if name.endswith(".lua")]
    failures = []
    for name in lua_files:
        text = (ROOT / name).read_text()
        if name == "core/core.lua":
            assert text.count(PREFIX) == text.count(ADDON_ROOT) == 1
        else:
            for line_number, line in enumerate(text.splitlines(), 1):
                if PREFIX in line:
                    failures.append(f"{name}:{line_number}: bypasses the shared addon asset root")
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"All {len(lua_files)} runtime Lua sources use the single addon asset root.")


if __name__ == "__main__":
    main()
