# Character-window artwork

The window uses World of Warcraft interface artwork, copyright Blizzard
Entertainment, Inc. These are existing client pixels, with cropping, repacking
and format conversion only. The sources' MIT licenses cover software
contributions and do not relicense Blizzard artwork. Their notices describe
in-game addon use; public availability is not a separate grant from Blizzard.

## Pinned sources

- [NeticSoul/DragonUI](https://github.com/NeticSoul/DragonUI/tree/6d9cc95eedd1de78fab3b965683df13421e21604),
  commit `6d9cc95eedd1de78fab3b965683df13421e21604`.
  Source paths below are relative to `DragonUI/Textures/`.
- Its [third-party notices](https://github.com/NeticSoul/DragonUI/blob/6d9cc95eedd1de78fab3b965683df13421e21604/DragonUI/THIRD_PARTY_NOTICES.md)
  credit DragonUI_NewEra for the character-panel artwork and DragonflightUI /
  DragonUI_NewEra for retail frame artwork. This records the conduit rather
  than assigning authorship of Blizzard artwork to an addon author.
- Its [MIT license](https://github.com/NeticSoul/DragonUI/blob/6d9cc95eedd1de78fab3b965683df13421e21604/DragonUI/LICENSE.txt),
  copyright 2026 NeticSoul and DragonUI contributors, and the retained
  [DragonflightUI MIT notice](https://github.com/NeticSoul/DragonUI/blob/6d9cc95eedd1de78fab3b965683df13421e21604/DragonUI/LICENSES/MIT-DragonflightUI.txt),
  copyright 2022 Karl-HeinzSchneider.
- [Gethe/wow-ui-textures](https://github.com/Gethe/wow-ui-textures/tree/e80e3278cc833c89e1f3fc79557b68315d750935),
  commit `e80e3278cc833c89e1f3fc79557b68315d750935`, whose commit identifies
  Dragonflight PTR `10.0.0 (45454)`. This is a pinned Dragonflight-era build,
  not an assumption about the mirror's current branch or later expansions.
- [Blizzard 10.2.7 CharacterFrame.xml](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/CharacterFrame.xml)
  defines the slot/stat/trim source regions. Its
  [NineSliceLayouts.lua](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_SharedXML/Mainline/NineSliceLayouts.lua)
  defines the portrait-frame assembly and offsets.

The additional coordinate/assembly references are DragonUI's
[`utils/atlas.lua`](https://github.com/NeticSoul/DragonUI/blob/6d9cc95eedd1de78fab3b965683df13421e21604/DragonUI/utils/atlas.lua),
[`characterpanel/chrome.lua`](https://github.com/NeticSoul/DragonUI/blob/6d9cc95eedd1de78fab3b965683df13421e21604/DragonUI/modules/characterpanel/chrome.lua),
[`slots.lua`](https://github.com/NeticSoul/DragonUI/blob/6d9cc95eedd1de78fab3b965683df13421e21604/DragonUI/modules/characterpanel/slots.lua)
and
[`tabs.lua`](https://github.com/NeticSoul/DragonUI/blob/6d9cc95eedd1de78fab3b965683df13421e21604/DragonUI/modules/characterpanel/tabs.lua).
The existing complete-window visual reference is
[DragonflightUI's older-client screenshot](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/f59cbc3f7010ef692fb983c7c3c848c4b70f56ce/Screenshots/v0.11/CharacterFrame.png).
That screenshot is not a runtime capture from this addon or game.

## Prepared files

`scripts/prepare_character_art.py` downloads the pinned source files and writes
the runtime artwork. It uses Pillow for image decoding/conversion and a direct
BGRA decoder for uncompressed BLP2 encoding 3. It never runs addon code.
Coordinates below are `(left, top, right, bottom)`, right/bottom excluded.
All unoccupied destination pixels are transparent.

### `media/tex/character/Chrome.tga`

The 1024-by-256 sheet contains the eight pieces of the plain metal frame.
Sources are `UI/uiframemetal2x.blp` (512 by 512),
`UI/uiframemetalhorizontal2x.blp` (64 by 256) and
`UI/uiframemetalvertical2x.blp` (512 by 32).

| Piece        | Source     | Source rectangle       | Destination  | Draw size     |
| ------------ | ---------- | ---------------------- | ------------ | ------------- |
| Top left     | Metal      | `(1, 1, 151, 151)`     | `(0, 0)`     | 75 by 75      |
| Top right    | Metal      | `(153, 1, 303, 151)`   | `(256, 0)`   | 75 by 75      |
| Bottom left  | Metal      | `(153, 153, 217, 217)` | `(512, 0)`   | 32 by 32      |
| Bottom right | Metal      | `(219, 153, 283, 217)` | `(640, 0)`   | 32 by 32      |
| Top          | Horizontal | `(0, 1, 64, 151)`      | `(768, 0)`   | Stretch by 75 |
| Bottom       | Horizontal | `(0, 153, 32, 217)`    | `(896, 0)`   | Stretch by 32 |
| Left         | Vertical   | `(1, 0, 151, 32)`      | `(0, 192)`   | 75 by stretch |
| Right        | Vertical   | `(153, 0, 303, 32)`    | `(256, 192)` | 75 by stretch |

Corners keep their proportions; straight edges stretch between them. Draw
order is OVERLAY, with ordinary alpha blending. The plain top-left region is
`UI-Frame-Metal-CornerTopLeft` from the pinned atlas table. It replaces the
earlier portrait cutout and ring while the native portrait stays hidden.

### `media/tex/character/Parts.tga`

The 256-by-256 sheet places these sources without resizing:

| Source                                               | Canvas     | Destination |
| ---------------------------------------------------- | ---------- | ----------- |
| Gethe `CHARACTERFRAME/Char-Paperdoll-Parts.PNG`      | 256 by 128 | `(0, 0)`    |
| Gethe `CHARACTERFRAME/Char-Paperdoll-Horizontal.PNG` | 32 by 16   | `(0, 128)`  |
| Gethe `CHARACTERFRAME/Char-Paperdoll-Vertical.PNG`   | 16 by 32   | `(64, 128)` |
| DragonUI `CharacterPanel/charstatmiddle.blp`         | 256 by 8   | `(0, 192)`  |

The parts source regions used at their original locations are left equipment
surround `(53, 76, 102, 120)`, right surround `(1, 76, 51, 120)`, bottom weapon
surround `(172, 1, 214, 54)`, stat-card top `(1, 65, 170, 74)` and stat-card
bottom `(1, 1, 170, 47)`. Card middles use the original middle strip's
`(1, 0, 170, 8)` region, now at `(1, 192, 170, 200)`.

Model/sidebar trim uses the four native seven-pixel corners and the five-pixel
edge strips defined in the pinned CharacterFrame XML. Top/bottom strips occupy
`(0, 136, 32, 141)` / `(0, 129, 32, 134)` in the destination; left/right strips
occupy `(65, 128, 70, 160)` / `(72, 128, 77, 160)`. Corners stay fixed while
straight trim and card middles stretch. Equipment artwork is BACKGROUND behind
native item icons; trim is OVERLAY. No item content or tooltip pixels are baked
into these textures.

### `media/tex/character/QualityBorder.tga`

This is the complete 64-by-64 `COMMON/WhiteIconFrame.PNG` from the pinned
Dragonflight 10.0.0 build 45454 texture mirror, converted without cropping,
recoloring or resizing. The transparent center leaves native item icons visible.
The character module draws it over each native equipment button at that button's
size: 37 by 37, or 27 by 27 for ammo, with ordinary alpha blending. Its vertex
color comes from the native item-quality palette, for uncommon or higher items.
Poor/common, empty and unavailable-quality slots have no colored overlay.

For the requested stronger quality outline, the original full-opacity layer is
joined by two copies of this same unmodified texture: an aligned additive pass
at alpha 0.4 and an additive outer rim at alpha 0.3. The outer copy extends one
local UI unit on every side (39 by 39 for equipment, 29 by 29 for ammo). All
copies use the exact native quality RGB and the full original UV rectangle;
transparent centres leave item artwork clear. They remain ordinary button-owned
OVERLAY textures, preserving native child cooldowns and input handling. No new
asset or source crop is introduced, and all layers share native refresh/cleanup.

Blizzard's pinned 10.2.7
[`ItemButtonTemplate.xml`](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_ItemButton/Mainline/ItemButtonTemplate.xml)
defines the centered 37-by-37 `IconBorder` using this texture. Its
[`ItemButtonTemplate.lua`](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua)
applies quality colors through vertex tinting. These are drawing references;
no retail item-button API or Lua module is imported. DragonUI's pinned
[`itemquality.lua`](https://github.com/NeticSoul/DragonUI/blob/6d9cc95eedd1de78fab3b965683df13421e21604/DragonUI/modules/itemquality.lua)
was also inspected: it uses the native equipped-item quality and defaults to
uncommon or higher, with a larger additive action-button glow. This integration
uses Blizzard's item frame with the existing metal surrounds and the additional
brightness/outer-rim passes described above.

### `media/tex/character/Background.tga`

The 512-by-512 canvas contains `character-panel-background`, the 450-by-420
region `(1, 1, 451, 421)` of DragonUI's 1024-by-512
`CharacterPanel/characterpanelbackground.blp`, placed at `(0, 0)`. The module
draws only that region, with UVs `(0, 450/512, 0, 420/512)`.

### `media/tex/character/Tabs.tga`

This is the complete 64-by-256 `UI/uiframetabs.blp`, converted without changing
its pixels. The native tab's existing state textures use these rectangles:

| State/piece     | Rectangle           | Draw size     |
| --------------- | ------------------- | ------------- |
| Inactive left   | `(1, 209, 36, 245)` | 35 by 36      |
| Inactive right  | `(1, 171, 38, 207)` | 37 by 36      |
| Inactive middle | `(0, 45, 1, 81)`    | Stretch by 36 |
| Selected left   | `(1, 127, 36, 169)` | 35 by 42      |
| Selected right  | `(1, 83, 38, 125)`  | 37 by 42      |
| Selected middle | `(0, 1, 1, 43)`     | Stretch by 42 |

Native selected/disabled state handling controls which set is shown. The old
rectangular highlight is transparent rather than covering the shaped tab.

### `media/tex/character/Close.tga`

The 128-by-128 sheet uses `UI/redbutton2x.blp` (256 by 128). Normal
`(39, 1, 75, 39)` goes to `(0, 0)`; pushed `(39, 81, 75, 119)` to `(64, 0)`;
disabled `(39, 41, 75, 79)` to `(0, 64)`; highlight `(115, 1, 151, 39)` to
`(64, 64)`. Each cell is 36 by 38; the native close button draws at 24 by 24.
Only its highlight uses ADD blending. Its original click handler remains.

## Native artwork and distribution

The model scenery uses the client's own `DressUpTexturePath()` and its four
native textures, retaining the documented client race fallbacks. Rotation
buttons and scrollbar controls use native Blizzard textures. These files are
not bundled. The skin adds no font, mask, source-addon framework or client patch.

Prepared files are uncompressed 32-bit RGBA TGA canvases, stored as BGRA, with
eight alpha bits and power-of-two dimensions. The complete applicable MIT
notice, source pins and Blizzard ownership statement are retained in shipped
`modules/ui/character.lua`. Standalone notices and preparation tooling stay on
GitHub and outside the runtime payload. Pixel inspection does not establish
packaged-game rendering; no addon or game execution was performed.
