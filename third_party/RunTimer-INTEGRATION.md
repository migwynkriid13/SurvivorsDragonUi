# Native run and encounter HUD integration

Implemented against the owner's official **Azeroth Survivors 0.87.0+** addon API. The source document is saved verbatim in `docs/AzerothSurvivors-Addon-API.md`; decisions and release context are in `docs/API-NOTES.md`.

## Runtime

Users install only DragonSurvivorsUI. `modules/ui/run.lua` reads the official Lua getters already provided before addon loading. No companion, client patch, alternate launcher, native memory access or personal-computer dependency is required.

- Read `AZS_GetPhase()` first to avoid retained previous-run tables.
- Read `AZS_GetRunTime()` on each OnUpdate; its native interpolation and pause handling are authoritative.
- Use `AZS_GetRunLength()` for the run bar maximum, falling back to the phase-gated native `AZS_RUN.fin` if it is empty. Use `AZS_SCHEDULE[*].at` for every spawn marker, including past spawns; never guess missing markers.
- Read `AZS_GetBosses()` and `AZS_GetGuardians()` for separate spawn-id keyed health rows, using `hp` and `hpm`. Include guardians only when `awake` is true or 1; sleeping lairs are not engaged encounters.
- Refresh lists on relevant addon messages and every 0.1 seconds. The refresh accumulator never advances run time.
- Read `AZS_RUN.kills`, `AZS_RUN.gold` and `AZS_RUN.chest` for a gold tally bar directly beneath the XP bar. Match its total outer width to the seven-button action bar artwork and XP bar, with three equal sections, centered numeric values and in-game icons. `chest` is the next cache price, not the opened-cache count (`ck`). Missing counters leave the native tally available; zero is valid.
- Hide only the original `clock`, `bosses` and `tally` parts through `AZS_SetHudShown` after their replacements are ready. Guardians share the native boss group, so engaged guardians also receive replacement health pills.
- Preserve and restore original HUD visibility on missing data, world leave and logout. Older clients lacking these APIs retain their native HUD.
- Reconnect clock, tally and encounters independently after `/reload`. Require `AZS_UNITS_UPDATED` before accepting an initially empty encounter snapshot, so native boss bars stay available while the new VM waits for data.

One blue top-center run pill and red encounter-health pills use the original Blizzard WidgetStatusBar artwork and DEFAULT font. Boss rows are not deduplicated by name and have no addon-imposed four-row cap. Removed encounters clear and recycle their frames.

Elwynn's native schedule remains 3, 6, 9, 12 and 16 minutes, with a 960-second maximum. Other zones follow their own official native duration and schedule. After the final-boss time the fill stays full while the native elapsed label can continue in endless mode.

There is no external snapshot/sequence/acknowledgement global, private `hpMax` schema or three-second missing-packet timeout. The owner only sends updates when values change; an unchanged paused state must remain visible.

## Status

The official API covers the required data and display controls. The user confirmed the timer and encounter pills work in-game and supplied a screenshot. The subsequent awake-only guardian filter, gold tally bar and reload-reconnection changes were written without tests, syntax checks, validation or game startups and remain unverified live. This integration requires a game build implementing the 0.87.0 API. Historical REA observations are separate from this official API implementation.

Full `/reload` recovery while paused or with unchanged lists also needs the game to reinstall its API parser/getters and replay current snapshots to the new Lua VM after the parser is registered. No request/resync API is documented, and this addon does not modify the engine. Details are in `docs/RELOAD-API-NOTES.md`.
