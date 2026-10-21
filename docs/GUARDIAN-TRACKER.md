# Guardian tracker

The tracker uses selected design **04**: the published quest-tracker header above
an open list. A minus/plus toggle occupies the old count position; no alive count
is displayed. The icons reuse the minimap's gold plus/minus artwork and state
textures. **Plus** means collapsed and shows only accepted living guardians
(`asleep` or `awake`), including every guardian in combat. **Minus** means expanded
and shows all accepted lairs, including respawn timers and empty rows. Both
modes retain native order. With accepted lairs but no living guardians, collapsed
mode keeps its header available so the user can expand it. The view hides when
no accepted lairs exist. Full roster data, timers and guidance data are retained
underneath this display filter.

The normal plus artwork has a two-source-pixel left inset relative to the minus
and other plus states. The shared styling helper's optional glyph alignment
corrects that single texture by `2 / 32` of the button width. Toggle/header/root
anchors and the hit box stay fixed through collapse, expansion, hover and press;
the full texture canvas and other state positions are preserved.

Design **09** supplies timer-bezel health bars only for native `awake` guardians
with valid current health. Resting guardians are labelled **Alive**. When the
native respawn countdown reaches zero, the row optimistically displays **Alive**
in the same green instead of Due. This caption does not change native occupancy,
the collapsed filter or health availability. Combat bars
show native current / maximum health with the regular boss-bar red fill and white
DEFAULT 12 text. Both views share `core/widgets.lua` style/text helpers; the
tracker has no Fighting caption or percentage. Missing health stays text-only,
and a prior bar is cleared when its row stops fighting or is filtered out.

The separate boss-health group includes fighting guardians by default. Turn off
**Guardians in boss bar** in `/sdui` → **HUD** to leave only bosses there. This
does not change target health, the tracker, guidance or map markers.
`guardiansInBossBar` is a normalized boolean in the existing
`SurvivorsDragonUiDisplay` table; missing or invalid values use `true`. The shared
display lifecycle previews it live, saves only with Confirm, discards drafts on
Cancel/world leave/logout/reload, and restores on through both full resets.

`modules/ui/run.lua` filters only the guardian list from its encounter rows,
retaining the received-unit-snapshot gate and native boss validation. Boss-only
mode does not require or read the excluded guardian list. The existing row
retirement clears removed guardian health/debuffs/tooltips and reflows bosses on
the next HUD update. A valid empty boss list still takes over native `bosses`,
which also contains guardians, so native guardian bars cannot reappear when only
guardians are fighting. Native visibility restoration and data-unavailable
fallbacks retain their existing lifecycle.

Move, scale or hide **Guardian tracker** through the shared `/sdui` Layout
controls. Confirm saves only its geometry and optional hidden flag in the existing
layout table; Cancel, world/reload discard and both resets use the normal shared
lifecycle. Its default scale is `0.85`, 15% smaller than the original size. The
name/status column gap is `14.4` units instead of `16`, retaining the name column
and measured translated status widths. Its top stays 252 UI units below the
screen top, with the toggle centred beneath the minimap's default minus button.
That horizontal anchor comes from shared static minimap appearance metadata,
not moved or resized minimap geometry. Width changes reapply this default edge
only when no confirmed or draft position exists; custom positions stay independent.
The tracker adds no display setting,
command, alert, sound, SavedVariable or dependency. Its header toggle choice is
session-only and starts expanded on reload; it survives run/world changes within
the session. Both shared resets restore expanded. The button is disabled during
layout editing so it does not interfere with dragging. Collapsing or filtering
clears pooled row health, then fits the frame to visible rows; the header icon
changes between minus and plus immediately. Guardian rows are mouse-transparent
and have no hover popups. The header toggle retains its explanatory tooltip and
the shared layout handles still support editing. Existing
guardian waypoints and map/minimap markers keep their appearance and independent
guidance control.

## Shared acceptance and cleanup

`modules/ui/guardians.lua` registers `DFRL.guardians` before Waypoints initializes.
The existing `modules/map/waypoints.lua` reader remains the only owner of raw lair
acceptance. After accepting a received, phase-gated native lair snapshot, it passes
copies of **all** lairs to `AcceptLairs`, including vacant ones. Navigation still
receives only its existing occupied-lair coordinate copies. Cache behaviour is
unchanged. No second raw lair poller or parallel lifecycle is introduced.

The roster accepts unique positive lair indexes, the native `asleep`, `awake` and
`empty` states, positive spawn ids for held lairs, and id zero for empty lairs.
Malformed roster data clears the roster; it never supplies invented values.
Optional numeric fields must be finite. Native names are preserved. Every
accepted lair is retained in native order.

Waypoints clears the roster through its existing active/inactive, zone, invalid
snapshot, world-leave and logout paths. Guidance visibility drafts do not clear
accepted data. Unchanged and paused snapshots do not expire. The existing
same-batch packet-generation and blocked-reference rules still apply; a fresh
same-prefix packet can release an in-place native table. Reload starts with an
empty roster and needs official snapshot replay. No gameplay data is persisted.

The API supplies no run id. These observed boundaries provide best-effort
isolation, not proof of full run identity. The roster deliberately follows the
existing reader's readiness, including its required world coordinates for held
lairs. It does not create an independent fallback when that reader is unavailable.

## Consumer API

`DFRL.guardians.GetSnapshot()` returns a fresh copy. Its `status` is `inactive`
outside the run phases, `unavailable` before acceptance, or `ready` after an
accepted snapshot; a ready empty list means zero lairs. `revision` advances on
acceptance and retirement. `generation` changes when an accepted roster is
retired. `zone`, when available, contains copied native `key`, `name` and `map`.

Each `rows` entry contains `index`, `id`, `key` (`index:id`), native `state`,
optional native `name`, `left`, world/map coordinates, and a semantic `status`:

| Status      | Native evidence                                          |
| ----------- | -------------------------------------------------------- |
| `asleep`    | A held lair with state `asleep` and a positive spawn id. |
| `fighting`  | A held lair with state `awake` and a positive spawn id.  |
| `returning` | An empty lair with positive native `left`.               |
| `due`       | An empty lair whose native `left` is exactly zero.       |
| `empty`     | An empty lair without a known non-negative return time.  |

`counts` includes `total`, `living`, `asleep`, `fighting`, `returning`, `due` and
`empty`. The view translates its captions through the existing fourteen-language system;
backend status keys and actual native names are not English UI captions. Caption
widths are measured with the real DEFAULT face across every supported language,
including populated time/health fields. Native names occupy a separate
bounded column without hover popups.

Health is read once per consumer snapshot through the official
`AZS_GetGuardians()`, only during an active run and after `AZS_UNITS_UPDATED`
exists. It joins by exact spawn id and never by name. Invalid or duplicate unit
ids supply no health. Available values are copied as `hp`, `maximum` and a bounded
`healthFraction`; missing health remains unknown. Retirement blocks the old unit
table/stamp until fresh unit evidence or an observed `AZSUNITS` packet arrives,
including parsers that reuse a table at the same UI timestamp. A lair's position
is its fixed lair, not the guardian's position while fighting.

For positive native `left`, `remaining` subtracts at most 1.5 seconds of progress
from the official `AZS_GetRunTime()` since acceptance. This clock stops during
pause and card choice. Missing or regressed clock values leave the native
countdown unchanged. Re-reading the same snapshot never resets its time anchor.
The native stamp and packet generation, not GetTime receipt rounding, identify a
new sample. There is no wall-clock countdown, respawn-period guess or invented
progress fraction. A cosmetic zero remains `returning` until native `left == 0`
confirms `due`; a return requires an actual occupied snapshot.

`GetChanges(afterRevision, afterGeneration)` returns copied observations since a
consumer's cursor, with `revision`, `generation`, `entries`, `reset` and, for a
valid cursor, `truncated`. Initial/replayed snapshots establish a baseline and
produce no notices. Observations are `vacated`, `returned`, `replaced` or `state`;
missing rows never establish a death. Up to 64 observations are retained, and
cursor truncation is explicit, including removal of part of a multi-row revision.
Consumers must baseline on `reset` and resynchronise on `truncated`. The foundation
never converts these observations into chat messages or sounds.

## Designs and payload

[The gallery](designs/guardian-tracker/index.html) has 20 static proposals using
published WoW artwork and existing addon artwork. Artwork recipes and exact
source evidence are in [ARTWORK.md](designs/guardian-tracker/ARTWORK.md). All names,
values and selections in the previews are samples. The preview font substitutes
for DEFAULT and does not establish game glyph metrics.

The runtime manifest adds `modules/ui/guardians.lua` before the waypoint reader,
`modules/ui/guardian_tracker.lua` after it, and the selected `guardians/Header.tga` crop. The toggle reuses already-shipped
minimap textures through the shared styling helper. Existing timer textures supply the health bezels. `core/layout.lua` adds the
translated group label; the source and generated catalogs include nine tracker
captions in all fourteen languages. The version advances once from `3.2.19-survivors` to
`3.2.20-survivors` for the shipped Lua change. The gallery, renderer and research
notes remain outside `packaging/runtime-files.json`. Only the selected header crop joins the runtime payload; the minimap state
textures already ship. Source sheets and
comparison designs remain outside it.

The currently installed executable could not be read by the existing pinned
full-catalog extractor. The addon-caption rows were generated directly
from the TSV into the existing fourteen UI sections, preserving all reviewed
native/effect/identity catalogs and aliases. No new client source or catalog order
is accepted. A later full generation still uses the documented pinned client.

No local validation, tests, syntax checks, formatting tools, addon execution or
game startup are authorized or run. Artwork decoding and static compositions are
design preparation. Only the existing GitHub Actions static checks are used for
code verification; they do not establish packaged-game behaviour.
