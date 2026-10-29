# Settings editor

`/sdui` uses Blizzard’s Dragonflight plain metal settings frame, gold accents,
compact category rows, checkbox artwork and
Confirm/Cancel footer. The wider content column and eight categories replace
the old twenty-entry sidebar. The editor fits to the available viewport without
the former additional 85% scale reduction.

| Category         | Sections                                            |
| ---------------- | --------------------------------------------------- |
| Layout           | Frame selection, coordinates, size, hiding and grid |
| Unit frames      | Unit frames, Pet frames, Auras                      |
| Combat           | Combat text, Nameplates, Damage meter               |
| Action bar       | Action bar, Equipped jewelry, Kills, Gold & Caches  |
| Encounters       | Run timer, Boss bars, Guardian tracker              |
| Map & navigation | Waypoints, Minimap                                  |
| Interface        | Chat, Loot notifications, Tooltip, Banners          |
| Profiles         | Save, load, overwrite and delete setups             |

## Navigation and spacing

`core/editor.lua:CreateEditorNavigator` owns eight category buttons and one native
scroll viewport. The selected sidebar button supplies the category name; there
is no duplicate category title or search field. Section headings appear only
when their names differ from the category, such as Pet frames under Unit frames.
Controls start at the top of the viewport rather than below a search/header area.
Each category remembers its scroll offset until the UI reloads.

`modules/ui/run.lua:CreateFontEditor` supplies the section definitions and keeps
the existing control owners. Numeric editors retain full-width rows. Ordinary
toggles use `CompactEditorToggle`: native caption width selects one or two title
lines, then the description follows with a three-unit gap. Single-line rows are
64 units high; wrapped-title rows are 76. Paired columns use the larger row height.
Changed measurements reflow the selected category on opening, category selection
or language changes, with no idle updater. Missing metrics remain retryable.

## Buttons

Cancel, Confirm, Addon defaults, profile actions, mode choices, numeric steps and
paging controls share the retail red button skin. The source is Blizzard's
Dragonflight-build `128GoldRedButton` artwork, with gold edges/text, a native
additive hover highlight, pressed artwork and grey disabled artwork. Fixed outer
caps retain their proportions as widths change; only the middle stretches.
Small buttons crop the inside of their caps instead of squeezing the corners.
Selected choices use the pressed face and a locked native highlight.

`CreateEditorButton` retains the native click/enable/disable methods and existing
callbacks. Hover/press/selection and explicit size changes update cached visual
state; hidden buttons defer painting until shown. There is no animation or idle
updater, and normal/Performance Mode use the same skin. The old inset fill,
diamond border and extra caption frame are removed from these buttons. Source
rectangles and the static preview are in
[SDUI-ARTWORK.md](../third_party/SDUI-ARTWORK.md).

## Saving and lifecycle

The navigator never saves settings. `core/layout.lua`, `core/display.lua`,
`core/profiles.lua` and the existing timer/SCT owners retain preview, Confirm,
Cancel, profile/reset and world/logout/reload discard. Pending Layout numeric
input is retained across categories; the existing invalid-input and
frame-selection rules remain. Closing the editor retains the existing focus cleanup and
closes the font-choice popup. No new SavedVariable or display preference exists.

All drawing is static in normal and Performance Mode. Sections and controls are
prepared on the first editor opening and reused; navigation adds no idle worker,
gameplay reader, native HUD ownership or animation. Cost boundaries are in
[PERFORMANCE.md](PERFORMANCE.md). CI-only production mocks are registered in
`scripts/run_ui_contracts.py`; local work uses source review and pinned formatting.
The revised dialog has not been launched or visually verified in the game.

HUD selection artwork, resize grips and the grid appear only in Layout or
`/sdui lock`. Other categories keep the shared preview transaction with those
overlays actually hidden and their geometry sampling suspended. Returning to
Layout restores the pooled overlays and retains pending numeric input. An
invalid pending value still brings Layout back before Confirm can save.

Closed windows and unselected categories defer setting-label, dependency and
font-preview painting until their native Show callback. The numeric form has
no separate OnUpdate: the existing editor sample refreshes it only when visible
and without dirty/focused input. The existing ten-Hz viewport watcher remains
necessary for delayed client UI scale and saved Layout placement; closing settings
does not turn that geometry owner into an editor-rendering worker.

## Retail moving view

`/sdui lock` opens the compact HUD Edit Mode manager. Blue selections identify
editable groups and gold identifies the selected group. Clicking a group opens
the same numeric form used by Layout; its input widgets are reparented rather
than duplicated. Switching back to `/sdui` restores their normal home. Moving
mode uses numeric sizing; the original corner/edge grips appear only in the full
editor and remain pooled for reuse.

Show grid, Snap to elements and Grid spacing share the existing display draft.
`layoutSnapEnabled` defaults true and `layoutGridSpacing` defaults 32, normalized
to 8–128 UI units. Confirm/Save and close, Cancel, profiles and both resets use
the existing transaction. No SavedVariable is added. Profiles opens the existing
profile page in the full dialog.

Dragging remains free under the pointer, with alignment previews and an
8-physical-pixel magnet applied on release. Snapping to frames/screen edges works
with the grid hidden; grid magnets follow visible grid lines. Adjacent frame
corners take priority, a single closest frame edge otherwise wins, and compatible
grid/screen candidates can settle both axes. The original full-editor Shift
alignment stays available. Arrow keys nudge the selected group by one UI unit;
Shift uses ten. Focused text inputs retain their keyboard input. Escape closes
the selected popup first, then cancels the edit session. Cancel, world/logout/
reload cleanup and invalid numeric input retain their original semantics.

This independently adapts Dragonflight 10.2.7 selection/magnetism behavior and
DragonUI’s manager/popup arrangement to the older native frame API. It does not
load Blizzard’s retail C_EditMode systems or DragonUI/Ace frameworks. SDUI keeps
absolute confirmed geometry and its own profile/reset and native HUD ownership
contracts; retail’s persistent frame-to-frame docking relationships, per-spec
layouts and system-specific retail settings are not reproduced. Exact in-game
behavior/appearance parity is unverified. Source pins and the static preview are
in [SDUI-ARTWORK.md](../third_party/SDUI-ARTWORK.md) and
[LAYOUT-HANDLES.md](LAYOUT-HANDLES.md).
