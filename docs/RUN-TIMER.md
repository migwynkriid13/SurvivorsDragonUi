# Run timer and boss countdown

`/sdui` → **Run timer** starts with **Enable custom run timer**, on by default.
Turn it off to use the game's original timer and next-boss line again. The
matching game option is turned back on too. **Boss bars** has an independent
**Enable custom boss bars** switch, also on by default; turning it off restores
the game's boss and guardian health bars.

**Boss bars** also has **Show current health** and **Show maximum health**, both
on by default. Together they show `current / maximum`; either value alone has no
slash, and turning both off hides the health text while keeping the fill. These
choices apply to every row in this view, including enabled guardian rows. The
Guardian tracker has its own independent pair.

The normalized `bossShowCurrentHealth` / `bossShowMaximumHealth` booleans use the
existing display table and shared preview, Confirm, Cancel/discard, profiles and
both full resets. Missing or invalid values and resets use true. The shared
encounter formatter retains compact K/M/B/T numbers, caches only each label's
current effective values and checks actual text/visibility before writing.

When either switch is off, the settings underneath it are dimmed and inactive.
The timer's preview, font controls and both mode columns fade together; an open
font menu closes. Their selected values are kept and become available again
when the custom display is enabled. The enable switches stay active.
Availability follows the current draft, including profile loads and Cancel.
The editor applies its existing 45% dimmed style only when availability changes,
without an animation updater or another saved choice.

**Font** and **Size** share one row below the timer switch, followed by
**Outline** and **Black shadow**. These choices apply to both timer captions.
Below them, **Regular runs** has four compact checkboxes and **Endless** has
three. Endless has no maximum zone time:

| Control           | Regular runs | Endless     |
| ----------------- | ------------ | ----------- |
| Run text          | On           | On          |
| Current time      | On           | On          |
| Maximum zone time | On           | Unavailable |
| Boss countdown    | Off          | On          |

Each mode's **Run text** controls only the translated `RUN` word. **Current
time** independently controls elapsed time; **Maximum zone time** independently
controls the regular run's limit. Turning both time components off with
**Run text** on shows the `RUN` word alone. Turning every left-caption component
off hides that caption. **Boss countdown** remains independent.

All choices preview immediately and save only with Confirm. Cancel, world
leave, logout and reload discard unconfirmed choices. Both full resets restore
the defaults above. Changing a choice does not move or scale the timer.

## Heroic affixes

On the 0.125.0 API, the run timer shows the current run's Heroic affixes in one
centered row beneath the bar. The selected **04 Rally and rupture** pictures
use the same neutral circular rim as equipped jewelry, tinted red while
retaining its original shading and alpha. There is no added flat outline.
Hovering an icon shows the game's name and description in the active language.
The run timer's existing move, scale, width and Hide frame controls own the row;
its Layout outline includes the icons without changing saved geometry.
Unpositioned boss bars reserve 33 more units below their usual 77-unit default
while the affix row is present, keeping the first boss name clear. Confirmed
and draft boss positions retain their shared Layout ownership.

The view reads only received `AZS_ZONE.heroic`, `AZS_ZONE.affixes` and
`AZS_ZONE_UPDATED` after the timer controller's phase check. It preserves the
published English-key order and does not calculate a rotation from difficulty,
date or zone. Empty, unavailable or non-Heroic snapshots hide the row. Unknown
future keys retain their exact label and use the native skull inside the same
rim, without borrowing another affix's description. Duplicate keys display once.

`AZSZONE` clears old presentation and schedules acceptance after native parsing
and the existing new-run handshake. Observed run regressions, inactive phases,
world leave/logout and reload retire the accepted snapshot. A retained old
packet stays blocked until its identity/stamp changes or a fresh zone receipt
arrives. Disabling the custom timer hides its affixes, while re-enabling can use
the current run's snapshot. Shared tooltip hiding/editing/placement and owned
hover cleanup apply; polling never reclaims a foreign tooltip.

Each kind lazily adds one 22-unit hover frame and two textures: its prepared
circular image and the existing jewelry rim. Five-unit gaps and a three-unit
top offset center the row on the bar. One 256-by-64 lossless BLP atlas holds
the three selected images; the separate rim uses `(664,56)-(736,128)` from
`jewelry/Frame.blp` and RGB `(237,35,38)/255`. No label, animation, updater,
event registration, setting or SavedVariable is added. Hidden rows allocate
and paint nothing; successful bindings, labels, UVs and anchors are reused.
Failed artwork retries only on the existing tenth-second refresh.

[Artwork sources and preparation](../third_party/HeroicAffixes-ARTWORK.md#selected-04-and-runtime-preparation)
and [PERFORMANCE.md](PERFORMANCE.md#heroic-affix-row--2026-10-28) record the
source-level costs. CI-only mocks cover the extracted production view and
shared tooltip registry. Local work used source/diff review, artwork preparation
and pinned formatting; live delivery, hover appearance and rendering remain
unverified.

## Update work

With **PERFORMANCE MODE** on, regular progress uses the plain blue fill and
the red Endless state keeps only its plain red fill. Both skip every decorative
fill layer: foam, right-moving streaks, flecks, sparkles, red glints and glow.
Enabling the mode hides any already-active layers immediately. Native progress
continues in whole-second steps; captions and informative markers remain.
Turning the mode off restores the original effects from current state.

Native duration and schedule validation reuse the existing ten-Hz/deferred
publication refresh. Phase changes, run/schedule retirement and reload invalidate
that cache. Raw run time, phase/rollback checks, clock HUD ownership and authored
animation retain their existing frame cadence while the clock is visible.
Boss debuffs read current native effects at ten Hz or a deferred publication;
hovering samples phase/effects immediately before opening the tooltip. Removed
slots clear before opening and changed debuff height reflows at that point.
No private countdown supplies remaining time.

The progress fill advances in whole native run-second steps instead of changing
every rendered frame. Native pause/choice states therefore freeze progress;
native corrections and duration changes still take effect, and reaching the
limit fills the bar exactly even when that limit includes a fractional second.
The existing decorative flow/foam animation keeps its cadence and clips to the
same stepped fill edge. Captions, boss scheduling and marker state continue
using their original native inputs. No private timer or updater is added.

Caption formatting keeps only the latest rounded native times and final labels.
Unchanged values, options and language reuse those labels; disabled components
skip formatting. Option previews rebuild immediately from the latest native
values, while the existing visible refresh still checks scale and retries
unavailable font metrics. Retirement clears the accepted inputs without
recreating an already-empty formatting record on every poll.
The formatting record uses `captionCache`; the original `caption` field remains
the optional string used for localized font fallback during construction and
font previews.

Each blue-foam paint shares one current bar-height sample across its sixteen
pieces. Clipping, UVs, artwork and animation cadence remain unchanged. These
reduce source-level CPU work; the controlled timer-off result and remaining
native rendering leads are recorded in [PERFORMANCE.md](PERFORMANCE.md#movement-stutter-investigation--2026-10-28).

## Boss health loss

Normal mode uses the selected **04 Crimson echo** treatment: received damage
immediately changes the red fill and health number, while a subdued crimson
afterimage catches up over 950 ms. Performance Mode keeps the immediate health
update and hides the afterimage. These rules also apply to enabled guardian rows
in the boss-bar view; the separate Guardian tracker is unchanged.

The trailing edge uses `(1 - elapsed / 0.95)^1.45` easing, the existing white
WidgetStatusBar fill tinted RGB `(235,65,51)/255`, and 0.74 opacity. Only the
recently lost section is drawn. Another decrease samples the current eased edge
before extending one trail, so rapid damage never restores an already-drained
peak or allocates a per-hit effect. These are changes between accepted native
health publications, not reconstructed individual combat hits.

One texture is prepared lazily on a row's first visible normal-mode decrease,
below its existing gold bezel and health text, and reused with the pooled row.
It stretches the same fill through the loss section as the selected simulation.
Successful artwork binding, tint and UV setup happen once; failed bindings retry
only while the trail is active. Active anchors and width follow the native bar's
current dimensions and skip unchanged writes. No new frame, asset, setting,
SavedVariable, event or updater is added. The existing HUD reader paints only
active trails; an empty effect set returns before UI-clock or geometry reads.

Hiding, retirement, row reuse, changed identity/name/maximum, healing, reload and
actual Performance Mode transitions clear the trail and its comparison baseline.
Showing a row or leaving Performance Mode starts with current health, without
replaying hidden or suppressed loss. World/run retirement and disabling custom
boss bars use their existing row cleanup. Health captions, debuffs, viewport,
native health and native HUD ownership keep their existing behavior.

[WidgetStatusBar attribution](../third_party/WidgetStatusBar-SOURCE.md) and
[rendering costs](PERFORMANCE.md#boss-health-loss--2026-10-28) describe the reused
artwork and limits. CI-only mocks cover production effect and row lifecycles;
local work uses source review and pinned formatting, without tests or game runs.

## Width and encounter rows

The Run timer and Boss health Layout outlines have left/right center handles for width only, preserving font, icon and health-pill height. Their 296-unit outer defaults and 280-unit fills stay unchanged; side widths range from 120 to 1200, independent of proportional corner scaling. Width is saved in the existing Layout geometry with normal Confirm, Cancel/discard, profiles and reset behavior.

The run fill uses `runBar.layoutWidth`, derived from the actual root width minus its original sixteen-unit inset. Every scheduled skull uses `width * nativeSpawnTime / nativeRunLength`; the final skull stays at the fill's right edge. Width is part of the marker cache key. Native health, boss state and native time still own the values and marker state. Native StatusBar UV writes remain untouched.

The existing 27 flow regions retain their speed, lane, phase and update interval; their spacing and wrap span reflow to the new width. Blue foam clips against the resized native progress boundary. The 28 red glints redistribute across that width only on a width transition, preserving pulse periods, phases, alpha and authored artwork. A wider bar does not allocate additional effects or alter native timing. Hidden views defer this cosmetic reflow until visible.

Boss health also has top/bottom handles for 1–40 viewport slots, with mouse-wheel access to further validated native entries. The `bossRows` display preference defaults to zero (automatic full list), copied by profiles and restored on resets. Full encounter validation and native HUD ownership remain intact. Visible health rows use the current group width, preserve end caps and text size, and wrap their eighteen-unit debuffs into the available columns. Debuff height remains part of the measured outline. No data, health value or boss is fabricated to fill empty viewport slots.

Source inspection and pinned formatting do not establish animation appearance, input behavior, native rendering or FPS in the packaged client. No local tests or game execution were run.

## Replacement switches and native settings

The existing display normalizer also owns `customRunTimer` and
`customBossBars`, both default true. They share live preview, Confirm-only
saving, Cancel/discard, profiles and both full resets with the other choices.
They do not change either group's saved position, scale or Layout hidden flag.
Layout hiding is separate: an enabled custom view still holds its valid native
takeover while hidden.

Disabling a replacement clears its view and explicitly requests native
`clock` or `bosses` visibility through `AZS_SetHudShown`, corresponding to
`hudClock` and `hudBosses` in Options → Interface. This intentionally replaces
an earlier saved false with true. Current visibility is checked before writing,
the result is checked afterward, and incomplete restores retry through the
existing reader. Matching CVar events defer reapplication while off; synchronous
callbacks from addon writes cannot reenter the handoff. World entry reapplies
the selected off mode, including before run data has arrived.

Enabling again requests a deferred current-state refresh and retains the
existing received-snapshot/readiness gates before native takeover. Disabled
views skip clock/schedule or encounter/debuff getter and presentation work.
Clock-off also skips reload schedule handoff preparation. Shared phase/run
boundary observation, the tally, guardian tracker and waypoint foundation keep
their own lifecycles. No updater, asset, command, SavedVariable or native
game-preference snapshot is added to profiles.

## Boss health on death and restart

The official `AZS_GetPhase()` reports `dead` for a finished run. Boss health
rows retire in that phase and in `ready`, including their debuffs, hovers and
copied encounter entries. This uses run state rather than player health or a
character-death event, so a temporary co-op down does not independently clear
encounters while the run remains active.

Clearing once is insufficient: the same Lua VM can retain `AZS_UNITS` and its
finite `AZS_UNITS_UPDATED` timestamp through **Again?**. `AZS_GetBosses()` creates
a new result table from those retained units, so neither that timestamp nor a
different getter result establishes a new run. The existing reader now counts
`AZSUNITS` receipts and requires a publication after the retired boundary before
accepting encounters again. A new `AZSZONE` receipt, native clock regression or
world cleanup also retires the old list, covering retries where the addon never
observes the terminal phase. No native table is cleared or rewritten.

The zone, run and unit prefixes may arrive in separate frames. Unit receipts
after a new zone remain eligible while waiting for its run packet; the previous
run's retained `dead` phase cannot discard them. Late unit receipts while a
current run remains `dead` or `ready` stay retired. All getters still run through
the deferred reader, after the native parser has handled the publications.

Initial loading or a mid-run `/reload` can still accept a received native unit
snapshot once phase and metadata are valid. After a known retirement, the old
timestamp alone cannot reopen rows. A fresh valid empty snapshot remains valid
for native HUD takeover. Filtering, health values, row order, hidden/off policy
and captured native visibility restoration are unchanged. There is no documented
run identifier; the gate uses the official phase, zone receipt, raw run clock
and unit publications without estimating run identity from enemy health.

This adds two session-only receipt counters and one retirement flag to the
existing render state, with no event, updater, setting, SavedVariable or region.
Cleanup traverses active rows once per retirement; later inactive refreshes skip
encounter getters and repeated cleanup. Runtime retry behavior remains unverified.

## Caption settings lifecycle

The existing `SurvivorsDragonUiDisplay` table owns normalized
`runTextRegular`, `runTextEndless`, `runCurrentRegular`, `runCurrentEndless`,
`runMaximumRegular`, `bossCountdownRegular` and
`bossCountdownEndless` booleans. Explicit valid choices are retained; missing or
invalid values use the defaults above, with one compatibility exception.

For either missing or invalid `runText` choice, a valid boolean legacy
`SurvivorsDragonUiRunFont.showText` supplies the fallback; otherwise it is on.
An explicit new mode choice takes precedence. The legacy field no longer
controls the boss countdown or acts as a shared master switch.

The obsolete `runMaximumEndless` field is no longer a supported setting. Any
old saved value is ignored by the timer and omitted when the existing display
normalizer saves confirmed choices.

All seven choices use the existing display draft, notification, Confirm,
discard and reset paths. The compact checkboxes have measured fourteen-language
captions and no description rows. Font preferences retain their existing save.
No SavedVariable, command or gameplay persistence is added.

## Native countdown data

The owning [API reference](AzerothSurvivors-Addon-API.md#azs_run-the-run-right-now)
defines `AZS_RUN.nb` as seconds to the next boss in regular and Endless modes,
with `-1` for none. The renderer uses that value directly after native phase
acceptance and receipt of a current run snapshot. Explicit `endl == 1` selects
the Endless preference; `endl == 0` selects the regular-run preference. Unknown
or missing mode flags do not select a boss-countdown preference.

A finite nonnegative `nb` is rounded up and shown with the existing translated
`BOSS IN: %s` caption and unpadded minutes, such as `5:00`. Zero is valid.
Missing, negative or nonfinite values hide the countdown. No deadline is
estimated from schedules, elapsed time, the final-boss limit or defeated bosses.
Native updates retain pause and spawn timing.

Packet handlers still defer native data reads until OnUpdate. A new zone clears
the displayed countdown immediately and suppresses old run data until a run
packet arrives after the zone boundary. Clock release, world leave, logout and
reload cleanup clear either mode's countdown through the same helper. Font
and display previews reapply the current mode's choices to cached formatted
caption strings, so previewing another choice cannot revive disabled text.
These strings supply no private clock or gameplay snapshot and are cleared on
a new zone and clock release.

## Caption placement

With all regular-run components enabled, the left caption reads
`RUN current / maximum`. Turning **Run text** off removes only the word,
leaving `current / maximum`. One enabled time component appears without a
slash: `RUN current` or `RUN maximum` with the word enabled, otherwise just
`current` or `maximum`. An explicitly enabled regular maximum stays visible at
and beyond the zone limit.

Endless independently shows the `RUN` word and current time; it never shows a
maximum zone time. A word-only caption is valid in either mode.

When both captions are visible, the time caption uses the pill's left edge and the boss
countdown uses its right edge. If only one caption is visible, it is centered;
this includes a boss-only display when **Run text** and **Current time** are
off, with **Maximum zone time** also off for regular runs.

Both labels and the font preview reuse the pooled segmented renderer, with
minutes, colon and seconds on the same baseline. Measured overflow separates
long translated captions and extends only the shared edit bounds; it does not
resize the pill or save new geometry. Font, visibility, native clock takeover,
fill animation, boss markers and the reload-only schedule handoff retain their
existing ownership.

## Evidence

Implementation follows the supplied API's native `nb`, `endl`, `clock` /
`bosses` HUD parts and existing phase-first lifecycle. The replacement switches
received manual source/diff review and pinned formatting. Local tests,
standalone validation and addon/game execution were not run; live rendering and
native preference handoff remain unverified.

The death/retry fix also consulted
`AzerothSurvivorsRE/docs/analysis/addon-bridge-0.109.0.md` for the historical
same-VM **Again** lifecycle. That older target is supporting evidence only.
Read-only inspection of the installed executable, SHA-256
`7e3e3f9558de1d87e615592c7b5d83f00de393ac8efa4e67d8f9b634ed07d6bf`,
confirmed the embedded `AZS_GetPhase` getter at file offset `120338879`,
`AZS_GetBosses` at `120342363`, and `AZSUNITS` parser at `120351145`. They read
`AZS_RUN.ph`, rebuild boss/final rows from `AZS_UNITS`, and replace that unit list
and receipt timestamp on publication. The supplied
[API reference](AzerothSurvivors-Addon-API-2026-10-22.txt) defines `dead`, the
once-per-run zone publication and unit spawn IDs scoped to a run. Source review
and formatting do not establish live death/retry or packet-delivery behavior.
