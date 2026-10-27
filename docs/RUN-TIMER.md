# Run timer and boss countdown

`/sdui` → **Run timer** starts with **Enable custom run timer**, on by default.
Turn it off to use the game's original timer and next-boss line again. The
matching game option is turned back on too. **Boss bars** has an independent
**Enable custom boss bars** switch, also on by default; turning it off restores
the game's boss and guardian health bars.

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

Both labels reuse the pooled segmented renderer, including seconds raised one
physical pixel. Measured overflow separates long translated captions and
extends only the shared edit bounds; it does not resize the pill or save new
geometry. Font, visibility, native clock takeover, fill animation, boss markers
and the reload-only schedule handoff retain their existing ownership.

## Evidence

Implementation follows the supplied API's native `nb`, `endl`, `clock` /
`bosses` HUD parts and existing phase-first lifecycle. The replacement switches
received manual source/diff review and pinned formatting. Local tests,
standalone validation and addon/game execution were not run; live rendering and
native preference handoff remain unverified.
