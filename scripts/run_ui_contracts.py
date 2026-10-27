"""CI-only mocked Lua tests. No game launch, client files or runtime test hooks."""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

from package import SOURCE


def main():
    # Extract exact AST ranges from the real controller, including its real
    # constants. Do not copy an algorithm or add test exports to runtime Lua.
    names = ["COOLDOWN_INTERVAL", "COOLDOWN_ZERO", "COOLDOWN_FINAL_WINDOW", "COOLDOWN_UNITS",
             "FormatCooldown", "UpdateCooldownNumber", "CreateCooldownNumbers"]
    parsed = subprocess.run(
        ["node", str(SOURCE / "scripts/addon_contracts.cjs")],
        input=json.dumps({"source": (SOURCE / "modules/bars/bars.lua").read_text(encoding="utf-8"), "extract": names}),
        text=True, capture_output=True,
    )
    if parsed.returncode:
        print(parsed.stderr, file=sys.stderr)
        return parsed.returncode
    with tempfile.TemporaryDirectory(prefix="sdui-ui-contracts-") as folder:
        seam = Path(folder) / "cooldown-source.lua"
        seam.write_text(json.loads(parsed.stdout), encoding="utf-8")
        result = subprocess.run(["lua5.1", "scripts/tests/fixtures/ui_spec.lua", str(seam)], cwd=SOURCE)
        if result.returncode:
            return result.returncode
        for fixture in ("ui_health_spec.lua", "ui_sct_spec.lua"):
            result = subprocess.run(["lua5.1", "scripts/tests/fixtures/" + fixture], cwd=SOURCE)
            if result.returncode:
                return result.returncode
        return 0


if __name__ == "__main__":
    sys.exit(main())
