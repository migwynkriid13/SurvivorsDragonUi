# Unit portraits

**Hide portraits** in `/sdui` → **Unit frames** switches the player,
target and target-of-target to closed health bars without their portrait
pictures or gold rings. Names, levels and health values keep their native
updates. The separately selected class resources remain available.

## Settings and layout

The normalized `hidePortraits` boolean defaults to false in the existing
`SurvivorsDragonUiDisplay` table. It uses the shared live preview and Confirm-only
saving. Cancel, world leave, logout and reload discard the preview; both full
resets restore visible portraits. No SavedVariable or gameplay state is added.

Round player portrait and Experimental 3D portraits retain their confirmed
choices while hidden. Their editor controls are dimmed until portraits return.
The model renderer treats hidden portraits as disabled, releases existing
copies and rejects late model callbacks. Still portraits remain transparent,
including when model creation is unsupported. Showing portraits restores the
chosen still or experimental model behavior through the existing readiness gates.

Unit roots, saved and draft positions, scales and native handlers remain intact.
The large bars remove only the overlap beneath the absent portrait, preserving
their outer edge and original label area. The optional player resource row and
existing damage-loss fractions follow the health span. Health fills, values,
native target availability and target-of-target updates remain authoritative.

## Artwork

The shared `CreatePortraitlessBorder` helper closes both ends with mirrored
pieces of the existing `UI-TargetingFrameDF1.blp` straight metal edge. Source
columns 24–32 provide end caps; columns 32–136 provide horizontal spans. Rows
29–34, 34–63 and 63–67 supply the top, side and bottom pieces. Corners keep their
size while the straight spans follow each bar. No new asset is shipped.

The ordinary portrait sheets are hidden while this border is active. The small
target-of-target hides only its sheet strips, retaining its foreground health
and dead text. Player portrait pulses and the resting icon remain hidden while
portraits are off. Native primary pet and summon frames are unaffected.

## Verification

Validation is limited to GitHub Actions formatting, static analysis, version
gating and runtime ZIP packaging. No local checks, addon execution or game
launches were run. The supplied Photoshop mockup guides the intended bar-only
appearance; exact rendering and native callback behavior remain unverified in-game.
