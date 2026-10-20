# Guardian tracker design artwork

Twenty proposals are in [index.html](index.html), with a complete
[overview](overview.png), four larger comparison sheets and full-size numbered
PNGs. Suggested starting points are **01 Waypoint ledger**, **03 Character metal
panel** and **16 Micro ledger**. These preserve the addon's gold DEFAULT text,
quiet dark surfaces, upright guardian glyph and restrained metal details.

All compositions were inspected as images. These are static proposals with
sample names/values and an Arial proxy for DEFAULT. They are not game captures.
The user selected proposal 04 with proposal 09 health bars only while fighting.
Only its prepared header crop joins the runtime manifest; the control reuses
already-shipped minimap textures; research images do not.
See [GuardianTracker-ARTWORK.md](../../../third_party/GuardianTracker-ARTWORK.md). `scripts/preview_guardian_designs.py` composes the previews from existing
artwork; it does not load or execute addon Lua. Keep original source bytes
separate from adapted crops.

## Artwork recipes

Letters beside each proposal identify its real artwork families. Source
rectangles below use a top-left origin and exclude the far right/bottom edge.
Ordinary alpha compositing is used throughout; only straight edges stretch.
Preview proportions and arrangement are design choices, not asserted retail
widget layouts. There are no proposed interactive controls requiring new hover,
pushed or disabled textures yet.

| Recipe | Asset, canvas and region                                                                                                                         | Source and adaptation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A      | `waypoint/GuardianFloating.tga`, 128 by 128, `(0, 0, 65, 65)`; `Guardian.tga`, full 64 by 64                                                     | The same upright medallion used by the current HUD, and the existing map glyph. [Pinned source and crops](../../../third_party/CacheWaypoints-ARTWORK.md). The medallion came via DragonUI commit `00197f223180323ea7297c0157edbd1a43d2f99f`, `Textures/Nameplates/Quests/Kill/kill_elite.tga`. The map glyph is Dragonflight 10.2.7.54847 `VignetteKillElite`, FileDataID 1121272, atlas rectangle `(265, 131, 329, 195)`.                                                                                                |
| B      | `editor/border.tga`, 1024 by 128, eight 128-square cells; `header.tga`, 256 by 32, `(0, 0, 199, 32)`; `choice.tga`, 256 by 64, `(0, 0, 187, 21)` | [Existing source coordinates and notices](../../../third_party/SDUI-ARTWORK.md), PentSec/DragonUI commit `623eca5893c9d475a7b77bd25808bdbe801d247c`, `DragonUI/Textures/ForeverUI/chrome-dialog.tga` and `chrome-options.tga`. Use fixed corners, stretched straight edges, an optional subdued header and the selected-row art. The gallery uses 25-unit editor corners.                                                                                                                                                  |
| C      | `character/Chrome.tga`, 1024 by 256; `Parts.tga`, 256 by 256                                                                                     | [Existing metal frame and card source regions](../../../third_party/Character-ARTWORK.md). The chrome comes through NeticSoul/DragonUI `6d9cc95eedd1de78fab3b965683df13421e21604`, `UI/uiframemetal2x.blp`, horizontal and vertical companions. Card pieces are Dragonflight PTR 10.0.0 (45454) source pixels at Gethe `e80e3278cc833c89e1f3fc79557b68315d750935`; top `(1, 65, 170, 74)`, bottom `(1, 1, 170, 47)`, middle repacked to `(1, 192, 170, 200)`. The renderer explicitly lists every chrome destination cell. |
| D      | `questtracker-source.png`, 1024 by 512; header `(11, 247, 571, 317)`, 560 by 70                                                                  | [Original QuestTracker.BLP](https://github.com/NeticSoul/DragonUI/blob/5aefa049d22ba1a9e968b433d96eed7be86d6ac9/DragonUI/Textures/UI/QuestTracker.BLP). Raw BGRA BLP2 was decoded without colour changes; the header is saved separately as `questtracker-header.png`. This is an older retail-style atlas conveyed by RetailUI, not a verified Dragonflight/TWW/Midnight-exclusive header.                                                                                                                                |
| E      | Timer `BorderLeft` / `BorderCenter` / `BorderRight`, 64 by 32 canvases; `BackgroundCenter`, 64 by 32; `FillWhite`, 256 by 16                     | [Exact source crops and atlas metadata](../../../third_party/WidgetStatusBar-SOURCE.md). Published [Gethe WidgetStatusBar.PNG](https://github.com/Gethe/wow-ui-textures/blob/d23deaf8f44a7d280dc974a5c9d5321c013db59b/Widgets/WidgetStatusBar.PNG), 9.2.7 (45114), with Dragonflight 10.1.5.50232 atlas metadata. Native source sizes are 35 by 31 end caps, 64 by 31 centre, 64 by 18 background and 256 by 15 fill. Previews tint the white fill red only for known health, never to imply a respawn duration.           |
| F      | `levelup/Backdrop.tga`, 512 by 128, full canvas; the numbered spine also uses `CountBadge.tga`, full 64 by 64                                    | These two textures are original addon artwork, not extracted Blizzard art. [Preparation and ownership](../../../third_party/LevelUp-ARTWORK.md). The backdrop is feathered black; the badge is a gold disk. No Level Up icon ornament or halo is imported into these designs.                                                                                                                                                                                                                                              |

Recipe A's one-unit baseline uses the existing waypoint RGBA
`(186/255, 148/255, 87/255, 85/255)` as the intended game styling. The static
compositions use a muted visible gold line against their study background. The
future addon would use the native WHITE8X8 baseline and game DEFAULT font.

The candidate D atlas definition is verified in
[DragonUI/utils/atlas.lua](https://github.com/NeticSoul/DragonUI/blob/5aefa049d22ba1a9e968b433d96eed7be86d6ac9/DragonUI/utils/atlas.lua)
under `QuestTracker-Header`: 560 by 70 and UVs
`11/1024, 571/1024, 247/512, 317/512`. Its owning
[objectivetracker.lua](https://github.com/NeticSoul/DragonUI/blob/5aefa049d22ba1a9e968b433d96eed7be86d6ac9/DragonUI/modules/objectivetracker.lua)
uses width-to-height ratio eight, alpha 0.9, and separate collapse/expand button
states. The preview follows that header ratio at alpha 0.8, with no collapse
button. Verified normal/pressed collapse cells are `(951, 59, 987, 97)` and
`(905, 121, 941, 159)`; expand cells are `(905, 161, 941, 199)` and
`(905, 201, 941, 239)`. They are not included in the chosen crop or used in the
proposal. The complete atlas is a source sheet, not an isolated widget.

## Retail expansion comparison

The wider search included the actual client source across three eras:

- [Dragonflight ObjectiveTracker.xml](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTracker.xml)
  uses `Objective-Header`, with separate OBJFX glow/sheens, and independent
  collapse-all textures. Its header region cannot be equated to candidate D.
- [The War Within 11.1.7 (61609) module header](https://github.com/Gethe/wow-ui-source/blob/d35405915c46f6a4ddc55d1974b8bf8c79468c99/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerModule.xml)
  uses `UI-QuestTracker-Secondary-Objective-Header`, a 260-by-26 module frame and
  separate secondary collapse/pressed/highlight textures.
- [Midnight 12.1.5 (70448) module header](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerModule.xml)
  uses the same named secondary header and state families. These source reads
  establish intended use; their backing atlas rectangles were not resolved in
  this study, so neither is claimed as a usable isolated crop in the previews.

The Gethe texture mirror's resolved default commit is still
`d23deaf8f44a7d280dc974a5c9d5321c013db59b`, labelled 9.2.7 (45114). It is not a
current Midnight texture extraction despite newer source branches. Existing
verified Dragonflight assets provide a better fit than guessing unresolved new
atlas rectangles. No retail atlas API, mask, blend mode, font or framework is
assumed to exist in the destination client.

## Repository search

Task-relevant trees were searched at the following resolved commits. All tree
responses were complete. NeticSoul and PentSec currently resolve to the same
commit and shared artwork was compared once. These were candidate/path searches;
only the selected files and their owning code/notices above were inspected as
artwork sources. Other repositories' pixels are not claimed as inspected or used.

| Repository                             | Resolved commit                            | Relevant result                                                                                                 |
| -------------------------------------- | ------------------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| NeticSoul/DragonUI; PentSec/DragonUI   | `5aefa049d22ba1a9e968b433d96eed7be86d6ac9` | Existing metal/editor/guardian families; older RetailUI quest-tracker atlas.                                    |
| Karl-HeinzSchneider/WoW-DragonflightUI | `f59cbc3f7010ef692fb983c7c3c848c4b70f56ce` | Shared metal/unit frame families; branch history includes newer UI backports, which does not date each texture. |
| Stormhand-dev/DragonflightUI-Reforged  | `2a8d2ffb3d9262f0d2af2071b9b47ef27f76f7f8` | Existing Reloaded-family theme; no stronger tracker-specific isolated match selected.                           |
| alchem1ster/DragonflightReloaded       | `49f20659cefcf621abd89fabb67f906b62ec7523` | Shared Reloaded theme; no separate pixel source selected.                                                       |
| DustinChecketts/Turtle-Dragonflight    | `b2c62e9095e1c859bff0209db09f4ff5b9884f5a` | Tooltip family; not selected for a new tracker skin.                                                            |
| mabu95/PhoUI                           | `304bff6816e6a1614b8945f3e0c0fc2bbf4c9497` | Tooltip code; no stronger gold/metal roster source selected.                                                    |
| ghbset/DragonUI_NewEra                 | `949261998d24acab02dd594a60f3ff0c2ee9932d` | Metal/diamond frame families; credited as a conduit by the selected DragonUI notices.                           |
| PentSec/DragonUI_AddOnSkins            | `18f390a3ea356cfc362ebb993adf593a6d357393` | Companion skin path search; no specific guardian component selected.                                            |

The supplied curated catalog and wider web search were both used. This is a
bounded component search, not a claim to have decoded every asset in every fork.

## Rights and delivery

Underlying WoW artwork is copyright Blizzard Entertainment. The selected
[DragonUI third-party notices](https://github.com/NeticSoul/DragonUI/blob/5aefa049d22ba1a9e968b433d96eed7be86d6ac9/DragonUI/THIRD_PARTY_NOTICES.md)
identify the source projects as conduits and exclude Blizzard artwork from the
[software MIT license](https://github.com/NeticSoul/DragonUI/blob/5aefa049d22ba1a9e968b433d96eed7be86d6ac9/DragonUI/LICENSE.txt).
Public hosting does not grant a separate texture license. Existing shipped
notices remain intact. No third-party software is copied into the new backend.
Candidate D is now used for the selected header; its source-specific notice and
intended game use are retained in the shipped tracker module.

The original candidate BLP is a research input kept separately from its preview
conversion, not part of the game payload. The full per-repository tree inventories
and unrelated research downloads are temporary and excluded from the deliverable.
