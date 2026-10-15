# Native API recovery after UI reload — 2026-10-14

The user reported that `/reload` restores the native timer and other HUD parts instead of reconnecting the addon displays. No game startup, addon execution, test, syntax check or validation was run for this investigation or its edits.

## Read-only evidence and limit

Embedded source/log strings in the local packaged `AzerothSurvivors.exe` show that UI reload rebuilds the Lua VM and the API initialization creates fresh state tables. The official documentation says `AZS_ZONE` is sent once per run and schedule/unit lists are sent only when they change. This supports a missing-snapshot replay explanation, but no live reload trace was collected to prove the exact failing engine path.

The existing addon retried official getters every frame, but required valid clock and zone-derived duration before refreshing any replacement. Thus missing zone data also blocked otherwise valid tally and encounter data. Fresh empty API tables could additionally be mistaken for a received empty encounter list.

## Addon changes

- Read the phase first, then use official `AZS_RUN.fin` if `AZS_GetRunLength()` has not recovered. Both values describe the native final-boss time.
- Reconnect clock, tally and encounter displays independently, preserving each native HUD part until its replacement has valid data.
- Require `AZS_UNITS_UPDATED` before accepting an initially empty encounter snapshot.
- Keep retrying the official getters and responding to native addon messages. Do not reconstruct elapsed time or guess boss markers. The later reload-only boss-schedule handoff below supersedes the original blanket cache prohibition; the separately authorized layout SavedVariables still contain frame geometry only.

The addon does not change the engine, parser, launcher or server. These source changes remain unverified live.

## What the game owner needs to provide

For reliable `/reload` recovery, including while paused or with unchanged lists, reinstall the official API parser/getters in each new Lua VM, then force a full current-state replay after the parser is registered. At minimum replay `AZSZONE`, `AZSRUN`, `AZSBOSSES` and `AZSUNITS`; ideally replay all API prefixes. Replay must occur even when the native state has not changed.

The supplied API documents no request/resync function that the addon can invoke. Without native replay, missing once-per-run facts or unchanged encounter lists cannot be recovered faithfully by addon polling alone. The later schedule handoff preserves only an already-received complete schedule through an eligible reload; it does not supply missing encounters or prove run identity. Native HUD fallback stays available until the corresponding replacement's required values arrive; marker availability does not gate a valid custom clock.

## Missing boss-spawn lines — 2026-10-15

The user subsequently reported that the custom progress timer returns after `/reload` but its vertical boss-spawn markers disappear. The native clock and recurring `AZS_RUN.fin` can recover before the complete schedule. The previous marker update treated a fresh empty `AZS_SCHEDULE` as an empty set of spawn times, while clock takeover required only valid time and duration. That allowed a replacement lacking the native next-boss information to hide the original clock HUD.

The first response required a complete valid native schedule before displaying or taking over the custom clock. The complete check uses the expected boss count from `AZS_RUN.bt` or `AZS_ZONE.bt`, unique numeric schedule indices, positive `at` times within the native duration, recognized `due`/`up`/`dead` states, and a final-boss flag/time agreeing with that duration. Every complete schedule entry contributes a marker regardless of its state. The current policy below retains that complete validation and uses the official boss state for default skulls, active glow and killed checkmarks.

The addon cannot recreate intermediate spawn times from the final-boss duration or the future-only `AZS_GetUpcomingBosses()` list. At this stage, marker recovery required the game to replay the complete `AZSBOSSES` snapshot into each new Lua VM, even when paused or when boss states were unchanged. The later handoff below adds a narrow saved-schedule fallback. Polling cannot invent missing schedules, and there is still no documented request/resync function or hardcoded schedule.

## Full progress-bar regression and correction — 2026-10-15

The user reported that `/reload` now removes the entire custom top bar, whereas previously only its vertical boss-spawn lines were missing. The new schedule readiness condition gated the whole custom clock, so an absent or incomplete `AZS_SCHEDULE` called `ReleaseClock()` even with valid native elapsed time and duration.

Clock display and native clock takeover again depend only on a valid phase, native elapsed time and native duration, including the phase-gated `AZS_RUN.fin` duration fallback. The complete schedule check now gates marker drawing alone. Missing schedule data clears marker textures without hiding the progress bar or time text; the native clock stays replaced to avoid duplicate displays. Markers rebuild when the complete official snapshot arrives, using `due` for default skulls, `up` for active glow and `dead` for smaller, faded skulls with a green killed checkmark. Invalid phase/time/duration still releases the replacement and restores captured native visibility, preserving an originally false preference. Tally and encounter recovery remains independent.

This corrected the addon-side full-bar regression without inventing marker times or changing the game. It originally relied entirely on native replay for schedule recovery; the later handoff below adds a narrowly scoped persistence exception.

No tests, syntax checks, validation, addon execution or game startups were run for this edit. Full marker restoration after `/reload` has not been verified live.

## Current skull appearance from native boss state — 2026-10-15

The user superseded elapsed-time completion with the official schedule's boss state. Completeness validation includes every native schedule entry with a recognized `due`, `up` or `dead` state. A `due` marker shows its default 18-by-18 skull at full opacity without a glow or checkmark. An `up` marker keeps that skull unchanged and adds a red/orange glow underneath it, forming an outline without tinting the skull. A `dead` marker shows an 80%-size skull at 0.70 alpha with a green native checkmark and no active glow. The checkmark means the boss was killed. Elapsed time or absence from the live boss list never establishes activation or death. List and marker-geometry refresh remain throttled to 0.1 seconds and native schedule messages refresh official state.

When the game replays a complete schedule after `/reload`, markers restore their official `due`, `up` or `dead` appearance at their native positions. The clock remains visible with valid time and duration even while the schedule is missing; skulls, glow and checkmarks stay hidden until a complete live schedule or eligible handoff is available. Unused pooled markers and clock release also hide all three visuals. Pausing does not advance marker state through an independent clock, and a new run's schedule restores the corresponding native states. Native tables remain read-only. This supersedes the prior elapsed-time checkmarks; the handoff below is the later exception to the original no-persistence policy. No tests, syntax checks, validation, addon execution or game startups were run for this edit.

## Reload-only saved boss schedule — 2026-10-15

The user requested that an already-received complete boss schedule survive `/reload`. The addon keeps a normalized schedule copy and minimal native continuity fields in memory. Only immediately before calling the wrapped real `_G.ReloadUI` does it write `SurvivorsDragonUiBossSchedule`. The next initialization consumes and immediately clears that SavedVariable. Normal world leave/logout, ready/run reset and a new `AZSZONE` invalidate the in-memory handoff; the leave triggered by the wrapped reload preserves it for initialization. This explicitly supersedes the earlier prohibition on persisting a schedule, without changing geometry-only layout storage or session-only chat capture.

The addon always prefers a complete live schedule. A handoff supplies markers only after current native data recovers an active phase, valid elapsed time/duration and expected boss count, with matching duration/count, nonregressing raw `AZS_RUN.t` and exact `bs`/`bk` counters. If those boss counters change, the handoff is discarded and markers wait for a fresh complete schedule. No elapsed-time inference changes `due`, `up` or `dead`, and no live encounter state is saved. The native clock, independent HUD readiness and 0.1-second list/geometry refresh remain unchanged.

The API has no documented run identifier, so these checks provide best-effort continuity rather than proof of run identity. This is a one-initialization handoff through the hooked native reload path, not a general cache across game sessions. Calls that bypass the hooked `_G.ReloadUI` path have no handoff guarantee. Missing, incompatible or outdated handoffs still require a complete `AZSBOSSES` replay; unchanged encounters and other missing facts also remain client replay requirements. A rejected handoff leaves markers hidden while a valid custom clock stays visible. Full reliable snapshot replay remains the owner-side solution.

No local validation, tests, syntax checks, addon execution or game startups were run. The persistence and reload lifecycle have not been verified in the packaged game.

## Layout restoration is separate from native-data recovery — 2026-10-15

The user subsequently authorized layout movement/resizing and then replaced its modifier-key trigger with `/sdui` edit mode. While editing, left-drag a group's body to move it or a corner icon to resize it. Repeated `/sdui` calls keep editing open. Outlines and corner icons appear only during this mode, with hidden HUD groups editable without revealing inactive targets or encounters; main-menu and Copy controls appear only while their windows are shown. A single centered Confirm button saves all pending changes and locks the layout. HUD groups use independent uniform scale to preserve artwork proportions; chat and Copy use actual width and height for text wrapping and viewport layout, without font scaling. Cast-bar and quest-watch displays are removed.

The `SurvivorsDragonUiLayout` SavedVariables table stores only confirmed geometry: locations, HUD scale and chat/Copy dimensions. Dragging/resizing stages draft changes without saving on drop; only Confirm stores them. Unconfirmed edits are discarded on world leave, logout and `/reload`, and the last confirmed layout returns. Each native HUD replacement continues waiting independently for its required official data. Timer and boss-health group geometry is independent. Action bar, XP and tally retain matching default widths and their default order, but each can be moved and resized independently.

`/sdui reset` immediately clears all saved geometry, discards drafts, exits editing and restores the default position and size for every registered group, including currently hidden groups. It does not replay or cache native clock, schedule, encounter or counter state; it does not change the separately saved SCT mode. Chat still defaults to the bottom-left corner with opacity 0. Entering layout editing, moving or resizing it does not uncover faded history or alter fading; mouse-wheel history navigation remains available, including its existing SHIFT fast-scroll behavior. `/copy` still opens the session-only raw capture window.

Geometry persistence remains separate from the reload-only schedule handoff and does not change the remaining game-owner snapshot replay requirements. No tests, syntax checks, validation, addon execution or game startups were run for these layout edits.
