# Run timer and boss countdown

`/sdui` → **Run timer** places **Font** and **Size** on one row, followed by
**Outline** and **Black shadow**. These choices apply to both timer captions.
Below them, **Regular runs** and **Endless** each have four compact checkboxes:

| Control           | Regular runs | Endless |
| ----------------- | ------------ | ------- |
| Run text          | On           | On      |
| Current time      | On           | On      |
| Maximum zone time | On           | Off     |
| Boss countdown    | Off          | On      |

Each mode's **Run text** controls only its complete `RUN` caption. **Current
time** and **Maximum zone time** independently choose the components of that
caption. Turning both components off leaves no `RUN` text. **Boss countdown**
is independent and can remain visible with **Run text** off.

All choices preview immediately and save only with Confirm. Cancel, world
leave, logout and reload discard unconfirmed choices. Both full resets restore
the defaults above. Changing a choice does not move or scale the timer.

## Settings lifecycle

The existing `SurvivorsDragonUiDisplay` table owns normalized
`runTextRegular`, `runTextEndless`, `runCurrentRegular`, `runCurrentEndless`,
`runMaximumRegular`, `runMaximumEndless`, `bossCountdownRegular` and
`bossCountdownEndless` booleans. Explicit valid choices are retained; missing or
invalid values use the defaults above, with one compatibility exception.

For either missing or invalid `runText` choice, a valid boolean legacy
`SurvivorsDragonUiRunFont.showText` supplies the fallback; otherwise it is on.
An explicit new mode choice takes precedence. The legacy field no longer
controls the boss countdown or acts as a shared master switch.

All eight choices use the existing display draft, notification, Confirm,
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

With both components enabled, the run caption reads `RUN current / maximum`.
With only **Current time**, it reads `RUN current`; with only **Maximum zone
time**, it reads `RUN maximum`, without a slash. An explicitly enabled maximum
stays in the caption at and beyond the zone limit. These choices apply
independently in regular and Endless modes.

When both captions are visible, `RUN` uses the pill's left edge and the boss
countdown uses its right edge. If only one caption is visible, it is centered;
this includes a boss countdown shown while the run caption is off.

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
