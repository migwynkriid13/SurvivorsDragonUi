# Minimap buttons

The gold Dragonflight glyph beside the minimap opens the existing `/sdui` editor.
It has no button border, circular frame or backdrop. Its one glyph texture uses
additive blending, so the source image's black backing contributes no visible
color. Hover changes only that texture's alpha; there is no separate glow region
or animation. The translated **Layout** caption and `/sdui` command identify the
action in its tooltip.

The launcher's center starts exactly on the minimap's bottom-left corner, where
the two edges meet, with no outward offset. It can be dragged around the square
edge. Its edge position is session-only. The minimap's existing Layout group owns
its movement, scale and hiding; the launcher adds no saved state or Layout group.
Clicking uses `layout.BeginEdit`, preserving the same preview, Confirm, Cancel,
profiles and cleanup paths as the slash command.

## Optional local clock

`/sdui` → **Minimap** → **Show clock** is off by default. With it off, the zone
name is centered in the existing top panel and the clock has no update callback
or local-time reads. Turning it on restores the zone name's left position and
shows local time on the right. The existing worker checks the date every five
seconds only while the clock is enabled and visible; unchanged minutes skip text
writes. Hiding/disabling clears only its owned hover. Show samples fresh time.

`minimapShowClock` uses the existing display table and shared live preview,
Confirm, Cancel/discard, profiles and both reset paths. Missing/invalid values
and resets mean off. It adds no SavedVariable, drawing region or asset.

## Square placement

`modules/map/buttons.lua` publishes `GetMinimapShape() == "SQUARE"` for compatible
libraries. The installed Survivor Bugs button instead always multiplies its saved
angle by a circular radius, so reporting the shape alone does not correct it.

On initialization, addon loading, world entry and minimap showing, discover small
draggable Button children of Minimap/MinimapCluster and one nested level. LibDBIcon
buttons are also eligible while locked. Wrap only each eligible button's own
`SetPoint`, retaining its original method. Adapt only nonzero **CENTER to Minimap
CENTER** offsets; forward all other anchor forms unchanged. Keep the existing
button's click, tooltip, drag handlers, visibility and saved angle owner. Survivor
Bugs itself is not edited.

The shared projection intersects the requested direction with a rectangle whose
half-width and half-height are the live map dimensions divided by two. External
buttons retain an eight-unit border allowance; our glyph uses zero allowance so
its center lies on the map's actual edges. Convert those bounds from map scale to the button's
effective scale. Dividing both coordinates by the larger normalized distance
places the center on a straight side, including the square corners. Apply the
same helper to our launcher, old circular buttons and already square-aware ones.

Store only the latest direction for reflow on actual minimap size/show changes.
Compare the real native anchor before clearing or setting it. Existing buttons
can still clear/reapply their native anchors; the wrapper repairs the new request
without a second controller. There is no idle discovery or position polling.

Only the launcher's active pointer drag installs an OnUpdate. It samples current
cursor/map geometry, skips unchanged anchors and takes a final sample on release.
Detach it immediately on release, minimap hiding, world leave/logout or entering
layout editing. Clear the launcher's owned hover on these cleanup paths. After a
drag, briefly suppress the native release click so dropping the icon does not
open settings. Hidden minimaps skip the addon's square projection and reflow;
foreign native anchor requests can still update their own state.

## Boundaries and inspection

Buttons created later are discovered at the next documented event. The shape
contract remains available to libraries that create their buttons dynamically.
Arbitrary UIParent-owned buttons, non-center anchors and engine controls absent
from the Lua frame tree are outside this adapter. Required native controls and
guardian/cache/player pins retain their existing placement and input.

The new renderer allocates one button and one texture, bound once. It adds no
idle updater, gameplay reads, logs, SavedVariable or runtime library. Hook records
are allocated once per eligible external button. Its full-resolution TGA is a
preparation input; only the prepared BLP enters the runtime manifest. See
[artwork provenance](../third_party/MinimapGlyph-ARTWORK.md).

The source and image were inspected, and edited Lua/Markdown/JSON were formatted
with the pinned local tools. No local test, standalone validation or addon/game
execution was performed. Actual dragging, native tooltip/input, load order and
appearance remain unverified in-game; source inspection is not an FPS result.
