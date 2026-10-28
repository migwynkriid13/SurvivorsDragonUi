# Revive progress

The selected design 01 places a white caption above
the same rounded WidgetStatusBar bezel as the run timer. The fill is green, a
spark follows reported progress, and a gold percentage sits to the right. The
addon uses the resolved DEFAULT font. Both directions share one passive view.
The bar appears only while reviving someone or being revived. Being downed
without a helper shows no caption, bar or percentage.

## Received state

`modules/ui/revive.lua` feature-detects `AZS_GetRevive` and `AZS_GetPhase`. Older
clients without either getter do not create this group. Each refresh reads phase
first and accepts received snapshots only in playing, choosing, paused, dead or
victory. A finite `AZS_REVIVE_UPDATED` marks receipt; it is neither an event nor
an expiry deadline.

| Received fields                                   | Display                                                 |
| ------------------------------------------------- | ------------------------------------------------------- |
| `down == 1`, nonempty `by`, finite `share`        | “NAME is reviving you!” and `share`                     |
| `down == 1`, absent/empty `by`, finite `share`    | Hide the custom artwork and suppress the native display |
| `down == 0`, nonempty `reviving`, finite `rshare` | “Reviving NAME!” and `rshare`                           |
| Empty, idle, unsupported or invalid state         | Hide and clear the custom view                          |

Names are supplied display values. Numeric-looking names are converted with
`tostring`, with no unit-token, GUID, class or party-roster inference. Numeric
zero is alive in Lua, so both `down` comparisons are explicit. Finite native
progress is clamped to 0–1. The fill and spark animate only between received
values, targeting a 0.14-second transition. Each rendered update advances by at
most one percentage point, and the rounded label changes by at most one; a low
frame rate can extend the visual catch-up. The label reaches 100% only
when the displayed and received values reach one. A fresh direction or supplied
subject starts at its received value with a 0.18-second fade-in. Six pooled
healing crosses stay at fixed positions across the pill, using native `WHITE8X8`
textures. Each rectangle is clipped at the fill edge, so progress uncovers the
marks without moving them. The pulse period is 0.7 seconds, twice the previous
speed, with six marks replacing four for a denser pattern. Decorative fades and
pulses use the full frame elapsed time. The marks remain visible at 100% until
the native state clears the view. No health values or assets are added.

The view retains authored cross widths and anchors between paints, updating
geometry only when clipping or caption width changes. The same pulse colors
continue at frame cadence. Completed fade-in stops rewriting full opacity;
the fill, spark and visibility setters likewise skip unchanged values. Clearing
and new subjects retain the original fade and percentage-step behavior.

The view caches only the latest subject/direction, language and translated
caption, plus the latest displayed percentage string. New native progress still
updates normally, but unchanged text skips formatting. Hidden views defer
caption formatting until visible. Actual label comparisons retain failed-write
retries and repair external text changes. Clear invalidates these display
caches. No effect, clipping equation, smoothing step or update cadence changes.

The installed 0.115.0 native Lua defines `AZS_GetRevive()` as a direct return of
`AZS_REVIVE`. Its documented fields are `down`, `share`, `by`, `reviving` and
`rshare`; it does not supply a revive duration or start time. `AZSREVIVE` parses
the received fields and stamps their receipt with `GetTime()`. Presentation
animation uses frame elapsed time only between confirmed values; it never
predicts future progress. Without a new sample, the fill settles at its latest
received target. Idle, invalid or retired state clears immediately instead of
waiting for an animation to complete. There is no countdown, extrapolated
progress, revive action or gameplay write.

The controller checks native snapshots at most every 0.1 seconds and animates
visible artwork each frame. `CHAT_MSG_ADDON` with prefix
`AZSREVIVE` schedules a deferred refresh after native parsing; it does not read
the getter inside the event. The getter is fetched again for each changed
snapshot, and its shared tables are never retained for mutation. Stable
snapshots remain valid regardless of timestamp age. World leave, logout,
reload and `AZSZONE` retire the visible state and block the old packet identity,
stamp and delivery generation until a fresh delivery. World entry resumes
refreshing. Both resets clear the view and allow current valid state to repaint.

## Layout and native replacement

The custom bar defaults on, and both full resets restore that default. In
`/sdui` → **Layout**, select **Revive** to move, resize or hide it. Missing
visibility uses the visible default; existing confirmed hidden choices and
profile copies are preserved. No saved geometry is rewritten.

One **Revive** group uses shared movement, proportional scale, numeric controls,
hiding, profiles and Confirm-only geometry saving. Cancel, world/logout/reload
discard and both resets remain owned by shared Layout. Its passive handle is
available without an active revive. Only geometry and the existing optional
hidden flag are saved; no revive data, setting or SavedVariable is added.

The default places the pill at the recovered native bar's center.
The original root is 300 × 24 native logical pixels, horizontally
centered with `left: 50%`, `margin-left: -150px`, and `bottom: 38%`. The custom
pill starts at 300 × 31 addon units. Its bottom is offset by −3.5 units from
38% of UIParent height to align their authored centers; the right-side
percentage is included in the edit bounds. Captions can widen the group, and
shared `refreshDefault` retains its default pill center while leaving confirmed
and draft geometry intact. Physical pixel alignment across native and addon UI
scales has not been tested.

The supplied 0.115.0 release notes add `AZS_SetHudShown("revive", false)`.
For valid received state while the custom group is enabled,
the module uses the shared `NewHudOwner("revive")` helper to capture the native
visibility through `AZS_IsHudShown("revive")`, hide the original and confirm the
result. A downed-only snapshot keeps the passive layout root available but hides
all artwork and stops its animation. Native suppression remains active so the
original waiting display cannot reappear. A named helper restores the same
progress artwork and fade-in. Stable snapshots still synchronize ownership, so
hiding/unhiding the group or a changed native preference does not need another
revive packet.

Hiding the custom group releases native ownership immediately. Idle or invalid
state, inactive phases, zone changes, world leave, logout, reload and refresh
errors also clear the view and restore the captured native preference. An
originally hidden native bar stays hidden; a later visible external choice is
preserved on release. No native preference snapshot is saved by the addon.

Missing or unsupported native visibility APIs leave the original bar alone.
Older clients can still show the custom overlay but cannot suppress the native
bar; move or hide **Revive** through Layout if they overlap. The module uses
only the official HUD getter/setter, with no direct revive CVar writes, strata
workaround or client patch.

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

The user-selected captions are **Reviving %s!** and **%s is reviving you!**.
Both name-bearing captions, the Layout caption and waiting caption have fourteen
source TSV/runtime translations. Existing reviewed native catalogs, effects and aliases retain
their original fingerprint. See [localization notes](LOCALIZATION.md).

The bezel, background, white fill and spark reuse existing Blizzard artwork.
Exact texture source, crops, alpha and ownership are retained in
[WidgetStatusBar-SOURCE.md](../third_party/WidgetStatusBar-SOURCE.md).
Only the newly used existing `Spark.tga` joins the runtime manifest alongside
the module. The selected preview and other developer files do not ship.

The user approved the appearance through a temporary two-direction sample loop.
That loop, its sample names and its artificial completion hold are removed from
the runtime module. Live progress uses only received native co-op snapshots.
Edited Lua and Markdown receive the repository's pinned formatters; local tests,
standalone syntax/validation checks and additional game execution were not run.
GitHub Actions is not awaited or polled. Actual co-op event ordering and native
completion/cancellation behavior remain unverified in game.

## Independent width

Revive's Layout outline has left/right center handles for width only (160–1200 local units); corner handles retain proportional scaling. Until a width is chosen, the original 356-unit minimum and caption-based fitting remain. A chosen width is stored with position/scale in the existing Layout record, using Confirm, Cancel/discard, profiles and both resets. Caption width follows that choice. The native fill, spark and authored cross animation use the actual root width minus the original 72-unit inset; a size transition dirties the view even when native progress is unchanged. No new effect, asset or updater is added, and hidden presentation stays deferred. Runtime appearance and input remain unverified.
