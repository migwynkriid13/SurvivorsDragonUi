# Minimap buttons

The gold Dragonflight glyph beside the minimap toggles the existing `/sdui` editor.
It uses the selected **05 Small square button** background: a compact dark plate
with a gold edge, centered behind the unchanged glyph. The background is static;
the glyph uses additive blending, so its source image's black backing contributes
no visible color. Hover changes only the glyph's alpha, without a separate glow
or animation. The translated **Layout** caption and `/sdui` command identify the
action in its tooltip.

The launcher's center starts exactly on the minimap's bottom-left corner, where
the two edges meet, with no outward offset. It can be dragged around the square
edge. Its edge position is session-only. The minimap's Layout group still owns
movement, scale and parent visibility.
Clicking uses `layout.ToggleEdit`: a closed editor opens through `BeginEdit`;
an active session closes through `CancelEdit`, discarding unconfirmed changes.
Escape also cancels the full settings window, including from its numeric and
profile-name fields. Confirm remains the save action. These routes share the
existing profiles, preview and cleanup paths.

Under `/sdui` → **Map & navigation** → **Minimap**, **Show SDUI button** is on by
default. Turn it off to hide only the gold launcher; `/sdui` still opens settings.
The switch previews immediately and follows Confirm, Cancel, profiles and both
reset paths. Hiding the launcher clears its hover and ends its drag. Showing it
again restores the same session position without another frame or updater.

While editing, the existing minimap `onEdit` callback puts the launcher at
TOOLTIP level 125, above Layout's level-100 selection and below the settings
dialog at 150. This keeps the second click reachable. Closing restores the
minimap's current strata and its level plus twenty, with actual-state comparisons
to skip unchanged writes. There is no new region, event or updater for layering.

The default map top is 26 UI units below the screen top. The zone panel sits
12 units above the map, tightening their gap by six units while retaining the
zone strip's default screen position. Saved Layout positions still take priority.
Both Performance Mode states use these static anchors with no added regions,
artwork or recurring work.

## Zone name

The text above the minimap shows the received `AZS_ZONE.zname` exactly, in the
game's language. Native area/subzone updates cannot replace it, and the zone
subtitle is not appended. Missing or invalid zone data leaves the caption empty;
there is no area-name fallback.

The existing zone button refreshes once after a native `AZSZONE` message, world
entry or language change, after native parsing. Showing the minimap refreshes
the caption; hiding it cancels pending work. World leave, logout and reload clear
the old name. Changed-only writes and the same existing controls serve both
Performance Mode states, including with the clock off. No frame, region, asset,
setting or recurring zone poll is added.

The center-screen zone-entry splash is disabled, including its territory and
subzone lines. The existing `PermanentlyDisableFrame` helper retires
`ZoneTextFrame` and `SubZoneTextFrame`, removes their event/animation callbacks
and blocks later Show attempts. This adds no polling or drawing resources.

## Optional local clock

`/sdui` → **Minimap** → **Show clock** is on by default, with the zone name on
the left and local time on the right. Turning it off centers the zone name in
the existing top panel and stops the clock's update callback and local-time
reads. The existing worker checks the date once every 60 seconds in both
Performance Mode states, only while the clock is enabled and visible on older builds. With
`AZS_GetLocalTime()` available, that same worker reads the native snapshot
instead. Our label and tooltip use its hour/minute fields in **24-hour `HH:MM`**
format, including when the native English caption uses AM/PM. Unchanged native
hour/minute pairs skip formatting; all paths skip unchanged text writes.
Hiding/disabling clears only its owned hover.
Show, world entry and language changes sample fresh time.

The clock's right edge stays aligned with the panel, while its label and hover
frame fit the current font's natural `HH:MM` width plus four units for outline
and shadow rounding. Wider readings extend left instead of being cut to a fixed
slot. The zone caption and its button use the remaining panel width with a
six-unit gap; clock-off restores their full centered width. Measurements are
cached by reading, actual font/size/flags and the owning frame's effective scale.
Visible font changes refit without another time read; Show and language recovery
remeasure. Missing metrics retry through the same visible worker and defer native
clock suppression until the replacement fits. Both Performance Mode states use
this static geometry, with no added frame, region, asset, event or updater.

`minimapShowClock` uses the existing display table and shared live preview,
Confirm, Cancel/discard, profiles and both reset paths. Missing/invalid values
and resets mean on; an explicitly saved off choice stays off. It adds no
SavedVariable, drawing region or asset.

On builds that also recognize the native `localClock` HUD part, on hides the
game clock once our text/font is ready; off hides both clocks. The shared HUD
owner captures the original preference and later external changes, restoring it
on world leave, logout, reload or an unavailable replacement. A failed native
handoff hides our caption until the existing visible worker can retry. The run
timer's separate `clock` part is untouched. Missing or invalid native readings
clear our text and release native ownership; they never fall back to a second
reading while that getter exists. Older builds without the getter keep the
existing date fallback and receive no unknown HUD-part calls.

The existing clock frame handles visibility, world/CVar delivery and cleanup;
there is no new frame, setting, asset or idle updater. Both Performance Mode
states use the same static behavior. The native contract is recorded in
[Local-clock API proposal](LOCAL-CLOCK-API-PROPOSAL.md). The addon consumer has
source review and CI-only mocks; installed API availability and in-game
handoff remain unverified. No local tests or game execution were performed.

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

The launcher allocates one button and two textures, bound once. The background
uses the exact `(0,3)-(29,29)` region of Blizzard's 32-square normal button image,
displayed at 37 by 33 units to match the chosen preview. The glyph and native
input bounds remain 34-square. This adds one persistent background region and
its normal alpha overlap beneath the glyph; it adds no animation or recurring
texture/geometry work. Both textures inherit minimap hiding and scale, and the
same static artwork remains in Performance Mode. It adds no
idle updater, gameplay reads, logs, SavedVariable or runtime library. Hook records
are allocated once per eligible external button. Full-resolution TGAs are
preparation inputs; only the prepared BLPs enter the runtime manifest. See
[artwork provenance](../third_party/MinimapGlyph-ARTWORK.md).

The source and image were inspected, and edited Lua/Markdown/JSON were formatted
with the pinned local tools. No local test, standalone validation or addon/game
execution was performed. Actual dragging, native tooltip/input, load order and
appearance remain unverified in-game; source inspection is not an FPS result.
