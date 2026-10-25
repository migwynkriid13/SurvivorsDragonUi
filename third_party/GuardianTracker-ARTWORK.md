# Guardian tracker artwork

The selected tracker combines **04 Quest header list** with **09 Timer bezel
rows**, but health bars appear only for native `awake` guardians whose current
spawn id has valid health. Resting living guardians remain text-only; nonliving lairs appear only when expanded. Native data, not
colour or a local timer, determines fighting and return states.

## Header

- Original file: [NeticSoul/DragonUI QuestTracker.BLP](https://github.com/NeticSoul/DragonUI/blob/5aefa049d22ba1a9e968b433d96eed7be86d6ac9/DragonUI/Textures/UI/QuestTracker.BLP),
  pinned commit `5aefa049d22ba1a9e968b433d96eed7be86d6ac9`.
- Original canvas: 1024 by 512, uncompressed BGRA BLP2. The original bytes are
  retained separately as a research input; the decoded full source and isolated
  preview crop are in `docs/designs/guardian-tracker/`.
- Verified region: `(11, 247, 571, 317)`, right/bottom excluded, 560 by 70.
  [`utils/atlas.lua`](https://github.com/NeticSoul/DragonUI/blob/5aefa049d22ba1a9e968b433d96eed7be86d6ac9/DragonUI/utils/atlas.lua)
  names it `QuestTracker-Header` with those exact UV fractions.
- Its owning [`modules/objectivetracker.lua`](https://github.com/NeticSoul/DragonUI/blob/5aefa049d22ba1a9e968b433d96eed7be86d6ac9/DragonUI/modules/objectivetracker.lua)
  maintains width-to-height ratio eight, uses alpha 0.9 and separate expand/collapse
  button states. This tracker preserves that ratio at alpha 0.8 and uses the
  existing minimap control below, without importing source-addon code.
- Prepared file: `media/tex/guardians/Header.tga`, 1024 by 128, uncompressed
  32-bit RGBA TGA, source pixels at `(0, 0)` without colour changes. All padding
  is transparent. Runtime UVs are `(0, 560/1024, 0, 70/128)` and ordinary alpha
  blending is used. The frame begins at 318.4 UI units wide and can grow to fit
  translated captions; header height remains width divided by eight.

The source notices identify RetailUI as this atlas's conduit. This is older
retail-style artwork, not a verified Dragonflight, War Within or Midnight-exclusive
header. The three expansion source comparisons and unresolved later atlas
rectangles are recorded in [the design study](../docs/designs/guardian-tracker/ARTWORK.md).
A current branch name is not treated as expansion evidence.

## Existing art reused

The upright header medallion is the existing `GuardianFloating.tga` crop
`(0, 0, 65, 65)` on a 128-by-128 canvas, drawn at 28 by 28. Its published source
and Blizzard attribution remain in [CacheWaypoints-ARTWORK.md](CacheWaypoints-ARTWORK.md).

Fighting rows reuse the original timer `BorderLeft`, `BorderCenter`, `BorderRight`,
`BackgroundCenter` and `FillWhite` TGA files. Their exact crops, pinned mirror and
Dragonflight atlas metadata are in [WidgetStatusBar-SOURCE.md](WidgetStatusBar-SOURCE.md).
Bezel height is 22; fixed 25-by-22 end caps surround a stretched straight middle.
The three pieces meet edge to edge, as in the regular boss pills. The former
five-unit overlap at each join composited the borders' translucent shadows
twice, producing black bands above, across and below the health fill. Removing
that overlap retains the original texture pixels, outer dimensions and fill.
The inner 11-unit health fill reads the exact spawn-matched native health
fraction and uses the regular boss-bar tint `(0.86, 0.12, 0.1, 1)`. Its centred
white DEFAULT 12 text shows current / maximum health, with the same floor-based
formatting as regular boss bars. Both views share `core/widgets.lua` style/text
helpers. Resting guardians are labelled **Alive**; no Fighting caption or
percentage is displayed. No return timer has a progress
bar, and no missing health value creates a placeholder fill.

Names use DEFAULT 12 and the header DEFAULT 14, without an alive counter, all with
OUTLINE and black shadow. Header/body text is pale gold; text-only states use the
chosen subdued green, red, amber and grey palette. Row height is 26. Actual glyph
widths are measured across all fourteen translations; no external font is shipped.
The complete tracker defaults to scale `0.85`, making the artwork, text and rows
15% smaller together. The name/status column gap is `14.4` local units, 10% less
than the original `16`, without shortening the name column or status measurements.

## Rights and payload

World of Warcraft artwork is copyright Blizzard Entertainment. The selected
[third-party notices](https://github.com/NeticSoul/DragonUI/blob/5aefa049d22ba1a9e968b433d96eed7be86d6ac9/DragonUI/THIRD_PARTY_NOTICES.md)
exclude Blizzard textures from the source's
[MIT software license](https://github.com/NeticSoul/DragonUI/blob/5aefa049d22ba1a9e968b433d96eed7be86d6ac9/DragonUI/LICENSE.txt)
and describe their use inside the game. Public hosting is not a new artwork
license. The shipped `modules/ui/guardian_tracker.lua` preserves this distinction
and the exact source notice; no source-addon software is copied.

Only `Header.tga` is newly added to `packaging/runtime-files.json`; timer and
medallion files already ship. The complete atlas, original BLP, previews, research
and tools stay outside the ZIP. Native retail atlas APIs or dependencies are not
used. Artwork inspection and static compositions do not establish packaged-game
rendering. No local checks or addon/game execution were run.

## Minus/plus control

The header reuses exactly the addon's existing gold minimap controls. The source
is the already-shipped `media/tex/minimap/` artwork at base commit
`8779289c7ba30ac9be424d7a396628f5cda13ea1`:

- Plus: [ZoomIn32.tga](https://github.com/migwynkriid13/SurvivorsDragonUi/blob/8779289c7ba30ac9be424d7a396628f5cda13ea1/media/tex/minimap/ZoomIn32.tga),
  with `ZoomIn32-push.tga`, `ZoomIn32-over.tga` and `ZoomIn32-disabled.tga`.
- Minus: [ZoomOut32.tga](https://github.com/migwynkriid13/SurvivorsDragonUi/blob/8779289c7ba30ac9be424d7a396628f5cda13ea1/media/tex/minimap/ZoomOut32.tga),
  with `ZoomOut32-push.tga`, `ZoomOut32-over.tga` and `ZoomOut32-disabled.tga`.

All eight 32-by-32 TGA canvases were visually inspected, including their
transparency. Their full texture regions are reused without any crop, conversion,
recolouring or new texture file. Existing artwork notices and project permission
remain applicable; no new expansion provenance is inferred for these inherited
images. `T.StyleMinimapZoomButton` supplies the same normal, pressed, hover and
disabled paths for both minimap buttons and the tracker. The tracker draws at
25.6 by 25.6, keeping its button in the former count position. Minimap placement,
scale, native zoom actions and state handling stay unchanged.
The tracker toggle inherits the tracker's smaller default scale. The tracker
places its health pills' right edge beneath the default minimap right edge,
using shared minimap appearance metadata and independent UIParent anchors.
The default root compensates for the row inset and health pill's right offset.
Text-driven width changes retain that edge only for an unpositioned tracker;
confirmed and draft placements remain independent.

The normal `ZoomIn32.tga` plus glyph is two source pixels left of the other
states: its bright-gold horizontal bounds are `[3, 25)`, compared with `[5, 27)`
for the minus and pressed plus. The tracker's optional glyph alignment shifts
only that normal plus texture right by `button width * 2 / 32` (1.6 local units
at width 25.6). Both full-canvas anchors receive the same offset, preserving its
size, UVs and artwork. Other states use zero offset; every reassignment first
clears old texture anchors. The button, hit box, header and root anchors remain
fixed. Native minimap buttons retain their existing style and state handling.

**Plus means collapsed:** show only living guardians, including combat guardians.
**Minus means expanded:** show every accepted lair, including respawn timers, due
and empty rows. Native due rows display **Alive** in the resting guardian green;
this optimistic caption supplies no health or change to native occupancy/filtering.
Mode changes compact the rows in native order without clearing
accepted data or selections. A collapsed list with no living guardians keeps its
header and plus button so it can be expanded.

The button is disabled during layout editing and has translated action hints.
Its session-only state adds no setting or SavedVariable, and both shared resets
restore expanded mode. Only effective mode changes reassign the texture states.
The atlas minus/plus candidate was superseded by this explicit request and is not
included in source or runtime payload. No new control artwork or dependency is
introduced; the selected quest-tracker header remains the sole new texture.
