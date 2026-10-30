# Diablo IV combat text

Choose **Custom**, then **Diablo IV** under `/sdui` → **Combat** → **Combat text** →
**Damage number style**. **Over enemies** remains the default; **MSBT-style
scrolling** retains the movable stream. Confirm saves the choice. Cancel,
world/logout/reload discard, profiles and both full resets use the existing
display transaction. Existing saved MSBT choices and profiles migrate to MSBT.

## Reference study

The requested reference is Vaereth's
[Insane Rogue Damage | 2.5B Poison Ticks | Diablo IV](https://www.youtube.com/watch?v=AUycDQNO0sk).
The video was inspected in the browser, including full-player views, paused
combat frames and adjacent frame advances around 12–13 seconds. It shows one
Rogue training-dummy encounter, not every Diablo IV combat-text variant.

The user initially requested camera-relative enemy following. Later in-game
recordings still showed left/right and up/down motion in crowded packs after
smoothing. The user selected the **addon-only fixed-position fallback**: each
number keeps its screen-space launch point for its full lifetime and applies
only its own burst, drift, scale pop and fade. It does not follow a moving enemy
or compensate for later camera movement. This deliberately favors readable,
stable numbers over exact Diablo IV world anchoring.

| Reference                              | Observed presentation                                                                                                                                           | Addon treatment                                                                                                                                                                          |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Opening and first burst, roughly 0–7 s | Hits cluster around individual dummies rather than a fixed screen column. Nearby targets produce separate clusters.                                             | Snapshot the resolved launch centroid once, then apply independent burst/drift offsets. Native re-stacking and camera movement cannot reposition an active number.                       |
| Dense burst, roughly 7–13 s            | Pale white and yellow values coexist. Large white damage remains white; number size alone does not identify a critical hit.                                     | Pale normal damage and yellow native critical hits. Keep original native critical flags; never infer a result from amount, school, pet ownership or relative damage.                     |
| Adjacent paused frames around 12–13 s  | Values fan out locally and linger near their launch area. They do not follow the addon's long falling arc. New values overlap older values during heavy damage. | Short eased fan-out, small continuing upward/outward drift, compact scale pop, readable hold and final fade. No long fall or screen-wide stream.                                         |
| Late ticks, roughly 29–33 s            | Separated pale poison ticks remain readable after the dense yellow burst. Full values use comma separators, including nine-digit values.                        | Full comma-separated numeric text, with no K/M/B abbreviation. Periodic hits retain native amounts, independent arrivals and filters.                                                    |
| Across the clip                        | Number sizes vary; critical numbers are visually prominent. No spell icons or source names appear beside the damage.                                            | Subtle launch-size variation, larger critical labels and smaller periodic labels. The existing optional icon choice remains available and defaults off. Never add source/enemy captions. |

These observations motivate an approximation. The equations and durations below
are authored tuning, not measurements of Blizzard's implementation. The clip
does not establish an exact lifetime, random distribution, font-size rule,
collision-avoidance algorithm or hidden damage aggregation. The existing addon
grouping policy remains authoritative rather than inferring one from a busy video.

Diablo IV has also changed its floating text over time: Blizzard's
[1.5.0 patch notes](https://news.blizzard.com/en-us/article/24123440/diablo-iv-1-5-0-patch-notes)
describe readability/consistency changes and new filtering settings. This option
targets the supplied clip's appearance rather than promising every current
Diablo IV configuration.

## Chosen presentation

- Lifetime: 1.1 seconds from actual display, after the existing intake/matching
  settlement. Fade begins at 72% of that lifetime and ends at the same deadline.
- Launch: a 120 ms cubic ease into alternating left/right offsets of 18–42 UI
  units, vertical scatter of −8 to +18 units, plus the existing 12-unit inset.
  The remainder adds 12% of the horizontal offset and 18 units of upward drift.
- Scale: normal 0.95, periodic 0.82 and critical 1.25 times the saved SCT size,
  with a once-per-label 0.94–1.06 variation. A 180 ms pop starts at 0.82 of that
  scale, peaks at 1.10 for normal/miss or 1.28 for critical, then settles to 1.
- Color: normal RGB `(0.92, 0.90, 0.82)`, critical `(1, 0.90, 0.32)`. The saved
  **Class-colored damage** choice still takes precedence when a class color is
  available. Miss/avoidance wording and color remain on their shared path.
- Typeface: reuse the resolved native DEFAULT font, outline and existing black
  shadow. No Diablo font, screenshot, artwork or other asset is bundled.

Blue Overpower, orange critical Overpower and Vulnerable/other status messages
are not synthesized. The current parsed native hits expose no corresponding
Diablo result fields. Particularly large ordinary or poison damage stays normal.
Amounts are formatted only for display; matching, health-loss consumption,
normal-hit color samples, native counters and meter attribution remain unchanged.
Precision remains limited to the numeric amount the native message parser supplies.

## Integration and cost

`sctStyle` is a normalized `enemy` / `msbt` / `diablo` enum in the existing
`SurvivorsDragonUiDisplay` table. Explicit valid new values win over the old
`sctMSBTStyle` boolean. Missing/invalid choices use the original enemy style,
except a legacy exact `true` selects MSBT. Invalid editor writes are ignored.
Profiles copy through the same normalizer and do not alias active drafts.

Style changes retire active/queued labels and matching state before changing
coordinates or animation. They reuse the original controller, event intake,
resolver and hit pool. Diablo uses enemy-origin matching and the same invisible
native plate tracking when V is off; MSBT still releases that tracking. Neither
style writes V's preference. Native incoming/self text remains independent.

Every original hit still resolves and consumes its own loss evidence. Once the
group settles, its resolved centroid becomes the label's fixed launch point.
The renderer retains no live origin reference and never rematches, follows,
reparents or restarts an active number when plates move, hide, re-stack or get
reused. New numbers still use their own current resolved coordinates. The
original enemy arcs and MSBT retain their behavior.

## Why native stacking cannot be followed reliably here

The reference client source separates the raw projected head point from the
final nameplate rectangle. In
[`vplates.rs` at `9cd691f`](https://github.com/samwhosung/benilla/blob/9cd691f630adc3ec6e0985243d05867a4a7af2da/crates/benilla-app/src/vplates.rs#L586),
`bucket.resolve(desired, viewport)` moves the rectangle around other plates and
clamps it to the screen. Lines 649–664 publish that **solved** rectangle as
`PlateState.top_centre`; the
[widget owner](https://github.com/samwhosung/benilla/blob/9cd691f630adc3ec6e0985243d05867a4a7af2da/crates/benilla-ui/src/script/nameplate.rs)
uses it for the native frame anchor. `SamplePosition` reads that frame's
`GetCenter`/`GetTop`, so live following can inherit collision displacement.
Easing changes how a number chases that input; it cannot recover the raw point.

This public source is a compatibility lead, not proof of the installed binary's
exact revision. The supplied 2026-10-22 API and 0.125.0 supplement expose neither
an unstacked per-enemy screen anchor nor a general unit-to-screen projection.
The stable fallback therefore makes no claim to reconstruct world positions,
spawn identity or camera transforms. It leaves native plate geometry, collision,
input, health reads and V ownership intact. Initial launch positions can still
reflect native stacking; the guarantee is that existing labels never chase it.

Performance Mode follows the existing explicit SCT exception: preserve the
selected animation and lifetime, and sum matching same-attack damage within the
fixed inclusive 300 ms window. Normal mode retains the original 75 ms
exact-amount duplicate suppression. Mode changes close old intake without
restarting active labels or rewriting an existing group total.

The Diablo branch adds no combat frame, drawing region, asset, event, updater or
SavedVariable. Each active entry still uses its original holder, inner visual,
FontString and optional icon; the pool grows to observed peak concurrency and is
reused. Formatting, random choices and the launch point are chosen once at
acquisition. Only live labels run their own animation math. The fallback removes
pending-group/label follow references, distance/easing calculations and movement
limits; it adds no position history, native read, scan or per-frame table.
Anchors, scale and alpha skip unchanged writes; glyph fitting continues only
during scale changes or unavailable-metric retries. Empty lists remain idle.

The lazy settings page replaces one checkbox with three standard buttons and a
heading: three button frames, twelve texture regions and four FontStrings,
instead of one button, four texture regions and one caption. Net cost is two
buttons, eight textures and three labels, visible only on the open Combat page.
The existing page height includes the final filters. All three style buttons
join the shared Custom-only alpha/input dependency guard. No new worker is added.

## Evidence limits

CI-only production-controller fixtures cover enum defaults/migration, invalid
values, preview/Confirm/Cancel, profile normalization, resets, full large values,
native critical colors, icons/filters, launch/hold/fade/expiry, unchanged work,
Performance Mode sums/transitions, pool reuse and world cleanup. The production
settings fixtures cover selection, page extent and hidden/unchanged listeners.
Existing nameplate fixtures continue to exercise native origin/visibility ownership.
Full-controller plate cases compare the moving/restacking scene with an
otherwise identical stationary production controller, using the same fake
random boundary rather than copying motion equations. Repeated alternating
native positions must leave the complete label trajectory, value, fade and
lifetime identical. Cases retain native matching samples and cover invalid
coordinates, different-name frame reuse, Performance Mode changes, fresh pooled
launch points and world cleanup in both grouping modes.

Local work uses source/diff review and pinned formatting only. These tests were
not run locally; addon/game execution remains unauthorized. No mock or source
count proves live appearance, native font rendering, draw calls or FPS.
