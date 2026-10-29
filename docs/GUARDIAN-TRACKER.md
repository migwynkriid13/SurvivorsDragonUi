# Guardian tracker

The tracker uses selected design **04**: the published quest-tracker header above
an open list. The header contains its medallion and **GUARDIANS** title, with no
alive count or minus/plus button. The title uses the space previously reserved
for the button.

`/sdui` → **Guardian tracker** has **Show dead**, on by default. On shows all
accepted lairs, including respawn timers, due and empty rows. Off shows only
native `asleep` or `awake` guardians, including every guardian in combat. Both
choices retain native order. With accepted lairs but no living guardians, the
filtered view keeps its header; the view hides when no accepted lairs exist.
Full roster data, timers and guidance data remain underneath this display filter.

Design **09** supplies timer-bezel health bars only for native `awake` guardians
with valid current health. Resting guardians are labelled **Alive**. When the
native respawn countdown reaches zero, the row optimistically displays **Alive**
in the same green instead of Due. This caption does not change native occupancy,
the Show dead filter or health availability. Combat bars
show native current / maximum health by default with the regular boss-bar red fill and white
DEFAULT 12 text. Both views share `core/widgets.lua` style/text helpers; the
tracker has no Fighting caption, and health percentages are off by default. Missing health stays text-only,
and a prior bar is cleared when its row stops fighting or is filtered out.

**Show current health** and **Show maximum health** in **Guardian tracker** are
both on by default. Both on shows `current / maximum`; either alone shows its
value without a slash. With percentages off, both off hides only the health text, preserving the fill
and other guardian status captions. Boss bars has an independent pair of controls.
The normalized `guardianShowCurrentHealth` / `guardianShowMaximumHealth` booleans
use the existing display table, live preview, Confirm, Cancel/discard, profiles
and both full resets. Missing or invalid values and resets use true.

**Shorten health numbers** in `/sdui` → **Encounters** → **Guardian tracker** also
defaults on. Off shows full whole-number health, such as `166983 / 331328`,
without K/M/B/T suffixes or exponent notation. The independent `guardianShortHealth`
boolean shares the same preview/save/discard/profile/reset lifecycle and true
fallback. A format change clears the existing bounded health-measurement slots
and reflows through the existing visible refresh. It adds no row, drawing region
or updater; hidden trackers defer the work. Boss and unit-frame choices remain
independent, and health visibility, values and fills stay intact.

Health text caches use only the latest effective values. Width measurements
reuse one current entry per copied roster slot and retry unavailable metrics;
option, scale and language changes discard them. All health text choices off skips health
formatting and measurement and actually hides the existing health label.
The pill's two end caps keep their minimum non-overlapping span.

**Show health percentage** defaults off and uses normalized
`guardianShowHealthPercentage` in the same display table and transaction.
Missing/invalid values and both resets use false. On appends a rounded whole
percentage to the existing label, such as `50 / 100 (50%)`; with both numeric
values hidden it shows only `50%`. The ratio uses received full health before
shortening or current/maximum hiding, clamps to 0–100%, and requires a finite
nonnegative current value and finite positive maximum. It shares the existing
pill, font, changed-text cache, measurement slots and visible controller. Turning
off all three text choices hides only the label. Hidden views defer formatting
and measurements; percentages add no gameplay frame, region, updater or asset.
While enabled, the health column receives its measured text width within the
existing saved tracker width, retaining the minimum name space and pill-cap span.

Each existing row also caches its latest status caption by received lair key,
status, rounded native respawn second and language. Repeated tenth-second
refreshes within one displayed second reuse the string. Row retirement, health
presentation, visibility, language and relevant option changes clear that cache;
actual label comparisons still repair changed or failed native text writes.
Health formatting, native countdowns, row order and update cadence stay intact.

The separate boss-health group shows only bosses by default. Enable
**Guardians in boss bar** in `/sdui` → **Boss bars** to include fighting guardians. This
does not change target health, the tracker, guidance or map markers.
`guardiansInBossBar` is a normalized boolean in the existing
`SurvivorsDragonUiDisplay` table; missing or invalid values use `false`. Existing
saved boolean choices remain unchanged. The shared
display lifecycle previews it live, saves only with Confirm, discards drafts on
Cancel/world leave/logout/reload, and restores off through both full resets.

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
screen top, with each health pill's right edge aligned beneath the minimap's
default right edge. The root's horizontal anchor uses shared static
`DFRL.minimapDefaults.right`, compensating for the existing row inset and health
pill's right offset at the default scale. The pill anchor and default calculation
share `HEALTH_RIGHT_OFFSET`; neither follows moved or resized minimap geometry.
Width changes reapply this default edge only when no confirmed or draft position
exists; custom positions stay independent.
The Layout left/right side handles set width from **120 to 960**, with **240** as the default, without scaling icons, fonts or rows. Corner handles still scale proportionally. Cached natural caption/health widths guide the columns: wide layouts retain the status column's natural width and give extra space to names; narrow layouts compress both. Long text can clip at small widths. Names retain at least 24 units; status retains at least 42 plus its eight-unit pill allowance, so the two 25-unit end caps never overlap. The measured header height retains its existing sizing.

Top/bottom handles choose 1–40 visible slots; scroll over the tracker or its editor outline for further rows. The `guardianRows` display preference defaults to zero, retaining the original automatic full list, including after resets. Only the selected slice is painted; the complete accepted native roster and countdowns remain available. An explicit slot count retains the selected viewport height even with fewer accepted rows.

Width is stored with the existing Layout geometry; the old `guardianWidth` display field and settings slider are removed. Row capacity uses existing display normalization. Both use shared preview, Confirm, Cancel/world/logout/reload discard, profiles and full resets. Width previews reuse cached caption/health requirements, without a metadata scan. Hidden views update required root geometry only, deferring row/header painting to the existing controller. No new command, alert, sound, SavedVariable, dependency or updater is added.

`guardianShowDead` is a normalized boolean in the existing display table. Missing
or invalid values and both full resets use true; explicit false choices remain
false. It previews through the existing view controller, saves only with Confirm,
discards with Cancel/world/logout/reload and participates in profiles. Filtering
clears removed pooled-row health and fits the frame to the remaining rows. The
header and rows remain click-through, with mouse-wheel input for viewport scrolling and no tracker hover popups. Shared
layout handles still support editing. Existing
guardian waypoints and map/minimap markers keep their appearance and independent
guidance control.

## Minimap timers

In `/sdui` → **Minimap**, enable **Show guardian timers** to see the respawn
countdown below each defeated guardian icon. It is off by default. Enabling it
also keeps defeated icons visible; **Guardian guidance** must remain on.
Turning it off leaves **Keep defeated guardian icons** in control of those icons.
Living guardians and lairs with unknown respawn times have no timer.

Each countdown uses gold DEFAULT 8.6 outlined text with a black shadow, centered
one unit below its existing 20-unit icon. Its explicit 64-by-15 text box is
required by this client's FontString layout; it does not enlarge the pin or its
hover bounds. Font readiness accepts a resolved native face with the requested
size and outline, using the same readback rule as meter labels instead of
requiring the requested font alias to round-trip unchanged.
It shows `m:ss`, including `0:00` when
the native countdown is due; zero does not invent a returned guardian. The
existing guardian roster's accepted run-clock anchor supplies the same bounded,
pause-aware remaining time as the tracker, without reading guardian health.
Missing or regressed run time retains the received countdown.

The normalized `guardianMinimapTimers` boolean lives in the existing display
table. Missing/invalid choices and both full resets use false. Shared live
preview, Confirm-only saving, Cancel/world/logout/reload discard and profiles
apply normally. Its caption and hint have all fourteen source/runtime translations.
Only accepted empty-lair minimap copies gain the received non-negative `left`.

One label is allocated lazily per pooled pin only when a valid enabled timer is
first shown. The ten-Hz/deferred refresh samples the official run time once for
visible countdown candidates; per-frame projection does no timer work. Formatting
and text writes occur only when the displayed second changes. Disabled/hidden
timers skip clock reads, formatting and allocation. Recycle, unknown countdowns,
living replacements and roster retirement clear the old label. No texture,
asset, frame, event, updater or SavedVariable is added. CI-only mocks cover these
boundaries, explicit text dimensions and resolved font paths; local work uses
source review and pinned formatting without game execution.

## Minimap names

Hover a guardian medallion on the minimap to see its name beside the cursor. The name comes from
the accepted native lair snapshot, including retained defeated markers when the
game supplies a name. A missing name gets no invented replacement. This does
not enable hover popups on the guardian tracker itself.

Markers remain mouse-transparent. The existing ten-Hz/deferred waypoint refresh
samples the native cursor once, converts it through minimap scale/center, and
tests the already drawn 20-unit marker bounds. No mouse handler, click/wheel
forwarder, new polling driver or extra hover frame is needed. The shared native
`GameTooltip` keeps its normal styling and Layout scale/visibility. Guardian pins
register once with the existing icon-owner registry's `cursor` placement, so
the shared tooltip controller uses `PlaceHoverAtCursor` even when the global
Tooltip at cursor option is off. Other tooltip owners retain their own choices.
The existing visible-tooltip updater follows the pointer with changed-only
anchors and native screen clamping; no second positioning driver is added.
An unchanged pin/name skips content writes; another owner's tooltip is never hidden or
reclaimed. Leaving the marker, recycling, minimap hiding, guidance off and
world/zone cleanup clear only this owned hover. Tooltip hiding and editing
suppress it, and unhiding does not replay a prior hover before re-entry.

Hover names use only the optional native name in accepted minimap point copies;
they add no raw getter, translation, asset, setting, saved state or full
world-map overlay. Pin OnHide clears an owned tooltip immediately. CI-only source-extracted
mocks cover names, scaled hit bounds, unchanged writes, missing names, retiring
pins, foreign ownership and Tooltip/editor suppression. Placement mocks use the
production owner-routing functions and verify the guardian cursor override plus
ordinary Layout/icon/global-cursor behavior. Local work is source
review and pinned formatting; live hover/input behavior remains unverified.

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
`Remaining(left, now)` shares that calculation with accepted minimap copies,
returning nil for an unready roster or unknown/negative `left`; the caller samples
official run time once without requesting a health-bearing snapshot.

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
`modules/ui/guardian_tracker.lua` after it, and the selected `guardians/Header.blp` crop.
Existing timer textures supply the health bezels. `core/layout.lua` adds the
translated group label; the source and generated catalogs include nine tracker
captions in all fourteen languages. The version advances once from `3.2.19-survivors` to
`3.2.20-survivors` for the shipped Lua change. The gallery, renderer and research
notes remain outside `packaging/runtime-files.json`. Only the selected header crop joins the runtime payload.
Minimap state textures remain for native zoom controls. Source sheets and
comparison designs remain outside it.

The currently installed executable could not be read by the existing pinned
full-catalog extractor. The addon-caption rows were generated directly
from the TSV into the existing fourteen UI sections, preserving all reviewed
native/effect/identity catalogs and aliases. No new client source or catalog order
is accepted. A later full generation still uses the documented pinned client.

Source/diff inspection, data preparation and pinned formatting only. No local
tests, standalone syntax/validation checks, addon execution or game startup were
run. Artwork decoding and static compositions are design preparation. GitHub
Actions static checks do not establish packaged-game behaviour.
