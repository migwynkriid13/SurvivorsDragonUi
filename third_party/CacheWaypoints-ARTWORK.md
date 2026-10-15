# Cache and guardian waypoint artwork

These files contain actual Blizzard World of Warcraft waypoint artwork. Cache/navigation textures were downloaded from the Gethe UI texture mirror on 2026-10-15. The guardian marker was extracted from the Dragonflight 10.2.7 client atlas through Wago's client-data service on the same date. They are not generated approximations.

Original artwork and World of Warcraft are copyright Blizzard Entertainment. The mirror provides access to the source files; this attribution does not assert a separate redistribution license.

## Pinned texture sources

The cache/navigation texture mirror snapshot used here is `9.2.7 (45114)`, commit `d23deaf8f44a7d280dc974a5c9d5321c013db59b`. Dragonflight's UI source still names the corresponding waypoint and navigation atlases; see the pinned Dragonflight references below. Those source texture files are from this earlier retail snapshot. The separate guardian marker below comes directly from Dragonflight.

- [Original tracked minimap waypoint PNG](https://raw.githubusercontent.com/Gethe/wow-ui-textures/d23deaf8f44a7d280dc974a5c9d5321c013db59b/MINIMAP/Minimap-Waypoint-MapPin-Tracked.PNG)
- [Original navigation atlas PNG](https://raw.githubusercontent.com/Gethe/wow-ui-textures/d23deaf8f44a7d280dc974a5c9d5321c013db59b/Navigation/IngameNavigationUI.PNG)
- [Original map waypoint atlas PNG, inspected as an additional reference](https://raw.githubusercontent.com/Gethe/wow-ui-textures/d23deaf8f44a7d280dc974a5c9d5321c013db59b/Waypoint/WaypoinMapPinUI.PNG)

## Dragonflight UI references

These references are pinned to Dragonflight `10.2.7 (54847)`, commit `88f272e94c202ecbe11fa44945f6035c65c15176`:

- [SuperTrackedFrame.xml](https://github.com/Gethe/wow-ui-source/blob/88f272e94c202ecbe11fa44945f6035c65c15176/Interface/AddOns/Blizzard_QuestNavigation/SuperTrackedFrame.xml) uses `Navigation-Tracked-Icon` and `Navigation-Tracked-Arrow`.
- [SuperTrackedFrame.lua](https://github.com/Gethe/wow-ui-source/blob/88f272e94c202ecbe11fa44945f6035c65c15176/Interface/AddOns/Blizzard_QuestNavigation/SuperTrackedFrame.lua) positions the navigation icon at its center and rotates the arrow to point toward the tracked destination.
- [WaypointLocationDataProvider.lua](https://github.com/Gethe/wow-ui-source/blob/88f272e94c202ecbe11fa44945f6035c65c15176/Interface/AddOns/Blizzard_SharedMapDataProviders/WaypointLocationDataProvider.lua) uses `Waypoint-MapPin-Tracked` and `Waypoint-MapPin-Untracked`.

## Guardian marker: Dragonflight client artwork

The guardian icon is Dragonflight's `VignetteKillElite` rare-elite marker: a gold star with a silver dragon surround. It is not a skull. Sources are pinned to client build `10.2.7.54847`:

- [UiTextureAtlasMember client metadata](https://wago.tools/db2/UiTextureAtlasMember/csv?build=10.2.7.54847): member `4737`, element `4951`, atlas `647`, rectangle `[265, 131, 329, 195)`, native display override `32 × 32`.
- [UiTextureAtlasElement client metadata](https://wago.tools/db2/UiTextureAtlasElement/csv?build=10.2.7.54847): element `4951`, `VignetteKillElite`.
- [UiTextureAtlas client metadata](https://wago.tools/db2/UiTextureAtlas/csv?build=10.2.7.54847): atlas `647`, `1024 × 1024`, FileDataID `1121272`.
- [Original client atlas](https://wago.tools/api/casc/1121272?version=10.2.7.54847): `interface/minimap/objecticonsatlas.blp`, FileDataID `1121272`.

The source atlas was decoded and visually inspected before cropping. `Guardian.tga` preserves the 64-by-64 source glyph's colors and transparency without rescaling. Its square bounds include the dragon surround; use full texture coordinates. The original atlas specifies a native 32-by-32 display size, while the compact square HUD draws it at 20 by 20. Cache and guardian HUDs reuse the same original retail direction-arrow artwork.

## Texture preparation

The PNG originals were visually inspected before cropping. Original colors and transparency are retained. Outputs are uncompressed, 32-bit RGBA TGA files with power-of-two canvas dimensions. No addon or game code was executed during preparation.

| Bundled file                        | Canvas  | Preparation                                                                                                             |
| ----------------------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------- |
| `media/tex/waypoint/MapPin.tga`     | 32 × 32 | Complete original tracked minimap PNG, converted to TGA without cropping or rescaling.                                  |
| `media/tex/waypoint/HudDiamond.tga` | 32 × 64 | Original navigation atlas pixel rectangle `[28, 0, 54, 37)`, placed at `(3, 13)` on a transparent canvas. No rescaling. |
| `media/tex/waypoint/HudArrow.tga`   | 32 × 32 | Original navigation atlas pixel rectangle `[0, 35, 24, 55)`, placed at `(4, 6)` on a transparent canvas. No rescaling.  |
| `media/tex/waypoint/Guardian.tga`   | 64 × 64 | Dragonflight 10.2.7 `VignetteKillElite`, original atlas rectangle `[265, 131, 329, 195)`, without rescaling.            |

Pixel rectangles use a top-left origin and exclusive right/bottom edges.

## Drawing recommendations

Square waypoint frames preserve the original textured gold pill artwork using eight slices from `BorderLeft.tga`, `BorderCenter.tga` and `BorderRight.tga`, with the center omitted. The tight column ranges are `[5, 16)`, `[0, 64)` and `[19, 30)` respectively, divided into source row thirds `[5, 12)`, `[12, 19)` and `[19, 26)`. At art scale 1.5, fixed 16.5-by-10.5 corners retain the original bevels and the visible gold rim is three pixels thick; only straight middle sections stretch. ADD blending at 0.9 alpha removes black outer shadow. Seven `media/tex/timer/BackgroundCenter.tga` strips at 0.45 alpha follow the inner cut-corner contour without background caps. No new texture assets are added. The marker and arrow share the top row, with the arrow rotating in place; the name and distance are stacked below. Existing timer artwork attribution is retained in [WidgetStatusBar-SOURCE.md](WidgetStatusBar-SOURCE.md).

- Map/minimap pin: use the full `MapPin.tga` texture on a 32 × 32 frame. Its visible diamond is centered at `(16, 16)`, with transparent padding around it. Scale the frame uniformly as needed.
- Cache HUD marker: draw the original `HudDiamond.tga` at 14 × 20 using `SetTexCoord(3 / 32, 29 / 32, 13 / 64, 50 / 64)`. Keep it upright in the square frame's top graphic row.
- Direction arrow: use the full `HudArrow.tga` texture on a square 18 × 18 frame for both cache and guardian guidance, rotating in place beside the top-row marker without orbiting. Its artwork points upward at zero rotation and is centered in its source canvas at `(16, 16)`. Both guides use exactly the same arrow size. A vanilla port should use its supported texture-coordinate rotation rather than assume retail `Texture:SetRotation` exists.
- Guardian marker: use the full `Guardian.tga` texture, at 20 × 20 in the square HUD and the existing independent world-map size. Keep the silver dragon and gold star upright.
- Square frame: keep the original textured gold artwork's fixed beveled corner slices, three-pixel visible rim and straight middle edges, with the dark inset following the inner contour described above. Both dimensions equal 95% of the combined DEFAULT action-bar artwork and XP border height, using static addon-owned appearance metadata. Stack the marker/arrow row, centered DEFAULT 9 name and bottom DEFAULT 10 distance inside the square. Uniform HUD scaling preserves the square proportions.
- Addon paths use `Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\waypoint\\` with the filenames above.

These assets provide artwork only. They do not add native waypoint APIs, enemy/cache coordinates, or world-to-screen projection capabilities to the 1.12 client.
