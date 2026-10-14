# Native API recovery after UI reload — 2026-10-14

The user reported that `/reload` restores the native timer and other HUD parts instead of reconnecting the addon displays. No game startup, addon execution, test, syntax check or validation was run for this investigation or its edits.

## Read-only evidence and limit

Embedded source/log strings in the local packaged `AzerothSurvivors.exe` show that UI reload rebuilds the Lua VM and the API initialization creates fresh state tables. The official documentation says `AZS_ZONE` is sent once per run and schedule/unit lists are sent only when they change. This supports a missing-snapshot replay explanation, but no live reload trace was collected to prove the exact failing engine path.

The existing addon retried official getters every frame, but required valid clock and zone-derived duration before refreshing any replacement. Thus missing zone data also blocked otherwise valid tally and encounter data. Fresh empty API tables could additionally be mistaken for a received empty encounter list.

## Addon changes

- Read the phase first, then use official `AZS_RUN.fin` if `AZS_GetRunLength()` has not recovered. Both values describe the native final-boss time.
- Reconnect clock, tally and encounter displays independently, preserving each native HUD part until its replacement has valid data.
- Require `AZS_UNITS_UPDATED` before accepting an initially empty encounter snapshot.
- Keep retrying the official getters and responding to native addon messages. Do not reconstruct elapsed time, guess boss markers, persist private caches or add SavedVariables.

The addon does not change the engine, parser, launcher or server. These source changes remain unverified live.

## What the game owner needs to provide

For reliable `/reload` recovery, including while paused or with unchanged lists, reinstall the official API parser/getters in each new Lua VM, then force a full current-state replay after the parser is registered. At minimum replay `AZSZONE`, `AZSRUN`, `AZSBOSSES` and `AZSUNITS`; ideally replay all API prefixes. Replay must occur even when the native state has not changed.

The supplied API documents no request/resync function that the addon can invoke. Without the native replay, missing once-per-run facts or unchanged encounter lists cannot be recovered faithfully by addon polling alone. Native HUD fallback stays available until those values arrive.

## Missing boss-spawn lines — 2026-10-15

The user subsequently reported that the custom progress timer returns after `/reload` but its vertical boss-spawn markers disappear. The native clock and recurring `AZS_RUN.fin` can recover before the complete schedule. The previous marker update treated a fresh empty `AZS_SCHEDULE` as an empty set of spawn times, while clock takeover required only valid time and duration. That allowed a replacement lacking the native next-boss information to hide the original clock HUD.

The custom clock now requires a complete valid native schedule before takeover. It checks the expected boss count from `AZS_RUN.bt` or `AZS_ZONE.bt`, unique numeric schedule indices, positive `at` times within the native duration, and a final-boss flag/time agreeing with that duration. Every complete schedule entry contributes a marker regardless of `due`, `up` or `dead` state. Markers are rendered before hiding the native clock. An absent or incomplete schedule releases the custom clock and restores its captured native visibility, without overriding an originally hidden clock preference. Tally and encounter recovery remains independent.

This addresses the addon-side premature takeover and blank-marker substitution. It cannot recreate intermediate spawn times from the final-boss duration or the future-only `AZS_GetUpcomingBosses()` list. The game must replay the complete `AZSBOSSES` snapshot into each new Lua VM, even when paused or when boss states are unchanged. Polling the official API and responding to its existing messages remains the recovery path; there is no documented request/resync function, private persisted snapshot, hardcoded schedule or SavedVariables fallback.

No tests, syntax checks, validation, addon execution or game startups were run for this edit. Full marker restoration after `/reload` has not been verified live.
