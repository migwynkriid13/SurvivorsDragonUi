# Cache and guardian waypoint artwork

The icon files contain actual Blizzard World of Warcraft waypoint artwork. Cache/navigation textures were downloaded from the Gethe UI texture mirror on 2026-10-15. The guardian gold-dragon/skull medallion comes from the pinned game-art source below and is shared by the HUD, minimap, world map and tracker header. They are not generated approximations.

Original artwork and World of Warcraft are copyright Blizzard Entertainment. The mirror provides access to the source files; this attribution does not assert a separate redistribution license.

## Pinned texture sources

The cache/navigation texture mirror snapshot used here is `9.2.7 (45114)`, commit `d23deaf8f44a7d280dc974a5c9d5321c013db59b`. Dragonflight's UI source still names the corresponding waypoint and navigation atlases; see the pinned Dragonflight references below. Those source texture files are from this earlier retail snapshot. The guardian medallion uses the separate pinned game-art source below.

- [Original tracked minimap waypoint PNG](https://raw.githubusercontent.com/Gethe/wow-ui-textures/d23deaf8f44a7d280dc974a5c9d5321c013db59b/MINIMAP/Minimap-Waypoint-MapPin-Tracked.PNG)
- [Original navigation atlas PNG](https://raw.githubusercontent.com/Gethe/wow-ui-textures/d23deaf8f44a7d280dc974a5c9d5321c013db59b/Navigation/IngameNavigationUI.PNG)
- [Original map waypoint atlas PNG, inspected as an additional reference](https://raw.githubusercontent.com/Gethe/wow-ui-textures/d23deaf8f44a7d280dc974a5c9d5321c013db59b/Waypoint/WaypoinMapPinUI.PNG)

## Dragonflight UI references

These references are pinned to Dragonflight `10.2.7 (54847)`, commit `88f272e94c202ecbe11fa44945f6035c65c15176`:

- [SuperTrackedFrame.xml](https://github.com/Gethe/wow-ui-source/blob/88f272e94c202ecbe11fa44945f6035c65c15176/Interface/AddOns/Blizzard_QuestNavigation/SuperTrackedFrame.xml) uses `Navigation-Tracked-Icon` and `Navigation-Tracked-Arrow`.
- [SuperTrackedFrame.lua](https://github.com/Gethe/wow-ui-source/blob/88f272e94c202ecbe11fa44945f6035c65c15176/Interface/AddOns/Blizzard_QuestNavigation/SuperTrackedFrame.lua) positions the navigation icon at its center and rotates the arrow to point toward the tracked destination.
- [WaypointLocationDataProvider.lua](https://github.com/Gethe/wow-ui-source/blob/88f272e94c202ecbe11fa44945f6035c65c15176/Interface/AddOns/Blizzard_SharedMapDataProviders/WaypointLocationDataProvider.lua) uses `Waypoint-MapPin-Tracked` and `Waypoint-MapPin-Untracked`.

## Texture preparation

The PNG originals were visually inspected before cropping. Original colors and transparency are retained. Outputs are uncompressed, 32-bit RGBA TGA files with power-of-two canvas dimensions. No addon or game code was executed during preparation.

| Bundled file                        | Canvas  | Preparation                                                                                                             |
| ----------------------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------- |
| `media/tex/waypoint/MapPin.tga`     | 32 × 32 | Complete original tracked minimap PNG, converted to TGA without cropping or rescaling.                                  |
| `media/tex/waypoint/HudDiamond.tga` | 32 × 64 | Original navigation atlas pixel rectangle `[28, 0, 54, 37)`, placed at `(3, 13)` on a transparent canvas. No rescaling. |
| `media/tex/waypoint/HudArrow.tga`   | 32 × 32 | Original navigation atlas pixel rectangle `[0, 35, 24, 55)`, placed at `(4, 6)` on a transparent canvas. No rescaling.  |

Pixel rectangles use a top-left origin and exclusive right/bottom edges.

## Floating-label HUD icons

The selected HUD design uses actual Blizzard game textures distributed by [NeticSoul/DragonUI](https://github.com/NeticSoul/DragonUI/tree/00197f223180323ea7297c0157edbd1a43d2f99f), pinned to commit `00197f223180323ea7297c0157edbd1a43d2f99f`:

- [Guardian gold-dragon/skull medallion: `kill_elite.tga`](https://raw.githubusercontent.com/NeticSoul/DragonUI/00197f223180323ea7297c0157edbd1a43d2f99f/DragonUI/Textures/Nameplates/Quests/Kill/kill_elite.tga).
- [Cache loot pouch: `loot_bag.tga`](https://raw.githubusercontent.com/NeticSoul/DragonUI/00197f223180323ea7297c0157edbd1a43d2f99f/DragonUI/Textures/Nameplates/Quests/Loot/loot_bag.tga).
- [Pinned upstream LICENSE](https://github.com/NeticSoul/DragonUI/blob/00197f223180323ea7297c0157edbd1a43d2f99f/LICENSE).

DragonUI core code is copyright 2026 NeticSoul and DragonUI contributors under MIT. Its LICENSE explicitly excludes World of Warcraft game artwork from that core-code license: these textures are copyright Blizzard Entertainment and included only for use with the game. This change imports no upstream Lua. The shipped `modules/map/waypoints.lua` comment retains source attribution and this artwork notice; the public source document is not added to the runtime ZIP.

Original glyph pixels and alpha are retained without rescaling. Transparent source padding is cropped, then the glyph is centered inside a square transparent sampling region with at least one pixel of padding. Both outputs use uncompressed 32-bit RGBA TGA on power-of-two canvases:

| Bundled file                              | Original canvas | Source rectangle    | Output canvas | Placement and sampling                                                              |
| ----------------------------------------- | --------------- | ------------------- | ------------- | ----------------------------------------------------------------------------------- |
| `media/tex/waypoint/GuardianFloating.tga` | 64 × 64         | `[0, 1, 62, 64)`    | 128 × 128     | Paste at `(1, 1)`; square region `[0, 0, 65, 65)`, UV `0..65/128` on each axis.     |
| `media/tex/waypoint/CachePouch.tga`       | 128 × 128       | `[28, 7, 117, 124)` | 128 × 128     | Paste at `(15, 1)`; square region `[0, 0, 119, 119)`, UV `0..119/128` on each axis. |

Square sampling preserves each glyph's proportions inside its 32-by-32 HUD icon field. All guardian views reuse this medallion and crop, including the 26-by-26 world-map pin. The separate `MapPin.tga` cache pin remains unchanged. `HudDiamond.tga` is retained as a source reference for the previous HUD, but is no longer used or included in the runtime manifest.

## Drawing recommendations

- Floating waypoint guides default to 190 by 46 with transparent backgrounds and only a fine muted-gold stripe along the bottom. Draw the stripe at 190 by 1 using native `Interface\\Buttons\\WHITE8X8`, ordinary `BLEND` and `SetVertexColor(186 / 255, 148 / 255, 87 / 255, 85 / 255)`. Keep the stripe's bottom-left anchor at the HUD's bottom-left corner. Do not draw a dark fill, enclosing border or native vertex gradient. The previous `FloatingRail.tga` is removed from the source and runtime manifest. Existing timer artwork and its [WidgetStatusBar attribution](WidgetStatusBar-SOURCE.md) remain unchanged.
- Cache HUD marker: draw `CachePouch.tga` in a 32-by-32 field with `SetTexCoord(0, 119 / 128, 0, 119 / 128)`. Keep the loot pouch upright.
- Guardian HUD marker: draw `GuardianFloating.tga` in a 32-by-32 field with `SetTexCoord(0, 65 / 128, 0, 65 / 128)`. Keep the gold dragon and skull upright.
- Place a left-aligned DEFAULT 13 destination title above DEFAULT 15 distance beside the icon, with outline and black shadow. Rotate the arrow in place to the right of the text.
- Direction arrow: retain the full original `HudArrow.tga`. The selected preview has a 19-pixel-wide visible arrow; increase that visible width by 20% to 22.8. The original source glyph is 24 pixels wide on a 32-pixel canvas, so draw the full texture at `19 * 1.2 * 32 / 24 = 30.4` square. Its artwork points upward at zero rotation and is centered at `(16, 16)`. Both guides share this size and the existing supported texture-coordinate rotation, without assuming retail `Texture:SetRotation`.
- World-map cache pin: keep the full `MapPin.tga`, with its centered diamond and transparent padding. World-map guardian pin: reuse `GuardianFloating.tga` with its existing `0..65/128` crop on both axes. Existing 26-by-26 map pin bounds, selection and tooltip behavior remain unchanged.
- Default anchors use the midpoint of the combined DEFAULT action-bar artwork and XP border height from static addon-owned appearance metadata. Cache is left and Guardian right with an eight-unit gap beyond the artwork. Uniform HUD scaling preserves the 190:46 proportions; confirmed independent geometry stays in use.
- Addon texture paths use `Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\waypoint\\` with the filenames above.

These assets provide artwork only. They do not add native waypoint APIs, enemy/cache coordinates, or world-to-screen projection capabilities to the 1.12 client.

The minimap guardian and available-cache markers also reuse the floating HUD glyphs above: `GuardianFloating.tga` with the `0..65/128` crop, and `CachePouch.tga` with `0..119/128`, drawn at 20 by 20 local units for each guardian and 16 by 16 for caches. The world-map guardian pin reuses the same medallion and crop; the cache world-map pin retains its separate diamond texture. No additional artwork is needed.
