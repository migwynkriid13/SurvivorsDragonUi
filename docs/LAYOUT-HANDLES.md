# Layout handles and alignment grid

`/sdui lock` opens a compact, draggable **HUD Edit Mode** manager with Show grid,
Grid spacing, Snap to elements, Profiles, Cancel and Save and close. It uses the
actual Blizzard plain metal frame already bundled for the character window.
The former standalone centered Confirm button now shares the manager footer.
Blue retail selections become gold on selection. Clicking opens a small frame
popup with the existing numeric Layout form; text inputs and draft state are
shared with the full editor. Numeric scale and a width slider replace corner/edge
grips in moving mode. The full `/sdui` editor retains those grips, the same width
slider and the shared Confirm footer.

Both commands enter the same draft transaction. Profiles returns to the full
profile page. A pending invalid numeric value keeps Save and close open, while
Cancel and world/logout/reload cleanup discard through the existing owner.
The popup/form, manager and native input handlers are pooled; leaving the mode
closes their input and stops any active window drag. No saved window position or
new SavedVariable is introduced. Existing Layout records remain absolute.

When the numeric form moves between settings and the selected-frame popup, it
aligns its existing child frames above the new parent's drawing level and
explicitly restores visibility. Legacy reparenting alone leaves child levels
behind and can leave an effectively hidden form invisible. The form and input
boxes are reused; draft, Apply and Save/Cancel behavior stays shared.

The compatibility reference is the native
[frame reparenting implementation](https://github.com/samwhosung/benilla/blob/3ae988ab1748149a10977093da909722d3a2e674/crates/benilla-ui/src/widget/propagation.rs#L334)
and its
[non-propagating script level setter](https://github.com/samwhosung/benilla/blob/3ae988ab1748149a10977093da909722d3a2e674/crates/benilla-ui/src/script/object/frame_state.rs#L326).
This source reference does not identify the packaged client's exact revision;
CI-only mocks cover the explicit hidden/reparent/layer boundaries without
launching the game.

### Dragonflight movement reference

The behavior reference is [Dragonflight 10.2.7 EditModeSystemTemplates.lua](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_EditMode/Mainline/EditModeSystemTemplates.lua)
(selection, arrow keys, `OnDragStop`) and
[EditModeUtil.lua](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_EditMode/Mainline/EditModeUtil.lua)
(`GetMagneticFrameInfos`, physical capture range and corner priority).
[DragonUI’s editor panel](https://github.com/NeticSoul/DragonUI/blob/6cfcd75a2e5762637322fd495cd4302b203b77df/DragonUI/core/editor_panel.lua)
provides the verified manager/selected-frame-popup arrangement; its custom green
tint is not used. This is an independent implementation using SDUI’s native
ownership and transaction, not an imported retail framework.

Moving mode previews magnetism while the pointer remains free, then takes a fresh
release sample before applying it. The eight-pixel capture range is converted by
UIParent’s effective scale. Frame magnets consider adjacent edges with overlapping
perpendicular spans and their nearest non-diagonally-opposed corners. Corner
priority wins; otherwise one closest frame axis wins, while screen/grid magnets
may settle both axes. There is no old twelve-unit latch during retail movement.
Grid hiding suppresses only grid lines/magnets, preserving screen/frame snapping
and preview lines. The preview’s pooled owner is separate from the hidden grid.

`layoutSnapEnabled` and `layoutGridSpacing` live in the existing display table,
with defaults true/32 and spacing normalized to 8–128 whole UI units. This is
SDUI’s supported spacing range, not a claim about retail’s C-side constants.
The standard display preview, Confirm/Save and close, Cancel, profiles and full
resets apply. Arrow nudging is one UI unit, or ten with Shift, and yields to a
focused numeric input. Edit Mode does not launch or read additional game APIs.

SDUI does not persist retail’s frame-to-frame docking links or per-spec layouts.
The destination keeps absolute geometry, its existing profile page and only its
own registered HUD groups. These are explicit compatibility boundaries; the
source review and static artwork do not establish exact live retail parity.

### Full-editor alignment

Both modes support a screen-wide alignment grid behind the HUD and editing controls by default. **Show grid** in `/sdui` → **Layout** turns it off immediately, including subdivisions and gold guides; Shift alignment still works. `layoutShowGrid` is a normalized boolean in the existing display table, default true for missing/invalid values and both full resets, using shared preview, Confirm, Cancel/discard and profiles. Squares are 32 UI units apart, measured outward from the exact screen center, with stronger lines every four squares. The horizontal and vertical center axes are gold and two physical pixels thick; other lines are one physical pixel thick. In the full editor, during Shift-drag, faint eight-unit subdivisions appear and the frame's edges and center can align with the grid, nearby edit outlines or matching screen edges/center. Two thin gold lines show the active horizontal and vertical alignments. Releasing Shift restores free movement and hides the guides and subdivisions. The grid overlay remains mouse-transparent.

Body dragging uses the original cursor-to-frame offset in UIParent units. Changed pointer/modifier samples derive the owner position from that original sample. Snapping measures the actual edit `region`, including inherited scale and its offset from the owner, then reuses that shape between refreshes. This keeps alignment tied to the compact Level Up panel, extended action artwork and other visible edit bounds. Snapping never changes another group's geometry. Corner resizing and numeric input retain their existing behavior. Width and row handles use the same drag lifecycle described below.

Each axis considers the moving region's two edges and center. Screen candidates match the same edge or center, keeping the full region on screen when seated at an edge. Other edit outlines offer all edge/center pairings when their perpendicular spans overlap or are within 96 UI units. Candidate availability shares the handle renderer's rules, so closed windows and inactive detached groups do not create invisible magnets; the normal handles for inactive HUD groups remain eligible. The closest screen/frame alignment within eight UI units captures before grid fallback. A captured alignment holds until twelve units away, or until its perpendicular gap exceeds 128 units, so nearby competing points do not flicker. Unavailable targets release on the next geometry refresh; registered show/hide transitions request that refresh for the next frame.

Grid fallback chooses the closest edge/center alignment on the eight-unit subdivisions derived from `GRID_SPACING / 4`. Exact half-step ties round away from the screen center. The renderer shares that spacing and pools subdivision textures. Two pooled native `WHITE8X8` guide textures cache their position, viewport and physical-pixel size. No snapping preference or target identity is saved; the latch lives only in the current drag.

Only an active Shift-drag measures snap targets; free movement does not scan them. The release handler applies the current cursor/modifier state before capturing the position, including a release between update frames. A viewport/scale transition finishes at the last valid position. Releasing Shift, ending the drag or closing editing clears the guides and magnetic hold. Movement remains a draft until Confirm; Cancel, world/logout/reload discard and both resets use the existing lifecycle. Profiles retain snapped geometry through the same normalized coordinates, without extra layout fields.

## MSBT-style scrolling

With **Custom** and **MSBT-style scrolling** enabled in **Combat text**, the
**MSBT-style scrolling** outline appears in both `/sdui` and `/sdui lock`, even
before a hit arrives. Drag it to move the outgoing stream, or use its numeric
position and scale in **Layout**. Corner handles scale the whole stream; **SCT
size** retains its existing control over individual labels. Confirm saves the
layout. Cancel, world/logout/reload discard, profiles and both resets use the
shared lifecycle.

The `sctMSBT` owner defaults to a 240-by-220 edit box centered 160 units right of
WorldFrame center. Its caption reuses all fourteen existing translations of
**MSBT-style scrolling**. Its handle and snap target retire when the style or
Custom mode turns off. **Hide frame** clears active/queued scrolling hits and
skips hidden intake and painting; only new hits appear after unhiding. Saved
scrolling geometry never moves or hides over-enemy combat text.

## Width and row handles

Selecting Player, Target, Party frames, Run timer, Boss health, Revive, DPS meter,
Chat or Guardian tracker shows **Width (frame units)** in both the `/sdui lock`
popup and `/sdui` → **Layout**. The shared slider previews whole-unit widths
within each group's existing limits. It keeps the frame center, current scale
and height; player/target/party health content stretches through the existing
resize callback without enlarging portraits, fonts or end caps. Other groups
hide the slider and its reserved space. Pending valid numeric edits apply first;
invalid input stays visible and blocks the width change. Confirm or Save and
close saves the shared draft; Cancel and the existing discard paths restore it.
Profiles and both resets retain the same Layout geometry owner. Merely selecting
Revive preserves automatic caption fitting; moving its slider chooses an explicit
width. Switching between editors reuses the same slider and current width.

Run timer, Boss health, Revive, DPS meter, Chat and Guardian tracker have handles at the center of their left and right sides. These change width only, keeping fonts, icons and row heights at their current scale. HUD corners still scale proportionally; Chat retains its existing corner dimension resizing. The opposite edge stays fixed during side dragging, and release samples the current pointer before saving the draft.

Top and bottom handles change the number of rows for DPS meter, Boss health and Guardian tracker. DPS uses its existing `meterRows` preference (1–10, default six), synchronized with **Abilities shown**. Boss and guardian viewports use normalized `bossRows` / `guardianRows` integers in the same display table: zero means the original automatic full list; a dragged choice selects 1–40 slots. Mouse wheel scrolling reaches other accepted native entries. These are view limits, never native roster or meter-data limits. Boss debuffs retain their icon size, wrap to the current width and add their required height below each visible health row. Chat's top/bottom handles change message viewport height using its existing native dimensions. Run timer and Revive have no row handles.

HUD side widths live beside scale/position in `SurvivorsDragonUiLayout`, copied by the existing layout/profile normalizer. Meter and guardian settings no longer contain width sliders or display width preferences. Both default to 240 with limits 120–960. Run timer and boss health retain a 296-unit outer default (280-unit fill), with limits 120–1200. Revive retains automatic caption fitting until a width is chosen, with limits 160–1200; Chat retains its native 240–2400 width and 120–1600 height limits. Confirm, Cancel, world/logout/reload discard, profiles and both full resets retain their shared behavior. Resizing does not re-enable a disabled meter or collect data from it.

The original six groups use twenty one-texture edge marks, all under their existing hidden handles. It uses the existing controller; unchanged pointer and root dimensions skip resizing work. Dynamic row/debuff height changes trigger a fresh opposite-edge calculation even at a stationary pointer. Viewport changes retain the last valid geometry. Width changes invalidate only the owning view's existing deferred presentation. No new asset, updater or SavedVariable is added. Source inspection and pinned formatting do not establish packaged-game appearance or input behavior.

Player, Target and Party frames also have width-only side handles. Player and target place them at the sides of their compact border outlines; party uses the sides of its four-row edit region. Unit roots retain proportional corner scaling. Their width delta extends health and its straight metal spans while keeping portraits, end caps, bar heights and fonts fixed. Existing portrait hiding, health labels and resource-row choices retain the same width. The large-frame outline uses prepared artwork bounds and enabled caption heights, switching to the actual closed border when portraits are hidden. Target bounds also include the shown aura buttons already discovered by the shared tooltip registry. The optional shared `refreshRegion` callback runs before handle and drag/snap measurements so pending caption metrics retry through the existing editor controller; corner scaling uses the compact region while saving the original native owner geometry. Six additional solid-texture marks use the same shared controller and store. See `UNIT-PORTRAITS.md` for native-width limits, mirrored geometry and rendering costs.

## Party frames

**Party frames** is one layout group in `/sdui` and `/sdui lock`. Its outline spans all four styled native party rows, including empty slots while solo. Movement, proportional corner resizing, Shift alignment, numeric controls and Hide frame use the existing shared layout entry. Confirm alone saves `partyFrames` geometry in `SurvivorsDragonUiLayout`; Cancel, world/logout/reload discard, profiles and both full resets use the same lifecycle as other groups.

`modules/unit/mini.lua` parents the four native unit buttons to a passive `DFRL_PartyFrames` owner. Its default footprint matches the first native row, retaining the existing first-row position at the left screen edge plus `(10, 220)`. The first row anchors to that owner; later rows retain their native chains through the preceding row's pet frame. A separate edit region anchors to the first and last styled border textures, so native row spacing and pet-driven offsets remain reflected in move/resize and snap bounds. The native party background inherits the same owner when available. Native unit Show/Hide requests, clicks, unit IDs, values, portraits, auras, names and resource display remain with their existing widgets; editing never shows inactive party members.

The caption is present in all fourteen source/runtime catalogs. This adds no asset, SavedVariable or updater. Source inspection covered native anchor chains and the shared save/discard paths; the edited files were formatted with pinned StyLua 2.6.0 and Prettier 3.9.10. Local tests, standalone validation and addon/game execution were not run. In-game movement and appearance remain unverified; GitHub Actions was not awaited.

## Editor refresh work

Settled handle sizes and the grid are checked at most ten times per second, rather than once per rendered frame. Existing show/hide requests, new registrations, numeric Apply, profile loading, drag completion, editor entry and viewport changes request a refresh on the next frame. Shift-drag transitions also refresh the grid immediately. Native anchors keep handle positions attached to their regions; an active resize updates its own outline on every changed pointer sample. The bounded refresh still detects HUD size changes made outside the editor without adding native geometry hooks or another updater.

The visible Layout page retains its ten-Hz coordinate sampling and protects focused or unapplied input. It caches the selected entry, geometry, hidden state and language. Unchanged samples skip formatting and widget writes; changed samples use the shared text helper and write the checkbox or height-field visibility only when necessary. Explicit selection, Apply, discard and page-show refreshes bypass the sample cache so edited text can always be restored.

Shift-drag caches the screen, visible source shape and eligible target bounds in records reused throughout that drag. It refreshes measurements at ten Hz, immediately after editor invalidation and on the final release sample. Only actual changes to the source/target geometry or membership advance the cache revision. An unchanged cursor, Shift state and revision skip snap searches and position writes; changed input still runs at the render cadence. Candidate and latch records are reused rather than allocated while searching, retaining the same candidate order, capture/release distances, ties and grid fallback. Releasing Shift forces fresh measurements on the next Shift press. All drag caches retire with the existing drag state.

`core/layout.lua` lazily creates the grid from pooled native `WHITE8X8` textures. It uses `GetLocalSize(UIParent)` for rendered extents and effective UI scale for line thickness. While editing, viewport/scale changes or entering/leaving Shift-drag rebuild grid geometry; surplus lines hide and later sessions reuse the pool. The shared close path hides it immediately on Confirm, Cancel, either reset, world leave, logout or reload discard. Invalid numeric input keeps the existing session and its grid open. Switching between `/sdui` and `/sdui lock` keeps the same centered grid. The grid switch uses the existing display preference table; it adds no asset, SavedVariable or layout entry.

`core/layout.lua` owns the session, mode, handles and Confirm button. The settings dialog registers one visibility callback; run-font editing still owns its existing previews and saving. The moving manager and full dialog share one confirmation control and no parallel layout store. A closed session clears the handles-only mode, so ordinary `/sdui` continues to open the full editor.

The performance follow-up was formatted locally with pinned StyLua 2.6.0 and Prettier 3.9.10. Source/diff inspection covered idle and active paths, current modifier capture on release, target retirement, numeric input and shared Confirm/Cancel/profile/world/reset behavior. Local tests, standalone syntax/validation checks and addon/game execution were not run; runtime input, appearance and FPS impact remain unverified. GitHub Actions was not awaited.
