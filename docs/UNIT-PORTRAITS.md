# Unit frames

**Hide portraits** in `/sdui` → **Unit frames** switches the player,
target and target-of-target to closed health bars without their portrait
pictures or gold rings. Names, levels and health values keep their native
updates. The separately selected class resources remain available.

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

Unit roots, saved and draft positions, scales and native handlers remain intact.
The large bars remove only the overlap beneath the absent portrait, preserving
their outer edge and original label area. The optional player resource row and
existing damage-loss fractions follow the health span. Health fills, values,
native target availability and target-of-target updates remain authoritative.

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
