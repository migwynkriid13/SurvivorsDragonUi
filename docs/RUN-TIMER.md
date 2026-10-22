# Run timer and boss countdown

`/sdui` → **Run timer** places **Font** and **Size** on one row, followed by
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

## Settings lifecycle

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

Implementation follows the supplied API's native `nb` and `endl` fields and
existing phase-first lifecycle. Local tests, syntax/formatting checks and
addon/game execution were intentionally not run. Use the existing PR's GitHub
Actions for authorized static verification; live rendering remains unverified.
