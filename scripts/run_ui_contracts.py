"""CI-only mocked Lua tests. No game launch, client files or runtime test hooks."""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

from package import SOURCE


def extract_source(path, names):
    parsed = subprocess.run(
        ["node", str(SOURCE / "scripts/addon_contracts.cjs")],
        input=json.dumps({"source": (SOURCE / path).read_text(encoding="utf-8"), "extract": names}),
        text=True, capture_output=True,
    )
    if parsed.returncode:
        raise RuntimeError(parsed.stderr)
    return json.loads(parsed.stdout)


def main():
    # Extract exact AST ranges from the real controllers, including constants.
    # Do not copy algorithms or add test exports to runtime Lua.
    try:
        cooldown = extract_source("modules/bars/bars.lua", [
            "COOLDOWN_INTERVAL", "COOLDOWN_ZERO", "COOLDOWN_FINAL_WINDOW", "COOLDOWN_UNITS",
            "FormatCooldown", "UpdateCooldownNumber", "CreateCooldownNumbers",
        ])
        guardian_hover = "local hoveredPin, hoveredName\n" + extract_source("modules/map/waypoints.lua", [
            "PIN_SIZE", "Number", "HideGuardianTooltip", "UpdateGuardianTooltip",
        ])
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 1
    with tempfile.TemporaryDirectory(prefix="sdui-ui-contracts-") as folder:
        for name, source, fixture in (
            ("cooldown-source.lua", cooldown, "ui_spec.lua"),
            ("guardian-hover-source.lua", guardian_hover, "ui_guardian_hover_spec.lua"),
        ):
            seam = Path(folder) / name
            seam.write_text(source, encoding="utf-8")
            result = subprocess.run(["lua5.1", "scripts/tests/fixtures/" + fixture, str(seam)], cwd=SOURCE)
            if result.returncode:
                return result.returncode
        for fixture in ("ui_health_spec.lua", "ui_sct_spec.lua", "ui_nameplates_spec.lua", "ui_marks_spec.lua", "ui_meter_party_spec.lua"):
            result = subprocess.run(["lua5.1", "scripts/tests/fixtures/" + fixture], cwd=SOURCE)
            if result.returncode:
                return result.returncode
        return 0


if __name__ == "__main__":
    sys.exit(main())
