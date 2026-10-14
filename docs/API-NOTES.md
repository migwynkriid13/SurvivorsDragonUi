# Official addon API integration — 2026-10-14

The owner announced native addon support in **Azeroth Survivors 0.87.0**, and the user supplied the official `addon_docs.md`. A verbatim copy is saved as `AzerothSurvivors-Addon-API.md` beside this note.

This supplies everything needed for DragonSurvivorsUI's native run-progress and boss-health replacements, including control over the original HUD. Public users install only the addon; the old external REA companion is unnecessary and excluded.

| Purpose | Official interface |
|---|---|
| Native smooth, pause-aware elapsed time | `AZS_GetRunTime()` |
| Current run lifecycle | `AZS_GetPhase()` |
| Actual zone duration/final-boss time | `AZS_GetRunLength()`, with native `AZS_RUN.fin` fallback |
| All scheduled boss-spawn markers, including past bosses | `AZS_SCHEDULE`, each entry's `at` |
| Every live boss, with stable identity within a run | `AZS_GetBosses()`: `id`, `name`, `hp`, **`hpm`** |
| Guardian bars sharing the native boss-HUD group | `AZS_GetGuardians()`: `id`, `name`, `hp`, `hpm` |
| Kills, current gold and the next cache's gold cost | `AZS_RUN.kills`, `AZS_RUN.gold`, `AZS_RUN.chest` |
| Show/hide native HUD groups | `AZS_SetHudShown(part, shown)` and `AZS_IsHudShown(part)` |
| Immediate state/list refreshes | `CHAT_MSG_ADDON`: `AZSZONE`, `AZSRUN`, `AZSBOSSES`, `AZSUNITS` |

`modules/ui/run.lua` now consumes these APIs directly. There is no invented snapshot global, companion sequence/acknowledgement protocol, independent run clock or heartbeat timeout. The native getter owns interpolation and pauses. The local 0.1-second accumulator only throttles list refreshes.

The official document corrects the earlier assumption that every zone lasts 16 minutes: duration and spawn times are zone-specific. Elwynn Forest remains 960 seconds with spawns at 3, 6, 9, 12 and 16 minutes. Other zones use their native duration and full schedule. The addon keeps past markers and clamps only the fill after the final-boss time, allowing elapsed time to continue in endless mode.

Every live boss and engaged guardian has its own spawn-id key and health pill, with no addon-imposed four-row limit. Guardians are shown only when their documented `awake` flag is true (or native numeric 1); sleeping guardians are omitted. This keeps map-wide dormant lairs from bloating the HUD, while engaged enemies remain visible even at full health. Do not use `enraged` (a low-health state), selection or missing HP as an engagement test. The API's `hpm` maximum-health field replaces the private JSON's old `hpMax` field. All returned native lists remain read-only.

The addon hides `clock`, `bosses` and `tally` only after their replacements are ready; `bosses` includes guardians, so engaged guardians' health is also preserved in the replacement. The clock requires a valid phase, native elapsed time and native duration; its marker schedule is independent. It captures prior HUD visibility and restores it when a replacement's required native data is missing/invalid, on world leave and on logout. Saved game HUD settings are not treated as addon configuration.

The replacement tally is one gold bar whose default placement is directly beneath the XP bar, with its default total outer width matching the seven-button action bar artwork and XP bar. Each of those three groups can be moved and uniformly resized independently, so user resizing can make their displayed widths differ. Three equal sections show centered numeric values with in-game icons and DEFAULT text for kills, current gold and the next cache's gold cost. These come directly from `AZS_RUN.kills`, `AZS_RUN.gold` and `AZS_RUN.chest`; `ck` counts opened caches and is not used as a price. All three required counters must be present and nonnegative; zero is valid. Missing fields release control of the native tally. Native `AZSRUN` messages and the existing 0.1-second poll refresh the values without inventing increments or timing out a paused run.

Phase must be read before using retained tables, which can contain previous-run data outside a run. A nil clock before the first update leaves the original HUD available. Paused/unchanged native state is valid without repeated packets.

After `/reload`, each HUD replacement reconnects independently when its required native data arrives. A missing zone-derived run length can fall back to the current run's official `AZS_RUN.fin`; no local clock or guessed schedule is used. Encounter lists must have `AZS_UNITS_UPDATED` before an empty list can suppress native boss bars. The addon cannot request a full API replay: unchanged lists and paused runs need the game to republish its current state after rebuilding the Lua VM. See [RELOAD-API-NOTES.md](RELOAD-API-NOTES.md) for the static evidence, owner-side requirement and unverified live status.

The API also exposes damage-meter lines, damage taken, spells/cooldowns, buffs, other hero/run statistics, targets and unit kinds. Those extra capabilities are available for future work; the current replacements cover run/encounter bars, the tally and their native visibility.

The supplied release announcement establishes the **0.87.0+** requirement. It does not prove the locally installed executable has been updated. The implementation detects unavailable APIs and leaves the native HUD available. No tests, syntax checks, validation or game startups were run for this change, per the project instruction.

## Independent clock and marker recovery after reload — 2026-10-15

The user reported that `/reload` leaves the run progress bar without its vertical boss-spawn markers. A recovered native clock and `AZS_RUN.fin` can supply elapsed time and duration before `AZSBOSSES` has replayed the complete schedule. The first response made the entire clock wait for that schedule; the user then reported that the whole custom top bar disappeared after `/reload`. That schedule gate has been removed from clock display and takeover.

Marker rendering requires a complete valid `AZS_SCHEDULE`, checked against the native expected boss count from `AZS_RUN.bt` or `AZS_ZONE.bt`. Schedule entries need unique numeric indices, positive spawn times no later than the native run length, and a final-boss flag/time agreeing with that length. The full list is used, including bosses whose state is `due`, `up` or `dead`; `AZS_GetUpcomingBosses()` cannot replace it because that getter excludes past bosses. Native tables remain read-only.

The custom clock displays and takes control of the native `clock` HUD part as soon as the phase, native elapsed time and native duration are valid. A missing or incomplete schedule clears only its marker textures; it keeps the progress bar and time text visible without a duplicate native clock. Complete markers rebuild when the official schedule arrives. Invalid phase, elapsed time or duration releases the custom clock and restores captured native visibility, including an originally hidden game preference. Tally and encounter bars continue reconnecting independently when their own native data is ready.

This corrects the full-bar regression while keeping incomplete marker data separate from valid clock data. It does not reconstruct absent spawn times after a Lua VM reload. Official getters remain polled every frame, list refreshes remain throttled to 0.1 seconds, and native addon messages trigger refreshes. There are no invented markers, independent clock, persisted private schedule or resync command. Complete marker restoration still depends on the game replaying the current `AZSBOSSES` snapshot, including while paused or unchanged. See [RELOAD-API-NOTES.md](RELOAD-API-NOTES.md). This edit was made without tests, syntax checks, validation or game startups and has not been verified live.

## Independent layout geometry — 2026-10-15

The user authorized SHIFT + left-drag on the body of an addon UI group to move it, and SHIFT + left-drag on a corner icon to resize it. Corner icons appear only while SHIFT is held. The remaining groups include independent player/target frames, boss-health group, run timer, action bar, XP, kills/gold/cache tally, micro menu, buffs, minimap and chat, plus the main menu and Copy window while open. Cast-bar and quest-watch displays are removed rather than registered for layout editing.

HUD groups resize by uniform scale, retaining their artwork proportions. Chat and Copy instead change actual width and height to update wrapping and the viewport, while fonts retain their normal size. The defaults remain defined in code, with XP beneath the action bar and tally beneath XP at matching artwork widths; moving or resizing one never changes another. Boss health rows remain together in their own group, independently of the timer.

Only frame geometry (locations, HUD scale and chat/Copy dimensions) is stored in the `SurvivorsDragonUiLayout` SavedVariables table and restored after `/reload`. `/sdui reset` clears it and restores every registered group's default position and size, including groups that are currently hidden. It does not alter native run data, native HUD visibility preferences or the session-only `/sct` mode. `/copy` remains the chat-capture utility; raw capture is still session-only. Chat defaults to the bottom-left corner, keeps opacity 0, and SHIFT moving or resizing does not reveal faded history; only mouse-wheel navigation does that.

Layout persistence never stores phase, clock, schedules, encounters, counters or other native API snapshots. The HUD still requires the same official native data and replay described above. These layout edits were made without tests, syntax checks, validation, addon execution or game startups.
