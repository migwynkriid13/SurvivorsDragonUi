# Unit frames

**Hide portraits** in `/sdui` → **Unit frames** switches the player,
target and target-of-target to closed health bars without their portrait
pictures or gold rings. Names, levels and health values keep their native
updates. The separately selected class resources remain available.

## Player absorbs

The player health bar shows active absorbs automatically as a pale-blue
segment. There is no separate setting, and **Class resources** can stay off.
The segment starts after current health when there is room. When health plus
the shield exceeds maximum health, it moves left inside the bar so the shield
is still visible at full health. Its width represents shield / maximum health,
capped at one full bar. Existing health labels continue to show health only.

The shared player-resource reader uses the official `AZS_RUN.sh`, `hp` and
`hpm` fields after checking `AZS_GetPhase()` and a published `AZS_RUN_UPDATED`.
It never derives absorbs from buffs, spell descriptions or combat text. Zero,
missing or invalid shield/health data clears the segment. Inactive phases,
new zones and world cleanup retire the previous run publication; the same
table/stamp/receipt tuple stays blocked until native data changes. Hidden
player frames clear the segment and defer presentation until visible again.
Run packets request a deferred read through the existing resource controller.

The segment inherits the actual health rectangle, including width handles,
portrait modes and the optional resource row's height. It lazily reuses the
prepared health-fill image below the gold border and health text, leaving
native StatusBar UVs, values and clicks unchanged. No setting, artwork,
SavedVariable, event subscription or updater is added. Appearance and live
shield changes remain unverified in-game.

## Names, levels and editor layout

**Show player name**, **Show player level**, **Show target name** and
**Show target level** independently control the four native captions. The
normalized `showPlayerName`, `showPlayerLevel`, `showTargetName` and
`showTargetLevel` booleans default true in the existing display table. They
reuse live preview, Confirm-only saving, Cancel/world/logout/reload discard
and both full resets to on, independently of portrait and resource choices.

One shared `BindUnitLabelVisibility` helper masks only each FontString's alpha.
Native text and Show/Hide decisions continue; later native alpha requests are
retained and become effective when the option is on. The helper never shows
an inactive target, clears its caption or changes the frame's geometry.

Unit frames has no scroll frame. Its ten controls occupy five rows in two
columns, starting with player name/level and then target name/level. Each row
is 60 units within the existing 396-unit page. Column width is measured against
all fourteen caption and hint catalogs; existing descriptions keep their two-line
space. The shared editor still fits the viewport, and other pages retain their
existing layouts and scrolling behavior.

## Settings and layout

The normalized `hidePortraits` boolean defaults to false in the existing
`SurvivorsDragonUiDisplay` table. It uses the shared live preview and Confirm-only
saving. Cancel, world leave, logout and reload discard the preview; both full
resets restore visible portraits. No SavedVariable or gameplay state is added.

Round player portrait and 3D Portrait retain their confirmed
choices while hidden. Their editor controls are dimmed until portraits return.
The model renderer treats hidden portraits as disabled, releases existing
copies and rejects late model callbacks. Still portraits remain transparent,
including when model creation is unsupported. Showing portraits restores the
chosen still or 3D model behavior through the existing readiness gates.

Unit roots retain native handlers and the existing saved/draft position and scale rules. Independent health widths use the same Layout records.
The large bars remove only the overlap beneath the absent portrait, preserving
their outer edge and original label area. The optional player resource row and
existing damage-loss fractions follow the health span. Health fills, values,
native target availability and target-of-target updates remain authoritative.

## Health width handles

Player, Target and Party frames have left/right side handles in Layout. Dragging changes the horizontal health span; it does not scale the portrait, gold end caps, bar height, fonts, aura icons or models. The existing corner handles still scale proportionally. Party's width applies to all four native rows together, including their edit outline while inactive. Its native row/pet anchor chains and unit clicks stay intact.

Player and target use compact edit regions around their visible border art and enabled name/level captions, rather than the native roots' transparent canvas. Width grips sit at the middle of that outline's left/right borders. The shared helper reads prepared nonzero-alpha bounds for the pointed, round, boss, elite and rare sheets as static metadata; classification and portrait-mode changes select the appropriate bounds. Hidden portraits use the existing closed-border frame plus the enabled caption height. The native root, input, saved position/scale and independent health-width value stay unchanged. Corner scaling and Shift alignment measure this same compact region. Target bounds also include its currently shown native aura buttons through the existing tooltip-owned aura registry, so the border does not cross visible icons. Aura measurements run only while editing. Auras and attached pets retain their native attachment and input.

The shared Layout root stores `width` beside its position/scale. Let `delta` be the chosen root width minus its original native width. Player and target content becomes `122 + delta`, with their existing portrait overlap and one-unit render underlap added separately. The player keeps its portrait-side inset; the target mirrors it. Source columns 0–33 keep the outer cap's native size while columns 33–152 extend the straight horizontal artwork. The portraits and their original rim crops retain their sizes. The target still follows its rim even when its native anchor was expressed from the root center or left side. The player's status pulse and resting animation stay with its fixed portrait area rather than shifting to the widened root center.

**Hide portraits** continues to remove only the existing overlap and display the shared closed border attached to the actual health rectangle. It does not reset the chosen width. Pointed and round player rims, native 2D/optional 3D portraits, health values/percentages, names, levels and damage-loss fractions keep their existing owners. A shown resource strip follows the health span at its original height. No target-of-target or pet-frame width control is added.

Party's 128-unit artwork is split at columns 44 and 112: the portrait portion and outer end retain their size, and the middle span takes `delta`. Its existing health-only artwork retains the exact divider-removal crops, splitting only the top/bottom horizontal spans at column 112. The native 35-unit portrait stays at its original position relative to that fixed portrait portion. Native health/resource values remain unchanged; optional resource strips follow the wider housing. Names gain the same horizontal room without changing their fonts.

Player/target limits leave at least 64 units of original health content; party limits leave at least 40 before its existing resource-off extension. Each group allows up to 800 units beyond its native root width. Defaults and both resets retain the original dimensions. Side dragging holds the opposite visible border edge fixed; shared Confirm, Cancel/world/logout/reload discard and profiles keep their established behavior. Width changes use existing Layout callbacks and unit events, without a new preference, SavedVariable, asset or updater. Hidden presentation defers until Show, with required edit geometry refreshed on editor entry; inactive party bounds still fit all four rows.

## Artwork

**3D Portrait** enables the existing independent player, target and
target-of-target models. Their native rectangular viewports are centered inside
the existing portrait circles. For portrait diameter `d`, each viewport is
`(d - 2) / sqrt(2)` units square, keeping all four corners inside the ring.
The 3D view is therefore smaller than the original full-width model viewport;
this is containment, not a circular model mask. Native cameras and animations
remain in charge, with no race offsets or additional copies.

Twenty-two passive native `WHITE8X8` strips form a round near-black background
at alpha `0.72`, beneath each 3D model and the existing gold artwork. The outer
edge of each strip fits inside the circle; no rectangular background protrudes
past it. The backing inherits model visibility, so disabling 3D, hiding portraits
or retiring a model removes it too. The existing model update checks changed
portrait dimensions and skips unchanged geometry; no updater is added.
Still portraits remain the fallback until the existing model callback provides
copy and viewport evidence. The legacy `playerPortrait3D` preference and all
preview, Confirm, Cancel, reset and world/reload cleanup paths are retained.

The shared `CreatePortraitlessBorder` helper closes both ends with mirrored
pieces of the existing `UI-TargetingFrameDF1.blp` straight metal edge. Source
columns 24–32 provide end caps; columns 32–136 provide horizontal spans. Rows
29–34 and 63–67 supply the top and bottom pieces. The sides stretch only the
clean 35–49 span, excluding the old resource-divider stub from both mirrored
ends. Corners keep their size while the straight spans follow each bar. This
applies to player, target and target-of-target, independently of Class resources;
the player's optional resource row and native values remain unchanged. No new
asset is shipped.

The ordinary portrait sheets are hidden while this border is active. The small
target-of-target hides only its sheet strips, retaining its foreground health
and dead text. Player portrait pulses and the resting icon remain hidden while
portraits are off. Native primary pet and summon frames are unaffected.

## Verification

The edited Lua and Markdown were formatted locally with the pinned repository
formatters. No local tests, standalone syntax checks, addon execution or game
launches were run. The supplied mockup and later screenshots guide the intended
appearance; exact rendering, containment and native callbacks remain unverified
in-game.
