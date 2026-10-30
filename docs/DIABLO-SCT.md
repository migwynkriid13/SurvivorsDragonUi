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
| Late ticks, roughly 29–33 s            | Separated pale poison ticks remain readable after the dense yellow burst. Full values use comma separators, including nine-digit values.                        | Full comma-separated numeric text by default; optional K/M/B/T abbreviations. Periodic hits retain native amounts, independent arrivals and filters.                                     |
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
- Color: normal RGB `(0.92, 0.90, 0.82)`, critical `(1, 0.90, 0.32)`, unusually
  large critical `(1, 0.62, 0.18)`. The saved
  **Class-colored damage** choice is retained but dimmed/inactive in Diablo
  style, so it cannot replace this palette. Other styles retain class colors.
  Miss/avoidance wording and color remain on their shared path.
- Typeface: the separate **Font** choice offers **Default** and **Diablo IV
  (PT Serif)**. Default retains the resolved native font. PT Serif Regular adds
  the serif digit shapes with the existing outline, shadow and saved SCT size.
  Localized miss/avoidance wording retains the native font for glyph coverage.

Blue Overpower and Vulnerable/other status messages are not synthesized. The
current parsed native hits expose no corresponding Diablo result fields. The
user requested a cosmetic amber imitation for unusually large native criticals;
this does not mark them as Overpower or change the native critical flag. Large
ordinary or noncritical poison damage stays normal.
Amounts are formatted only for display; matching, health-loss consumption,
normal-hit color samples, native counters and meter attribution remain unchanged.
Precision remains limited to the numeric amount the native message parser supplies.

## Damage colors in the supplied references

The references use four main outgoing-number colors. This is a result palette,
not a scale from small to large damage:

| Color           | Meaning in that Diablo IV system        | Addon treatment                                                             |
| --------------- | --------------------------------------- | --------------------------------------------------------------------------- |
| Pale white      | Ordinary damage                         | All parsed noncritical hits, including periodic, reflected and pet damage.  |
| Yellow/gold     | Critical strike                         | Only the original native critical flag.                                     |
| Light blue/cyan | Overpower                               | Unavailable: this game's parsed hit records expose no Overpower result.     |
| Orange/amber    | Critical strike combined with Overpower | Used cosmetically for unusually large native criticals; no Overpower claim. |

Firsthand [October 2024 player reports on Blizzard's forum](https://us.forums.blizzard.com/en/d4/t/what-are-the-four-damage-colors-please-normal-crit-overpower-and/203037)
identify the four meanings. A separate
[January 2025 gameplay report](https://www.reddit.com/r/diablo4/comments/1idyjrg/)
distinguishes the Vulnerable word/health-bar indicator from damage-number color.
The supplied third image likewise shows gold **Vulnerable** text beside white
and yellow numbers. It is a status notification, not a fifth numeric result.
Do not confuse a [player's proposed purple DoT color](https://us.forums.blizzard.com/en/d4/t/suggestion-detailed-options-for-combat-text-customisable-colors-and-minion-numbers-with-picture/204356)
with shipped Diablo IV behavior.

This documents the requested reference-era palette. Diablo IV's Overpower
mechanics subsequently changed: Blizzard's
[Season of Hell's Legacy notes](https://worldofwarcraft.blizzard.com/en-gb/news/24295394)
describe generating and spending Overpower stacks. The older four-color meaning
must not be presented as proof of every current Diablo IV version or option.

Runtime pale white is RGB `(0.92, 0.90, 0.82)` (`#EBE6D1`) and yellow is
`(1, 0.90, 0.32)` (`#FFE652`); cosmetic amber is `(1, 0.62, 0.18)`
(`#FF9E2E`). These are authored approximations of the supplied
compressed images/video, not extracted Blizzard color constants. Class colors
cannot override them in Diablo style; their saved choice returns on other
styles. The existing checkbox dims/disables without clearing its value, and
Custom/Off transitions retain that secondary dependency. Color assignments skip
unchanged RGB values, including when another display choice changes.

The parser in `modules/nameplates/parser.lua` receives the original amount,
critical flag, source/pet, damage type and school. It exposes no Diablo Overpower
or Vulnerable result. Class, damage school, ownership and random chance never
invent native result flags or status messages. Only the explicitly cosmetic
large-critical rule below adds amber emphasis. Matching,
color samples, filters, original amounts and native counters remain unchanged.

## Cosmetic amber critical highlights

The user requested the brown/amber appearance even without Diablo's Overpower
mechanic. In Diablo style, a native critical becomes amber when its original
amount is at least **1.5 times the previous critical average**, after at least
**three earlier critical hits** for that same attack identity. The current hit
is classified before it enters the baseline. Ordinary hits never train this
baseline or become critical because they are large. Until it warms up, native
criticals stay yellow.

The recent window targets ten seconds using twenty half-second sum/count
buckets. Every received original critical contributes, without retaining an
individual event log. The oldest boundary can expire up to half a second early;
this is cosmetic tuning rather than an exact gameplay/DPS statistic. There are
at most 64 identities, each with at most 20 reusable buckets. A new identity at
capacity reuses the least recently observed row with a fresh baseline. Invalid
amounts/times are ignored and unrepresentable totals drop their baseline.

Identity is the existing unambiguous intake key: exact attack/spell or
identified autoattack, source, pet flag, damage type, school, native critical
status and resolved icon. Unidentified unnamed abilities stay yellow rather
than sharing an invented source. No target identity, health loss, damage
amount tier, random chance or inferred spawn identity is introduced.

The same rule runs before 75 ms duplicate collapse and Performance Mode's 300 ms
sums. A sum of many ordinary-sized criticals stays yellow. A group containing
an amber-qualified original critical displays amber; its total never trains or
qualifies against the baseline. Original amounts, critical flags, matching,
filters, meter counters and normal-hit color samples remain unchanged.

Classification is fixed on the completed group/label. Later baseline changes,
font or abbreviation preview, saved class-color choices and Performance Mode
transitions cannot recolor or restart an active number. World/zone retirement,
mode/style changes and clock regression clear the recent baseline. Leaving
Diablo stops this collection; it is unsaved and unrelated to DPS. No new
setting, frame, region, event, updater or asset is added. Both Performance Mode
states retain the same cosmetic comparison and existing animation.

## Optional abbreviated damage

**Combat → Combat text → Abbreviate damage (K, M, B, T)** uses default-off boolean
`sctShortNumbers` in the existing display table. Missing/invalid choices and both
full resets retain full values. It shares preview, Confirm-only saving,
Cancel/discard, profiles and Custom-only availability, independently of the
animation style, font and Performance Mode.

The renderer reuses `T.CompactHealth`'s existing decimal tiers for numeric damage:
`999 → 999`, `1,000 → 1K`, `1,250 → 1.2K`, `2,500,000 → 2.5M`,
`1,000,000,000 → 1B`, and `12,800,000,000,000 → 12.8T`. It truncates to one decimal
place and omits a zero decimal; the T tier remains the highest. Full Diablo
values retain comma grouping when off; other styles keep their original full
format. Localized miss/avoidance text never goes through numeric abbreviation.

Each active label keeps only its own original display value (the completed
presentation-group total when applicable). Preview/Cancel reformats and refits
that value without moving or restarting the number, changing its font/color or
expiry, closing intake, or recomputing a total from compact text. Pool retirement
clears this value. Queued hits use the current choice when displayed; their
original matching amounts and the 75 ms duplicate / 300 ms sum policies stay
intact. The meter and native counters never consume abbreviated values.

The checkbox adds one lazy settings button, four texture regions and one label;
no combat region, asset, event, updater or SavedVariable is added. Formatting
runs at display and actual choice changes, with changed-only text/width writes;
there is no new per-frame formatting work. Both Performance Mode states share
this behavior and their existing animation remains intact.

## Damage-number font

**Combat → Combat text → Font** is independent of the animation style. Its
`sctFont` choice (`default` / `diablo`) lives in the existing display table,
with Default for missing/invalid values and both full resets. It shares preview,
Confirm-only saving, Cancel/discard and profiles. Invalid edits are ignored.
The two buttons use the same Custom-only input/dimming guard as the other SCT
controls; native incoming/self feedback keeps its existing font and ownership.

PT Serif is a supported visual match rather than an extracted game atlas.
[Diablo IV credits](https://www.mobygames.com/game/259985/diablo-iv-lord-of-hatred/credits/windows/)
list PT Serif and ParaType. The original
[D2RDamageNumbers project](https://github.com/Fr4nsson/D2RDamageNumbers)
identifies its Diablo IV-style damage font as PT Serif. Neither source proves
which exact game build, weight, outline or rasterization produced every frame
in the supplied video. Old Fenris, the designer's
[official Diablo IV typeface](https://www.behance.net/gallery/187326289/OLD-FENRIS-DIABLO-IV-OFFICIAL-FONT),
is a separate branding face; it is not the bundled damage-number match.

The unmodified Regular TTF comes directly from pinned Google Fonts upstream,
under SIL OFL 1.1. See [font provenance and license](../third_party/PTSerif-FONT.md).
The complete required notice also ships inside `modules/nameplates/sct.lua`.

The pinned public client's [font engine](https://github.com/samwhosung/benilla/blob/9cd691f630adc3ec6e0985243d05867a4a7af2da/crates/benilla-app/src/ui_text/engine/mod.rs#L276)
loads additional TTF faces through its loose-addon asset source and caches them;
its [font registration](https://github.com/samwhosung/benilla/blob/9cd691f630adc3ec6e0985243d05867a4a7af2da/crates/benilla-app/src/ui_text/engine/faces.rs#L87)
retains the file's actual family and weight. This supports a bundled Regular TTF
through the normal `SetFont` path. It is compatibility evidence, not verification
of the installed binary or its rendered output.

Active labels change font and refit their natural width without changing the
value, launch point, animation age, grouping, color, icon or expiry. Pooled
labels defer font changes until reuse. Successful bindings are cached; a
rejected native font assignment restores the known usable default before text
or metrics calls, then retries after 0.5 seconds through the existing active
animation loop. Expired/hidden text does no font retry work. Localized avoidance
labels always retain the default face, including Chinese, Japanese and Korean.
Performance Mode uses the same selection and font lifecycle.

Successful size checks use the shared finite-number tolerance. Native
`GetFont` converts stored screen units back to Lua units, so an assigned size
of 18 can read slightly above or below 18. Exact equality incorrectly treated
that successful PT Serif load as a failure and immediately restored the game
font. The file path and outline still have to match, and materially different
or invalid sizes still trigger fallback and retry.

The font adds no combat region, font object, event or updater. The lazy settings
page adds two buttons with eight texture regions, two button captions and one
Font label; they draw only while that page is open. This is separate from the
style-selector cost below. The package inventory requires live literal font
references and exact manifest membership, just as it does for owned textures.

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

The Diablo animation adds no combat frame, drawing region, event, updater or
SavedVariable. The optional font adds one unmodified 359,048-byte TTF. Each active entry still uses its original holder, inner visual,
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
