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

## Shared minimap control artwork

The tracker has no minus/plus header control. Its Show dead choice is a shared
editor checkbox. Existing minimap zoom controls retain the inherited artwork
from base commit `8779289c7ba30ac9be424d7a396628f5cda13ea1`:

- Plus: [ZoomIn32.tga](https://github.com/migwynkriid13/SurvivorsDragonUi/blob/8779289c7ba30ac9be424d7a396628f5cda13ea1/media/tex/minimap/ZoomIn32.tga),
  with `ZoomIn32-push.tga`, `ZoomIn32-over.tga` and `ZoomIn32-disabled.tga`.
- Minus: [ZoomOut32.tga](https://github.com/migwynkriid13/SurvivorsDragonUi/blob/8779289c7ba30ac9be424d7a396628f5cda13ea1/media/tex/minimap/ZoomOut32.tga),
  with `ZoomOut32-push.tga`, `ZoomOut32-over.tga` and `ZoomOut32-disabled.tga`.

The eight full source canvases and their ownership notices remain applicable;
no new expansion provenance is inferred for these inherited images. Their
prepared BLP counterparts remain in the runtime manifest for the minimap.
`T.StyleMinimapZoomButton` retains normal, pressed, hover and disabled paths for
native zoom buttons. The retired tracker-only glyph-offset branch is removed;
minimap placement, scale, zoom actions and texture-state geometry are unchanged.
The quest-tracker header and existing timer-bezel textures retain the source
records above. No new control artwork or dependency is introduced.
