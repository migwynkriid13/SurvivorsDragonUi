# Cache and guardian waypoint artwork

The tracked-map and navigation textures use Blizzard World of Warcraft artwork downloaded from the Gethe UI texture mirror on 2026-10-15. The silver guardian crest is shared by the overhead marker, HUD, minimap and tracker header. The cache chest is the separate user-supplied artwork documented below. These icons are not generated approximations.

Original artwork and World of Warcraft are copyright Blizzard Entertainment. The mirror provides access to the source files; this attribution does not assert a separate redistribution license.

## Selected 02 Winged Soul

The fallen-ally HUD and minimap use Blizzard's original **Raid-Icon-Rez** glyph
from the early Dragonflight **10.0.0 (45454)** texture snapshot, Gethe commit
`e80e3278cc833c89e1f3fc79557b68315d750935`:
[RAIDFRAME/Raid-Icon-Rez.PNG](https://raw.githubusercontent.com/Gethe/wow-ui-textures/e80e3278cc833c89e1f3fc79557b68315d750935/RAIDFRAME/Raid-Icon-Rez.PNG).
The downloaded PNG SHA-256 is
`52a1a0d74736d71335a2342830cb14a46bfdc2937c96a187da50cb6eaa5d134c`.

The complete 64 × 64 canvas and RGBA pixels are retained: full UVs `(0, 1, 0, 1)`,
without cropping, tinting or resampling. Visible alpha occupies `[4, 0, 60, 60)`.
`media/tex/waypoint/FallenAlly.tga` is the lossless authoring source;
`scripts/prepare_client_textures.py` prepares `FallenAlly.blp` for runtime. Only
the BLP ships. It draws at 32 units in the HUD and 20 on the minimap.

[Dragonflight CompactUnitFrame.lua](https://github.com/Gethe/wow-ui-source/blob/88f272e94c202ecbe11fa44945f6035c65c15176/Interface/AddOns/Blizzard_UnitFrame/Mainline/CompactUnitFrame.lua#L1283)
uses `Interface\\RaidFrame\\Raid-Icon-Rez` for incoming resurrection. This addon
reuses the glyph as a fallen-ally waypoint; its presence does not mean someone is
already resurrecting that member. The design name **Winged Soul** labels the
user-selected proposal, rather than an official atlas name. Blizzard retains
the artwork copyright; the public mirror supplies no additional artwork license.

## Revive-beacon studies

[Animated comparison](../docs/previews/revive-beacons.webp) uses the original
64 × 64 Winged Soul glyph above the same simulated ground in all five designs.
The lower-right panel records an earlier chest trial from the design study.

The following preview components come from Blizzard's early Dragonflight
10.0.0 (45454) texture snapshot at Gethe commit
`e80e3278cc833c89e1f3fc79557b68315d750935`. Crop rectangles are top-left
inclusive and bottom-right exclusive.

| Study             | Artwork and assembly                                                                                                                                                   |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 01 Dawn Column    | Original shaft and existing soft pool, in pale gold.                                                                                                                   |
| 02 Kyrian Wake    | Blue shaft plus two tilted cyan ribbons from the 1024 × 512 [Covenant celebration sheet][celebration], crop `(413, 0, 775, 72)`.                                       |
| 03 Spirit Flare   | Narrow white shaft and the complete 128 × 128 [Cooldown starburst][starburst] and [star4][star4] textures. [Cooldown.xml][cooldown] binds `star4` as its finish flash. |
| 04 Emerald Return | Soft green shaft over two opposed crops of the celebration sheet's green braid `(12, 264, 352, 337)`.                                                                  |
| 05 Anima Rift     | Two angled shafts over the celebration sheet's blue swirl `(12, 393, 345, 466)`, with a faint Cooldown starburst beneath it.                                           |

[Blizzard's covenant toast][toast] uses the same celebration art family. The
crop placements, color choices, layers and motion shown here are custom
assemblies. The selected **02 Kyrian Wake** uses the cyan ribbon crop in
`media/tex/waypoint/KyrianWake.blp`. The source sheet SHA-256 is
`ae744fc133b8b633b4b2a2ac6cbb81b835428b7a9c0716fe3121d41611d69694`.
The lower ribbon, original beam and soft pool are composited into one
128 × 256 BLP2 texture. The runtime uses full UVs and additive blending with
the ground reference at 150/174 of the canvas height. The other Blizzard
extracts appear in the comparison preview. Blizzard retains the artwork
copyright, and the mirror supplies no separate redistribution license.

[celebration]: https://github.com/Gethe/wow-ui-textures/blob/e80e3278cc833c89e1f3fc79557b68315d750935/CovenantChoice/CovenantChoiceCelebration.PNG
[starburst]: https://github.com/Gethe/wow-ui-textures/blob/e80e3278cc833c89e1f3fc79557b68315d750935/Cooldown/starburst.PNG
[star4]: https://github.com/Gethe/wow-ui-textures/blob/e80e3278cc833c89e1f3fc79557b68315d750935/Cooldown/star4.PNG
[cooldown]: https://github.com/Gethe/wow-ui-source/blob/88f272e94c202ecbe11fa44945f6035c65c15176/Interface/AddOns/Blizzard_FrameXML/Mainline/Cooldown.xml#L8
[toast]: https://github.com/Gethe/wow-ui-source/blob/88f272e94c202ecbe11fa44945f6035c65c15176/Interface/AddOns/Blizzard_CovenantToasts/Blizzard_CovenantChoiceToast.xml#L3-L25

## Pinned texture sources

The cache/navigation texture mirror snapshot used here is `9.2.7 (45114)`, commit `d23deaf8f44a7d280dc974a5c9d5321c013db59b`. Dragonflight's UI source still names the corresponding waypoint and navigation atlases; see the pinned Dragonflight references below. Those source texture files are from this earlier retail snapshot. The guardian medallion uses the separate pinned game-art source below.

- [Original tracked minimap waypoint PNG](https://raw.githubusercontent.com/Gethe/wow-ui-textures/d23deaf8f44a7d280dc974a5c9d5321c013db59b/MINIMAP/Minimap-Waypoint-MapPin-Tracked.PNG)
- [Selected 05 Quest spear PNG](https://raw.githubusercontent.com/Gethe/wow-ui-textures/d23deaf8f44a7d280dc974a5c9d5321c013db59b/MINIMAP/MiniMap-QuestArrow.PNG)
- [Former navigation-triangle atlas PNG](https://raw.githubusercontent.com/Gethe/wow-ui-textures/d23deaf8f44a7d280dc974a5c9d5321c013db59b/Navigation/IngameNavigationUI.PNG)
- [Original map waypoint atlas PNG, inspected as an additional reference](https://raw.githubusercontent.com/Gethe/wow-ui-textures/d23deaf8f44a7d280dc974a5c9d5321c013db59b/Waypoint/WaypoinMapPinUI.PNG)

## Dragonflight UI references

These references are pinned to Dragonflight `10.2.7 (54847)`, commit `88f272e94c202ecbe11fa44945f6035c65c15176`:

- [SuperTrackedFrame.xml](https://github.com/Gethe/wow-ui-source/blob/88f272e94c202ecbe11fa44945f6035c65c15176/Interface/AddOns/Blizzard_QuestNavigation/SuperTrackedFrame.xml) uses `Navigation-Tracked-Icon` and `Navigation-Tracked-Arrow`.
- [SuperTrackedFrame.lua](https://github.com/Gethe/wow-ui-source/blob/88f272e94c202ecbe11fa44945f6035c65c15176/Interface/AddOns/Blizzard_QuestNavigation/SuperTrackedFrame.lua) positions the navigation icon at its center and rotates the arrow to point toward the tracked destination.
- [WaypointLocationDataProvider.lua](https://github.com/Gethe/wow-ui-source/blob/88f272e94c202ecbe11fa44945f6035c65c15176/Interface/AddOns/Blizzard_SharedMapDataProviders/WaypointLocationDataProvider.lua) uses `Waypoint-MapPin-Tracked` and `Waypoint-MapPin-Untracked`.

## Texture preparation

The PNG originals were visually inspected before cropping. Original colors and transparency are retained. Outputs are uncompressed, 32-bit RGBA TGA files with power-of-two canvas dimensions. No addon or game code was executed during preparation.

| Preparation input                 | Canvas  | Preparation                                                                                                                                                        |
| --------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `media/tex/waypoint/HudArrow.tga` | 32 × 32 | Selected **05 Quest spear**: full `MINIMAP/MiniMap-QuestArrow.PNG` canvas. Visible alpha rectangle `[5, 4, 26, 27)` is 21 × 23. No crop, recoloring or resampling. |

Pixel rectangles use a top-left origin and exclusive right/bottom edges.

The selected source PNG SHA-256 is `bea3dd8c5fba2ec05c8b42b33678903c2ab98233870884fe33ac4d0f40f8c1a6`. The TGA preserves its complete RGBA canvas; `scripts/prepare_client_textures.py` prepares the lossless `HudArrow.blp` through the existing conversion helpers. Only that existing BLP path ships. Its decoded top-down BGRA base-level SHA-256 is `8411d1eec84a18dfe842807b6a8391bdb240685459ad1ff0ba757ec9d5dcece7`.

This replaces the former 24 × 20 navigation-triangle crop. Quest spear is a proposal label for Blizzard's shared quest-minimap direction artwork in the pinned Shadowlands snapshot, not an expansion-exclusive design or a new gameplay category. Cache, guardian and fallen-ally marker artwork is unchanged. No new runtime file, frame, region, setting, reader or updater is added; direction sampling, rotation, mirroring and both Performance Mode lifecycles retain their existing paths. Static artwork preparation does not verify native appearance.

## User-supplied cache chest

The user supplied `/Users/sebastijan/Downloads/chest.tga` on 2026-10-27 and
selected it for the cache guidance HUD, bottom cache-cost counter and minimap.
Its source SHA-256 is
`7417f8036d48a5df64497673f5fa93b07f907d978b0e347bbe35fec604caae1b`.
The 32-by-32 RGBA original is retained byte-for-byte as
`media/tex/waypoint/Chest.tga`, outside the runtime manifest. No further upstream
source is established for that supplied file.

`scripts/prepare_client_textures.py` prepares the shared `Chest.blp` without
cropping, scaling, recoloring or alpha changes. Every decoded RGB/alpha byte
matches the source, and full `0..1` UVs display it at the existing HUD/minimap/
counter sizes of 32/16/18 units. It replaces the former HUD/minimap pouch and
native tally loot cursor. `CachePouch.blp` is removed from the runtime manifest;
the unused `CachePouch.tga` preparation input is also removed. The full world-map overlay and runtime diamond have been removed. The local asset receipt and retired BLP backup are under
`/tmp/sdui-cache-chest-20261027/`; this is image-data evidence, not game execution.

## Guardian and former cache HUD artwork

The guardian crest uses Blizzard's `vignettekillelite` sprite. The source and
crop are documented in [EncounterIcons-ARTWORK.md](EncounterIcons-ARTWORK.md).
The retired loot-pouch HUD glyph came from DragonUI's
[`loot_bag.tga`](https://github.com/NeticSoul/DragonUI/blob/00197f223180323ea7297c0157edbd1a43d2f99f/DragonUI/Textures/Nameplates/Quests/Loot/loot_bag.tga).
DragonUI's code license excludes Blizzard's game artwork.

## Drawing recommendations

- Floating waypoint guides default to 190 by 46 with transparent backgrounds. Draw the icon, text and arrow without a bottom stripe, dark fill, enclosing border or native vertex gradient. The previous `FloatingRail.tga` is removed from the source and runtime manifest. Existing timer artwork and its [WidgetStatusBar attribution](WidgetStatusBar-SOURCE.md) remain unchanged.
- Cache HUD marker: draw `Chest.blp` in its existing 32-by-32 field with `SetTexCoord(0, 1, 0, 1)`. Keep the chest upright.
- Guardian HUD marker: draw `GuardianFloating.blp` in a 32-by-32 field with `SetTexCoord(0, 65 / 128, 0, 65 / 128)`.
- Place a left-aligned DEFAULT 13 destination title above DEFAULT 15 distance beside the icon, with outline and black shadow. Rotate the arrow in place to the right of the text.
- Direction arrow: retain the selected **05 Quest spear**'s full `HudArrow.tga` canvas and full UVs. Its 21 × 23 visible glyph on a 32 × 32 canvas draws at 24 units high and about 21.91 units wide using a full texture size of `24 * 32 / 23` (about 33.39 square). The original upward-facing artwork rotates around the same texture pivot. Cache, guardian and fallen-ally guides share this size and the existing supported texture-coordinate rotation, without assuming retail `Texture:SetRotation`.
- Default anchors use the midpoint of the combined DEFAULT action-bar artwork and XP border height from static addon-owned appearance metadata. Cache is left and Guardian right with an eight-unit gap beyond the artwork. Uniform HUD scaling preserves the 190:46 proportions; confirmed independent geometry stays in use.
- Addon texture paths use `Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\waypoint\\` with the filenames above.

These assets provide artwork only. They do not add native waypoint APIs, enemy/cache coordinates, or world-to-screen projection capabilities to the 1.12 client.

The minimap guardian and available-cache markers also reuse their floating HUD glyphs: `GuardianFloating.blp` with the `0..65/128` crop, and `Chest.blp` with full `0..1` coordinates, drawn at 20 by 20 local units for each guardian and 16 by 16 for caches. There are no full world-map pins. The same chest also serves the bottom cache-cost counter; no per-view image is needed.
