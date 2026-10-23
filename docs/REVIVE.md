# Revive progress

The selected design 01 places a white caption above
the same rounded WidgetStatusBar bezel as the run timer. The fill is green, a
spark follows reported progress, and a gold percentage sits to the right. The
preview uses sample player names and approximate typography; the addon uses the
resolved DEFAULT font. Both directions share one passive view.

## Received state

`modules/ui/revive.lua` feature-detects `AZS_GetRevive` and `AZS_GetPhase`. Older
clients without either getter do not create this group. Each refresh reads phase
first and accepts received snapshots only in playing, choosing, paused, dead or
victory. A finite `AZS_REVIVE_UPDATED` marks receipt; it is neither an event nor
an expiry deadline.

| Received fields                                   | Display                                 |
| ------------------------------------------------- | --------------------------------------- |
| `down == 1`, nonempty `by`, finite `share`        | “NAME is bringing you back” and `share` |
| `down == 1`, absent/empty `by`, finite `share`    | “Downed — waiting for help” and `share` |
| `down == 0`, nonempty `reviving`, finite `rshare` | “Bringing NAME back” and `rshare`       |
| Empty, idle, unsupported or invalid state         | Hide and clear the custom view          |

Names are supplied display values. Numeric-looking names are converted with
`tostring`, with no unit-token, GUID, class or party-roster inference. Numeric
zero is alive in Lua, so both `down` comparisons are explicit. Finite native
progress is clamped to 0–1 and rounded to a whole percentage for the label.
There is no countdown, interpolated revive clock, extrapolated progress, revive
action or gameplay write.

The controller checks at most every 0.1 seconds. `CHAT_MSG_ADDON` with prefix
`AZSREVIVE` schedules a deferred refresh after native parsing; it does not read
the getter inside the event. The getter is fetched again for each changed
snapshot, and its shared tables are never retained for mutation. Stable
snapshots remain valid regardless of timestamp age. World leave, logout,
reload and `AZSZONE` retire the visible state and block the old packet identity,
stamp and delivery generation until a fresh delivery. World entry resumes
refreshing. Both resets clear the view and allow current valid state to repaint.

## Layout and native overlap

One **Revive** group uses shared movement, proportional scale, numeric controls,
hiding, profiles and Confirm-only geometry saving. Cancel, world/logout/reload
discard and both resets remain owned by shared Layout. Its passive handle is
available without an active revive. Only geometry and the existing optional
hidden flag are saved; no revive data, setting or SavedVariable is added.

The default places the pill at the recovered native bar's center for comparison,
as requested. The original root is 300 × 24 native logical pixels, horizontally
centered with `left: 50%`, `margin-left: -150px`, and `bottom: 38%`. The custom
pill starts at 300 × 31 addon units. Its bottom is offset by −3.5 units from
38% of UIParent height to align their authored centers; the right-side
percentage is included in the edit bounds. Captions can widen the group, and
shared `refreshDefault` retains its default pill center while leaving confirmed
and draft geometry intact. Physical pixel alignment across native and addon UI
scales has not been tested.

**This is a comparison overlay, not native suppression.** In the inspected
0.113.0 EXE, `AZS_SetHudShown` exposes only clock, bosses, tally, build, banners,
loot, meter, levels and flag. There is no revive control. The original
`ReviveBar`, `ReviveFill` and `ReviveLine` are Bevy UI entities. FrameXML strata
sort Lua quad batches; the native Bevy UI pass is later. Raising the custom
frame's strata cannot be treated as covering that separate pass. The original
bar can remain visible above the custom pill; move **Revive** in `/sdui` to
compare them separately.

The module neither writes an unsupported revive CVar nor claims ownership of
the native bar. Clean replacement still needs a selective game-side visibility
control while keeping revive packets available. No EXE patch is included.

## Native and artwork evidence

Recovered target: Azeroth Survivors 0.113.0, EXE SHA-256
`c3a82f594e05dc8cea49dfa38e69aca96c9ee625a5b7df3ffa93c19dc8c95773`.

- Native label/update owner: `0x140214a50..0x14021593e`. REA/Ghidra evidence
  `ev_a6b0ee682a63da02eb641aa2751b3942eaff771b4176c413fda6bfa34d9e9aa0`.
  Its constructor block `0x140214fe5..0x1402152ac` supplies the native geometry
  above and `GlobalZIndex(4100)`.
- Native HUD visibility owner: `0x1403fdb50..0x1403fe552`. REA evidence
  `ev_4fc15a0451b3e79030de60ca716fee3333dd2ef3702ab70817c8220758976c9f`.
  The nine-control template descriptors occupy `0x14700d280..0x14700d3a0`.
- The current EXE's UI graph contains `UiPass → UiGammaLabel`, corroborated by
  original typed vtables/formatters and REA evidence
  `ev_3ba826c185301e21454ad5185454af35793063a3219e89a2107fcc9c804005e6`
  and `ev_d423241cd9b7393c5c32b299490c918937e3f5a58fc829e10ec428f86d6743e4`.
  This is static pass-order evidence, not a runtime overlap capture.

The two name-bearing captions reuse exact native wording from that target's
fourteen embedded catalogs, changing only `{name}` to a Lua `%s` placeholder.
The Layout caption and waiting caption have fourteen source TSV/runtime
translations. Existing reviewed native catalogs, effects and aliases retain
their original fingerprint. See [localization notes](LOCALIZATION.md).

The bezel, background, white fill and spark reuse existing Blizzard artwork.
Exact texture source, crops, alpha and ownership are retained in
[WidgetStatusBar-SOURCE.md](../third_party/WidgetStatusBar-SOURCE.md).
Only the newly used existing `Spark.tga` joins the runtime manifest alongside
the module. The selected preview and other developer files do not ship.

Local addon checks, syntax checks, formatters, tests and game/addon execution
were intentionally not run. GitHub Actions provides the permitted static
checks. Native co-op behavior, visual coverage and physical scale alignment
remain unverified in game.
