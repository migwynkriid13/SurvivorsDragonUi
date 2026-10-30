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

The user clarified that numbers should retain their position relative to the
enemy as the camera moves. Stationary dummies alone do not establish that
behavior. The implementation uses the accepted enemy's current native projection,
rather than treating the first screen coordinate as a world anchor.

| Reference                              | Observed presentation                                                                                                                                           | Addon treatment                                                                                                                                                                          |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Opening and first burst, roughly 0–7 s | Hits cluster around individual dummies rather than a fixed screen column. Nearby targets produce separate clusters.                                             | Follow the existing matched enemy instance's native projection, with independent burst/drift offsets. Detach permanently on retirement; ambiguous groups retain their centroid.          |
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

Every original hit still resolves and consumes its own loss evidence. Only a
group whose members all resolve to the same nonnil origin can follow it. That
origin table belongs to one native visibility/name incarnation; animation never
rematches names, reuses a frame handle as identity or chooses an arbitrary member
of a mixed group. At display and each active animation sample, Diablo copies the
already-sampled projection before applying its own offsets. The original enemy
arcs and MSBT retain their coordinate behavior.

On hide, retirement or reuse, the number takes the original instance's last
usable point and permanently drops its reference. Projection data older than
the existing 0.65-second matching window also detaches. A later same-name enemy
or restored projection cannot reclaim that number. Mixed/ambiguous/unmatched
groups retain their fixed fallback centroid. The addon has no persistent world
projection after the native plate retires, so continuing camera compensation
after death or disappearance remains a client/API boundary.

Performance Mode follows the existing explicit SCT exception: preserve the
selected animation and lifetime, and sum matching same-attack damage within the
fixed inclusive 300 ms window. Normal mode retains the original 75 ms
exact-amount duplicate suppression. Mode changes close old intake without
restarting active labels or rewriting an existing group total.

The Diablo branch adds no combat frame, drawing region, asset, event, updater or
SavedVariable. Each active entry still uses its original holder, inner visual,
FontString and optional icon; the pool grows to observed peak concurrency and is
reused. Formatting and random choices run once at acquisition. Only live labels
run animation math. Following adds one optional origin reference per pending
group/active label and constant-time cached-field reads, without another native
position read, plate scan or lookup per label. References clear on detach,
release and shared cleanup. Anchors, scale and alpha skip unchanged writes; glyph fitting
continues only during scale changes or unavailable-metric retries. Empty lists
remain idle and normal retirement clears the style/lifetime scalars.

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
New full-controller plate cases move the accepted projection at unchanged UI
time, check the exact anchor delta and one shared native sample, retain active
lifetime through Performance Mode changes, then exercise retirement, different-
and same-name reuse, stale projection, fallback pool reuse and world cleanup.
Queue fixtures require unanimous nonnil origins while retaining every original
match, centroid, amount and Performance Mode total.

Local work uses source/diff review and pinned formatting only. These tests were
not run locally; addon/game execution remains unauthorized. No mock or source
count proves live appearance, native font rendering, draw calls or FPS.
