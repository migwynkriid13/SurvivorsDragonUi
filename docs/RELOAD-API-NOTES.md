# Native API recovery after UI reload — 2026-10-14

The user reported that `/reload` restores the native timer and other HUD parts instead of reconnecting the addon displays. No game startup, addon execution, test, syntax check or validation was run for this investigation or its edits.

## Read-only evidence and limit

Embedded source/log strings in the local packaged `AzerothSurvivors.exe` show that UI reload rebuilds the Lua VM and the API initialization creates fresh state tables. The official documentation says `AZS_ZONE` is sent once per run and schedule/unit lists are sent only when they change. This supports a missing-snapshot replay explanation, but no live reload trace was collected to prove the exact failing engine path.

The existing addon retried official getters every frame, but required valid clock and zone-derived duration before refreshing any replacement. Thus missing zone data also blocked otherwise valid tally and encounter data. Fresh empty API tables could additionally be mistaken for a received empty encounter list.

## Addon changes

- Read the phase first, then use official `AZS_RUN.fin` if `AZS_GetRunLength()` has not recovered. Both values describe the native final-boss time.
- Reconnect clock, tally and encounter displays independently, preserving each native HUD part until its replacement has valid data.
- Require `AZS_UNITS_UPDATED` before accepting an initially empty encounter snapshot.
- Keep retrying the official getters and responding to native addon messages. Do not reconstruct elapsed time, guess boss markers or persist private native-data caches. The separately authorized layout SavedVariables contain positions only.

The addon does not change the engine, parser, launcher or server. These source changes remain unverified live.

## What the game owner needs to provide

For reliable `/reload` recovery, including while paused or with unchanged lists, reinstall the official API parser/getters in each new Lua VM, then force a full current-state replay after the parser is registered. At minimum replay `AZSZONE`, `AZSRUN`, `AZSBOSSES` and `AZSUNITS`; ideally replay all API prefixes. Replay must occur even when the native state has not changed.

The supplied API documents no request/resync function that the addon can invoke. Without the native replay, missing once-per-run facts or unchanged encounter lists cannot be recovered faithfully by addon polling alone. Native HUD fallback stays available until the corresponding replacement's required values arrive; marker availability does not gate a valid custom clock.

## Missing boss-spawn lines — 2026-10-15

The user subsequently reported that the custom progress timer returns after `/reload` but its vertical boss-spawn markers disappear. The native clock and recurring `AZS_RUN.fin` can recover before the complete schedule. The previous marker update treated a fresh empty `AZS_SCHEDULE` as an empty set of spawn times, while clock takeover required only valid time and duration. That allowed a replacement lacking the native next-boss information to hide the original clock HUD.

The first response required a complete valid native schedule before displaying or taking over the custom clock. The complete check uses the expected boss count from `AZS_RUN.bt` or `AZS_ZONE.bt`, unique numeric schedule indices, positive `at` times within the native duration, and a final-boss flag/time agreeing with that duration. Every complete schedule entry contributes a marker regardless of `due`, `up` or `dead` state.

The addon cannot recreate intermediate spawn times from the final-boss duration or the future-only `AZS_GetUpcomingBosses()` list. The game must replay the complete `AZSBOSSES` snapshot into each new Lua VM, even when paused or when boss states are unchanged. Polling the official API and responding to its existing messages remains the recovery path; there is no documented request/resync function, private persisted snapshot, hardcoded schedule or saved native-data fallback.

## Full progress-bar regression and correction — 2026-10-15

The user reported that `/reload` now removes the entire custom top bar, whereas previously only its vertical boss-spawn lines were missing. The new schedule readiness condition gated the whole custom clock, so an absent or incomplete `AZS_SCHEDULE` called `ReleaseClock()` even with valid native elapsed time and duration.

Clock display and native clock takeover again depend only on a valid phase, native elapsed time and native duration, including the phase-gated `AZS_RUN.fin` duration fallback. The complete schedule check now gates marker drawing alone. Missing schedule data clears marker textures without hiding the progress bar or time text; the native clock stays replaced to avoid duplicate displays. Markers rebuild when the complete official snapshot arrives. Invalid phase/time/duration still releases the replacement and restores captured native visibility, preserving an originally false preference. Tally and encounter recovery remains independent.

This corrects the addon-side full-bar regression without inventing marker times, persisting private snapshots or changing the game. The native replay requirement for complete spawn-line recovery remains.

No tests, syntax checks, validation, addon execution or game startups were run for this edit. Full marker restoration after `/reload` has not been verified live.

## Layout restoration is separate from native-data recovery — 2026-10-15

The user subsequently authorized independent SHIFT + left-drag positions for the UI groups. The `SurvivorsDragonUiLayout` SavedVariables table stores only those positions, so `/reload` can restore the layout while each native HUD replacement continues to wait independently for its required official data. Timer and boss-health group positions are independent. Action bar, XP and tally retain their existing widths and default order, but moving one does not move another.

`/sdui reset` clears all saved positions and restores the default layout for every registered group, including currently hidden groups. It does not replay or cache native clock, schedule, encounter or counter state; it does not change the session-only SCT mode. Chat still defaults to the bottom-left corner with opacity 0, and moving it does not uncover faded history. `/copy` still opens the session-only raw capture window.

Position persistence therefore does not change the game-owner snapshot replay requirement. No tests, syntax checks, validation, addon execution or game startups were run for these layout edits.
