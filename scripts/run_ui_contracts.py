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
        guardian_timers = "local hoveredPin, hoveredName\n" + extract_source("modules/map/waypoints.lua", [
            "PIN_SIZE", "Number", "Native", "MinimapEntries", "Shown", "HideGuardianTooltip",
            "HideGuardianTimer", "UpdateGuardianTimer", "RecyclePins", "MakeMinimapPin", "PlacePin",
            "Offset", "DrawTrackedPin", "UpdateTrackerPins",
        ])
        guardian_placement = "local tooltip, root = GameTooltip, tooltipRoot\nlocal inWorld, editing = true, false\nlocal lastIconOwner\n" + extract_source("core/tooltips.lua", [
            "IconOwner", "PlaceTooltip",
        ])
        border_modes = "local resourcesShown, appliedDelta\n" + extract_source("modules/unit/mini.lua", ["UpdateResources"])
        border_portraits = "local portraitsHidden\n" + extract_source("core/widgets.lua", ["UpdatePortraitVisibility"])
        border_mini = "local portraitsHidden\n" + extract_source("modules/unit/mini.lua", ["UpdatePortraitVisibility"])
        debuff_tooltip = extract_source("modules/ui/run.lua", ["IsNumber", "Clock", "Permanent", "DebuffRemaining", "DebuffTooltip"])
        navigation_distance = extract_source("modules/map/waypoints.lua", ["UpdateDistance"])
        xp_glow = extract_source("modules/xprep/xprep.lua", ["PaintGlow"])
        sct_queue = extract_source("modules/nameplates/sct.lua", [
            "FALLBACK_ICON", "EVENT_SETTLE", "EVENT_FALLBACK_DELAY", "DUPLICATE_WINDOW", "DAMAGE_COLORS",
            "DAMAGE_SAMPLE_LIMIT", "DAMAGE_SAMPLE_TIME", "DAMAGE_SAMPLE_MINIMUM", "STRONG_DAMAGE_RATIO",
            "TextureKey", "IconIdentityPart", "DamageColor", "QueueCombatText", "UpdatePending", "HandleCombatEvent",
        ])
        sct_queue = sct_queue.rsplit("\nreturn ", 1)[0] + "\nreturn { Queue = QueueCombatText, Update = UpdatePending, Handle = HandleCombatEvent }\n"
        run_foam = extract_source("modules/ui/run.lua", ["DrawFoam", "UpdateBlueFoam"])
        run_affixes = 'local path = "Interface\\\\AddOns\\\\SurvivorsDragonUi\\\\media\\\\tex\\\\timer\\\\"\n' + extract_source("modules/ui/run.lua", ["SKULL_ICON", "IsNumber", "CreateRunAffixes"])
        run_captions = extract_source("modules/ui/run.lua", [
            "IsNumber", "Clock", "ApplyFont", "NewClockLabel", "RefreshClockLabel", "StyleClockLabel",
            "SetClockLabelText", "RefreshTimerCaptions", "ClearClockCaptions", "UpdateClockCaptions",
        ])
        run_captions = run_captions.rsplit("\nreturn ", 1)[0] + "\nreturn { New = NewClockLabel, Update = UpdateClockCaptions, Refresh = RefreshTimerCaptions, Style = StyleClockLabel, Clear = ClearClockCaptions }\n"
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 1
    with tempfile.TemporaryDirectory(prefix="sdui-ui-contracts-") as folder:
        placement = Path(folder) / "guardian-placement-source.lua"
        placement.write_text(guardian_placement, encoding="utf-8")
        for name, source, fixture in (
            ("cooldown-source.lua", cooldown, "ui_spec.lua"),
            ("guardian-hover-source.lua", guardian_hover, "ui_guardian_hover_spec.lua"),
            ("guardian-timers-source.lua", guardian_timers, "ui_guardian_timer_spec.lua"),
            ("border-modes-source.lua", border_modes, "ui_border_spec.lua"),
            ("debuff-tooltip-source.lua", debuff_tooltip, "ui_debuff_tooltip_spec.lua"),
            ("navigation-distance-source.lua", navigation_distance, "ui_navigation_distance_spec.lua"),
            ("xp-glow-source.lua", xp_glow, "ui_xp_perf_spec.lua"),
            ("sct-queue-source.lua", sct_queue, "ui_sct_queue_perf_spec.lua"),
            ("run-foam-source.lua", run_foam, "ui_run_foam_perf_spec.lua"),
            ("run-affixes-source.lua", run_affixes, "ui_run_affixes_spec.lua"),
            ("run-captions-source.lua", run_captions, "ui_run_captions_perf_spec.lua"),
        ):
            seam = Path(folder) / name
            seam.write_text(source, encoding="utf-8")
            command = ["lua5.1", "scripts/tests/fixtures/" + fixture, str(seam)]
            if fixture == "ui_guardian_hover_spec.lua":
                command.append(str(placement))
            if fixture == "ui_border_spec.lua":
                for name, body in (("border-portraits-source.lua", border_portraits), ("border-mini-source.lua", border_mini)):
                    source_file = Path(folder) / name
                    source_file.write_text(body, encoding="utf-8")
                    command.append(str(source_file))
            result = subprocess.run(command, cwd=SOURCE)
            if result.returncode:
                return result.returncode
        for fixture in ("ui_health_spec.lua", "ui_sct_spec.lua", "ui_nameplates_spec.lua", "ui_marks_spec.lua", "ui_meter_party_spec.lua", "ui_banners_perf_spec.lua", "ui_layout_spec.lua", "ui_pets_totems_spec.lua", "ui_guardian_tracker_perf_spec.lua", "ui_revive_perf_spec.lua"):
            result = subprocess.run(["lua5.1", "scripts/tests/fixtures/" + fixture], cwd=SOURCE)
            if result.returncode:
                return result.returncode
        return 0


if __name__ == "__main__":
    sys.exit(main())
