# Settings editor

`/sdui` uses Blizzard’s Dragonflight plain metal settings frame, gold accents,
compact category rows, checkbox artwork and
Confirm/Cancel footer. The wider content column and nine categories replace
the old twenty-entry sidebar. The editor fits to the available viewport without
the former additional 85% scale reduction.

| Category         | Sections                                            |
| ---------------- | --------------------------------------------------- |
| Layout           | Frame selection, coordinates, size, hiding and grid |
| Unit frames      | Unit frames, Pet frames, Auras                      |
| Combat           | Combat text, Nameplates                             |
| Damage meter     | Damage meter                                        |
| Action bar       | Action bar, Equipped jewelry, Kills, Gold & Caches  |
| Encounters       | Run timer, Boss bars, Guardian tracker              |
| Map & navigation | Waypoints, Minimap                                  |
| Interface        | Chat, Loot notifications, Tooltip, Banners          |
| Profiles         | Save, load, overwrite and delete setups             |

## Navigation and spacing

`core/editor.lua:CreateEditorNavigator` owns nine category buttons and one native
scroll viewport. Opening creates the shell and selected category only. Section
parents, headings and controls are constructed on their category's first visit
and reused thereafter; unvisited categories have no native page objects. Profiles
waits for its own category, and the Run timer font popup waits for its button.
There is no background preloading. Direct entry to Profiles prepares Profiles
without visiting Layout first. The selected sidebar button supplies the category name; there
is no duplicate category title or search field. Section headings appear only
when their names differ from the category, such as Pet frames under Unit frames.
These subsection headings are centered above their controls and divider. Damage
meter has its own sidebar category and no repeated content heading.
Controls start at the top of the viewport rather than below a search/header area.
Each category remembers its scroll offset until the UI reloads.

Live run updates touch the font preview only after the Run timer page has been
prepared and its category is visible. Opening another category leaves that
sample unallocated while the normal HUD captions continue updating. Hiding the
category or closing settings stops sample presentation.

`modules/ui/run.lua:CreateFontEditor` supplies the section definitions and keeps
the existing control owners. Multi-option sections use two columns for both
toggles and numeric steps, read left to right and then down. At the current
660-unit content width, each column is 322 units wide with a 16-unit gap. Enable
switches for boss bars and the damage meter span both columns; mode selectors
and sections with only one option keep their full width. An odd last option
stays on the left. Guardian current/maximum health and percentage/shortening
choices form matching pairs.

The existing custom pages retain their useful arrangements: Layout pairs
coordinates, dimensions and Hide frame/Show grid; Combat text pairs its switches
and filters; Run
timer pairs Regular/Endless options and keeps shared font controls together.
Profiles retains one saved-profile list and its action row. Loot's three-way
mode selector and the tally's two-column style picker keep their own rows.

Ordinary toggles use `CompactEditorToggle`: native caption width selects one or
two title lines, then the description follows with a three-unit gap. Single-line
rows are 64 units high; wrapped-title rows are 76. `CompactEditorNumber` uses the
same title gap, a separate 40-unit help area and the existing step controls,
giving 72/84-unit rows instead of 88. `LayoutEditorOptions` uses the larger height
in each pair and finishes incomplete pairs before placing a full-width control.
Changed measurements reflow the selected category on opening, category selection
or language changes, with no idle updater. Missing metrics remain retryable.

Sidebar width stays at the existing 232-unit cap, avoiding first-click measuring
of every translated category. Footer and prepared control widths use the active
language through `locale.Width(..., true)`. Successful measurements are cached by
caption, language, font/size/flags, ruler width and owning-frame effective scale;
unavailable metrics are retried. The timer controls and Profiles save row reflow
when their visible language changes. Closed and unselected pages defer that work.

HUD edit artwork uses the existing Layout controller with a limit of two newly
prepared groups per render frame. Pending groups keep the editor dirty only
while Layout or the moving mode is active. Switching categories, closing,
Cancel/world cleanup and reopening preserve the reusable pools without preparing
remaining hidden artwork. The grid uses the chosen editor mode's existing path.

Description-free checkbox captions stay vertically centered with their checkbox
as row height changes. Performance Mode keeps a 28-unit caption box inside its
36-unit row; Black shadow and Attach affixes share aligned 28-unit rows.

Layout's Hide frame and Show grid use 194-unit columns with a 12-unit gap. The
shared moving popup hides Show grid and expands Hide frame to 400 units. Caption
wrapping determines the row height and positions Apply/status; the popup grows
from its 320-unit minimum and reuses the existing screen-clamped placement.

Layout and profile inputs use a plain dark inset with four thin neutral metal
edges. Native EditBox behavior, text, focus and callbacks are unchanged. No
ornamental border asset or input animation remains.

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

The named `SurvivorsDragonUiSettings` window is registered once with native
`UISpecialFrames`. Escape hides it through the native close path, and its shared
Layout hide hook calls Cancel only for a live full-editor session. Switching to
moving mode hides the same window while retaining the draft; Confirm/Cancel
retire the transaction before their own hide callbacks. Escape from a focused
Layout numeric field or profile-name field also cancels the full editor, even
with invalid pending input. The moving popup retains its existing field-level
Escape behavior. The minimap glyph uses `layout.ToggleEdit` for open/cancel.

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
