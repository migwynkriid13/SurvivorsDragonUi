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
        run_hud = "local render, refreshRows, scheduleCache = {}, false, nil\n" + extract_source("modules/ui/run.lua", [
            "nativeParts", "TakeOver", "Restore", "SyncReplacements",
        ])
        run_hud = run_hud.rsplit("\nreturn ", 1)[0] + "\nreturn { TakeOver = TakeOver, Restore = Restore, Sync = SyncReplacements }\n"
        guardian_hover = "local hoveredPin, hoveredName\n" + extract_source("modules/map/waypoints.lua", [
            "PIN_SIZE", "Number", "HideGuardianTooltip", "UpdateGuardianTooltip",
        ])
        guardian_timers = "local hoveredPin, hoveredName\n" + extract_source("modules/map/waypoints.lua", [
            "PIN_SIZE", "Number", "Native", "FrameVisible", "MinimapEntries", "HideGuardianTooltip",
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
        waypoint_frame = extract_source("modules/map/waypoints.lua", ["Number", "Rotate", "WrapAngle", "Blend", "UpdateGuide"])
        xp_glow = extract_source("modules/xprep/xprep.lua", ["PaintGlow"])
        sct_queue = extract_source("modules/nameplates/sct.lua", [
            "FALLBACK_ICON", "EVENT_SETTLE", "EVENT_FALLBACK_DELAY", "DUPLICATE_WINDOW", "PERFORMANCE_DUPLICATE_WINDOW", "duplicateWindow", "DAMAGE_COLORS",
            "DAMAGE_SAMPLE_LIMIT", "DAMAGE_SAMPLE_TIME", "DAMAGE_SAMPLE_MINIMUM", "STRONG_DAMAGE_RATIO",
            "IsFiniteNumber", "TextureKey", "IconIdentityPart", "DamageColor", "SyncDuplicateWindow", "QueueCombatText", "UpdatePending", "HandleCombatEvent",
        ])
        sct_queue = sct_queue.rsplit("\nreturn ", 1)[0] + "\nreturn { Queue = QueueCombatText, Update = UpdatePending, Handle = HandleCombatEvent, SyncWindow = SyncDuplicateWindow }\n"
        run_foam = extract_source("modules/ui/run.lua", ["DrawFoam", "UpdateBlueFoam"])
        run_static = extract_source("modules/ui/run.lua", [
            "BAR_WIDTH", "FLOW_WIDTH", "FLOW_SPEED", "FLOW_INTERVAL", "FLOW_SPACING", "FLOW_COUNT", "FLOW_SPAN",
            "RED_SPARKLE_OPACITY", "AnimatedRunFill", "runEffects", "SetRunAppearance", "HideRunFlow", "UpdateRunFlow",
        ])
        run_static = run_static.rsplit("\nreturn ", 1)[0] + "\nreturn { Appearance = SetRunAppearance, Hide = HideRunFlow, Update = UpdateRunFlow, effects = runEffects }\n"
        run_progress = extract_source("modules/ui/run.lua", ["IsNumber", "UpdateClock"])
        run_affixes = 'local path = "Interface\\\\AddOns\\\\SurvivorsDragonUi\\\\media\\\\tex\\\\timer\\\\"\n' + extract_source("modules/ui/run.lua", ["SKULL_ICON", "IsNumber", "CreateRunAffixes", "UpdateRunFontBounds"])
        run_affixes = run_affixes.rsplit("\nreturn ", 1)[0] + "\nreturn { New = CreateRunAffixes, Bounds = UpdateRunFontBounds }\n"
        run_captions = extract_source("modules/ui/run.lua", [
            "IsNumber", "Clock", "ApplyFont", "NewClockLabel", "RefreshClockLabel", "StyleClockLabel",
            "SetClockLabelText", "RefreshTimerCaptions", "ClearClockCaptions", "UpdateClockCaptions",
        ])
        run_captions = run_captions.rsplit("\nreturn ", 1)[0] + "\nreturn { New = NewClockLabel, Update = UpdateClockCaptions, Refresh = RefreshTimerCaptions, Style = StyleClockLabel, Clear = ClearClockCaptions }\n"
        settings_views = extract_source("modules/ui/run.lua", [
            "SetSettingsEnabled", "UpdateSctLabels", "UpdateDisplayLabels", "RefreshFontControls",
        ])
        settings_views = settings_views.rsplit("\nreturn ", 1)[0] + "\nreturn { Display = UpdateDisplayLabels, SCT = UpdateSctLabels, Font = RefreshFontControls }\n"
        tally_counters = extract_source("modules/ui/run.lua", [
            "TALLY_COUNTER_INTERVAL", "IsNumber", "TallyCountersDue", "ClearTally", "UpdateTally", "UpdateRunBoundary",
        ])
        tally_counters = tally_counters.rsplit("\nreturn ", 1)[0] + "\nreturn { Update = UpdateTally, Clear = ClearTally, Boundary = UpdateRunBoundary }\n"
        minimap_clock = extract_source("modules/map/map.lua", ["WatchClock"])
        player_pulse = extract_source("modules/unit/player.lua", ["CreatePulse"])
        aura_layout = extract_source("modules/unit/auras.lua", ["PlaceNativeFrame", "Layout"])
        aura_duration = extract_source("modules/unit/auras.lua", ["Time", "SetTimerDuration"])
        pet_captions = extract_source("modules/unit/pets.lua", ["Number", "Time", "TimerText", "CountText", "HideRow"])
        pet_captions = pet_captions.rsplit("\nreturn ", 1)[0] + "\nreturn { Timer = TimerText, Count = CountText, Hide = HideRow }\n"
        chat_idle = extract_source("modules/chat/chat.lua", ["HOLD", "FADE", "FadeSettings"])
        chat_frame = extract_source("modules/chat/chat.lua", ["UpdateChat"])
        chat_performance = extract_source("modules/chat/chat.lua", [
            "HOLD", "FADE", "SLIDE", "AtBottom", "FadeSettings", "Rearm", "Reveal", "PositionNative", "NoticeMessage",
        ])
        run_markers = extract_source("modules/ui/run.lua", [
            "MARKER_SIZE", "ACTIVE_GLOW_PERIOD", "ACTIVE_GLOW_MIN_ALPHA", "ACTIVE_GLOW_MAX_ALPHA",
            "ACTIVE_GLOW_MIN_OFFSET", "ACTIVE_GLOW_MAX_OFFSET", "ShowMarkerGlow", "HideMarkerTooltip",
            "HideMarker", "UpdateMarkerStates",
        ])
        run_markers = run_markers.rsplit("\nreturn ", 1)[0] + "\nreturn { Update = UpdateMarkerStates, Hide = HideMarker }\n"
        run_debuff_cadence = extract_source("modules/ui/run.lua", [
            "IsNumber", "HideDebuff", "Permanent", "DebuffRemaining", "DebuffIcon", "UpdateDebuffs",
            "ReflowRows", "RefreshDebuffHover", "UpdateDebuffRows", "Update",
        ])
        run_debuff_cadence = run_debuff_cadence.rsplit("\nreturn ", 1)[0] + "\nreturn { Update = Update, Rows = UpdateDebuffRows }\n"
        run_boss_health_loss = extract_source("modules/ui/run.lua", ["CreateBossHealthLoss", "Retire", "UpdateRows"])
        run_boss_health_loss = run_boss_health_loss.rsplit("\nreturn ", 1)[0] + "\nreturn { New = CreateBossHealthLoss, Rows = UpdateRows, Retire = Retire }\n"
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 1
    with tempfile.TemporaryDirectory(prefix="sdui-ui-contracts-") as folder:
        placement = Path(folder) / "guardian-placement-source.lua"
        placement.write_text(guardian_placement, encoding="utf-8")
        aura_duration_source = Path(folder) / "aura-duration-source.lua"
        aura_duration_source.write_text(aura_duration, encoding="utf-8")
        for name, source, fixture in (
            ("settings-views-source.lua", settings_views, "ui_settings_visibility_spec.lua"),
            ("run-hud-source.lua", run_hud, "ui_shared_rules_spec.lua"),
            ("cooldown-source.lua", cooldown, "ui_spec.lua"),
            ("guardian-hover-source.lua", guardian_hover, "ui_guardian_hover_spec.lua"),
            ("guardian-timers-source.lua", guardian_timers, "ui_guardian_timer_spec.lua"),
            ("border-modes-source.lua", border_modes, "ui_border_spec.lua"),
            ("debuff-tooltip-source.lua", debuff_tooltip, "ui_debuff_tooltip_spec.lua"),
            ("navigation-distance-source.lua", navigation_distance, "ui_navigation_distance_spec.lua"),
            ("waypoint-frame-source.lua", waypoint_frame, "ui_waypoint_frame_perf_spec.lua"),
            ("xp-glow-source.lua", xp_glow, "ui_xp_perf_spec.lua"),
            ("sct-queue-source.lua", sct_queue, "ui_sct_queue_perf_spec.lua"),
            ("run-foam-source.lua", run_foam, "ui_run_foam_perf_spec.lua"),
            ("run-static-source.lua", run_static, "ui_run_static_mode_spec.lua"),
            ("run-progress-source.lua", run_progress, "ui_run_progress_perf_spec.lua"),
            ("run-affixes-source.lua", run_affixes, "ui_run_affixes_spec.lua"),
            ("run-captions-source.lua", run_captions, "ui_run_captions_perf_spec.lua"),
            ("tally-counters-source.lua", tally_counters, "ui_tally_counter_cadence_spec.lua"),
            ("minimap-clock-source.lua", minimap_clock, "ui_idle_clock_spec.lua"),
            ("player-pulse-source.lua", player_pulse, "ui_player_pulse_perf_spec.lua"),
            ("aura-layout-source.lua", aura_layout, "ui_aura_layout_perf_spec.lua"),
            ("pet-captions-source.lua", pet_captions, "ui_pet_caption_perf_spec.lua"),
            ("chat-idle-source.lua", chat_idle, "ui_chat_idle_perf_spec.lua"),
            ("chat-frame-source.lua", chat_frame, "ui_chat_frame_perf_spec.lua"),
            ("chat-performance-source.lua", chat_performance, "ui_performance_mode_spec.lua"),
            ("run-marker-source.lua", run_markers, "ui_run_marker_perf_spec.lua"),
            ("run-debuff-cadence-source.lua", run_debuff_cadence, "ui_run_debuff_cadence_spec.lua"),
            ("run-boss-health-loss-source.lua", run_boss_health_loss, "ui_run_boss_health_loss_spec.lua"),
        ):
            seam = Path(folder) / name
            seam.write_text(source, encoding="utf-8")
            command = ["lua5.1", "scripts/tests/fixtures/" + fixture, str(seam)]
            if fixture == "ui_guardian_hover_spec.lua":
                command.append(str(placement))
            if fixture == "ui_aura_layout_perf_spec.lua":
                command.append(str(aura_duration_source))
            if fixture == "ui_border_spec.lua":
                for name, body in (("border-portraits-source.lua", border_portraits), ("border-mini-source.lua", border_mini)):
                    source_file = Path(folder) / name
                    source_file.write_text(body, encoding="utf-8")
                    command.append(str(source_file))
            result = subprocess.run(command, cwd=SOURCE)
            if result.returncode:
                return result.returncode
        for fixture in ("ui_editor_navigation_spec.lua", "ui_retail_edit_spec.lua", "ui_retail_layout_spec.lua", "ui_default_chat_spec.lua", "ui_health_spec.lua", "ui_mini_health_spec.lua", "ui_sct_spec.lua", "ui_nameplates_spec.lua", "ui_marks_spec.lua", "ui_meter_party_spec.lua", "ui_party_waypoint_spec.lua", "ui_banners_perf_spec.lua", "ui_layout_spec.lua", "ui_pets_totems_spec.lua", "ui_guardian_tracker_perf_spec.lua", "ui_revive_perf_spec.lua", "ui_core_idle_cadence_spec.lua", "ui_cooldown_lifecycle_spec.lua", "ui_tooltip_style_perf_spec.lua", "ui_target_color_perf_spec.lua", "ui_target_classification_spec.lua", "ui_passive_cadence_spec.lua", "ui_projection_cache_perf_spec.lua", "ui_sct_metadata_perf_spec.lua"):
            result = subprocess.run(["lua5.1", "scripts/tests/fixtures/" + fixture], cwd=SOURCE)
            if result.returncode:
                return result.returncode
        return 0


if __name__ == "__main__":
    sys.exit(main())
