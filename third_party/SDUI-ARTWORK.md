# SDUI editor artwork

The `/sdui` editor uses World of Warcraft interface artwork, copyright Blizzard
Entertainment, Inc., obtained through the public projects listed below. Cropping,
repacking and format conversion do not change the ownership of that artwork. The
artwork is included for use inside the game; the source projects' MIT licenses
cover their own contributions rather than Blizzard's underlying artwork.

## Pinned sources

- [PentSec/DragonUI](https://github.com/PentSec/DragonUI/tree/623eca5893c9d475a7b77bd25808bdbe801d247c),
  commit `623eca5893c9d475a7b77bd25808bdbe801d247c`.
- [DragonUI artwork and third-party notices](https://github.com/PentSec/DragonUI/blob/623eca5893c9d475a7b77bd25808bdbe801d247c/DragonUI/THIRD_PARTY_NOTICES.md),
  including the distinction between Blizzard artwork and MIT code, and the
  attribution of retail frame chrome to DragonflightUI and DragonUI_NewEra.
- [DragonUI license](https://github.com/PentSec/DragonUI/blob/623eca5893c9d475a7b77bd25808bdbe801d247c/LICENSE):
  MIT, copyright 2026 NeticSoul and DragonUI contributors.
- [Karl-HeinzSchneider/WoW-DragonflightUI](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/tree/b8b35451d4621a8097e887385f72ec03e17765f1),
  commit `b8b35451d4621a8097e887385f72ec03e17765f1`, is the upstream DragonflightUI
  artwork conduit credited by DragonUI.
- [DragonflightUI license](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/b8b35451d4621a8097e887385f72ec03e17765f1/LICENSE):
  MIT, copyright 2022 Karl-HeinzSchneider.

The source coordinate definitions are
[`DragonUI/utils/forever_atlas_chrome.lua`](https://github.com/PentSec/DragonUI/blob/623eca5893c9d475a7b77bd25808bdbe801d247c/DragonUI/utils/forever_atlas_chrome.lua)
and
[`DragonUI/utils/forever_atlas_controls.lua`](https://github.com/PentSec/DragonUI/blob/623eca5893c9d475a7b77bd25808bdbe801d247c/DragonUI/utils/forever_atlas_controls.lua).
Their pixel rectangles are reproduced below. No source addon, library, font, Lua
atlas implementation or runtime dependency is included. The editor uses DEFAULT
fonts and direct texture coordinates through the vanilla frame API.

## Extracted texture pixels

All source paths in this section are relative to `DragonUI/Textures/ForeverUI/` at
the pinned DragonUI commit. Rectangles use `(left, top, right, bottom)`, with right
and bottom excluded. Destination coordinates refer to the top-left pixel of each
cell. Unused destination pixels are transparent.

### Input fields

Layout numeric fields and the Profile name field use a plain recessed treatment
matching the neutral metal panel. They retain the native EditBox, text, focus and
input handlers. No separate input artwork is bundled: one inset dark fill and
four one-unit neutral edges use the game's existing
`Interface\Buttons\WHITE8X8` texture. The top edge is subdued and the bottom
edge lighter to give a small inset relief without ornamental corners.

The fill uses RGB `(0.025, 0.028, 0.032)` at alpha `0.98`; edge colors are
`(0.17, 0.19, 0.22, 1)` above, `(0.42, 0.44, 0.46, 0.85)` below and
`(0.24, 0.27, 0.3, 0.95)` at the sides. These are addon-authored colors applied to
the native white texture, rather than a claim of pixel-identical retail input
artwork. Anchored edges follow field resizing without a script. Five regions
replace the old fill and eight diamond-border pieces; no animation or idle
updater is involved, and Performance Mode uses the same static treatment.

The obsolete prepared `editor/border.blp` has been removed from the runtime
manifest and media tree. `scripts/prepare_editor_art.py` prepares only the retail
selection artwork below. The guardian design preview helper now uses the retained
plain metal frame and does not depend on the old border or removed header crop.

### `media/tex/editor/choice.tga`

The 256-by-64 destination contains two 187-by-21 cells from `chrome-options.tga`:

| Cell         | Source rectangle       | Destination |
| ------------ | ---------------------- | ----------- |
| Selected row | `(398, 180, 585, 201)` | `(0, 0)`    |
| Hover row    | `(594, 180, 781, 201)` | `(0, 32)`   |

### `media/tex/editor/divider.tga`

The 1024-by-1 destination contains the 630-by-1 `options_horizontaldivider` cell
from `chrome-options.tga`: rectangle `(288, 220, 918, 221)`, placed at `(0, 0)`.

### `media/tex/editor/checkbox.tga`

The 64-by-32 destination contains two 30-by-29 cells from the 128-by-256
`controls-basic.tga` source:

| Cell      | Source rectangle  | Destination |
| --------- | ----------------- | ----------- |
| Checkbox  | `(64, 4, 94, 33)` | `(0, 0)`    |
| Checkmark | `(4, 52, 34, 81)` | `(32, 0)`   |

## Retail red buttons

`media/tex/editor/button.tga` retains the 512-by-512 preparation canvas for
`button.blp`. The source is Blizzard's
[`Buttons/128GoldRedButton.PNG`](https://github.com/Gethe/wow-ui-textures/blob/e80e3278cc833c89e1f3fc79557b68315d750935/Buttons/128GoldRedButton.PNG),
512 by 1024, at Gethe texture commit
`e80e3278cc833c89e1f3fc79557b68315d750935` (**10.0.0 build 45454**).
This is shared retail artwork present in Dragonflight, rather than an image
authored exclusively for that expansion. The gold variant retains SDUI's gold
accents while replacing the former diamond-frame action buttons.

The atlas member names and full member bounds are recorded in
[TextureAtlasViewer's `Data.lua`](https://github.com/LanceDH/TextureAtlasViewer/blob/e58691c23218b25a368f20c8cfebd8f482ed8ce3/Data.lua).
That export identifies **build 37864**, not Dragonflight. Its bounds were used
as discovery leads and the actual Dragonflight crops were inspected. The sheets
are not byte/pixel-identical between those eras; the retained pixels and hashes
come only from the Dragonflight pin above.

The source names its 292-pixel cell `128-goldredbutton-left` and its 114-pixel
cell `128-goldredbutton-right`. Their visible outer edges face right and left,
respectively. This assembly uses the full 114-pixel cell as the displayed left
cap and the outside 114 pixels of the long cell as the displayed right cap.
Both keep their full 128-pixel height. The center uses the original 64-pixel
member. Rectangles below use exclusive right/bottom bounds.

| State    | Displayed left cap  | Center           | Displayed right cap | Destination row |
| -------- | ------------------- | ---------------- | ------------------- | --------------- |
| Normal   | `(295,521,409,649)` | `(0,1,64,129)`   | `(179,521,293,649)` | `0`             |
| Pressed  | `(295,781,409,909)` | `(0,261,64,389)` | `(179,781,293,909)` | `128`           |
| Disabled | `(295,651,409,779)` | `(0,131,64,259)` | `(179,651,293,779)` | `256`           |

These cells start at destination X positions `0`, `128` and `208`. The full
441-by-128 highlight `(1,391,442,519)` occupies `(0,384)` and uses native ADD
highlight blending, below the caption. Cap width is `114/128` of button height;
narrow buttons crop only the inner ends so the middle keeps at least 20% of
the button width. No pixel resampling, recoloring or mirroring occurs during
preparation. `scripts/prepare_editor_buttons.py` creates the retained TGA and
lossless BLP using the shared client texture encoder, compares all decoded
pixels, and writes [EditorButtons-PREPARATION.json](EditorButtons-PREPARATION.json).

Source research also inspected DragonUI's
[red button helper](https://github.com/NeticSoul/DragonUI/blob/6cfcd75a2e5762637322fd495cd4302b203b77df/DragonUI/utils/redbutton.lua),
[three-slice controls](https://github.com/NeticSoul/DragonUI/blob/6cfcd75a2e5762637322fd495cd4302b203b77df/DragonUI/utils/forever_ui_chrome.lua)
and the accompanying
[notices](https://github.com/NeticSoul/DragonUI/blob/6cfcd75a2e5762637322fd495cd4302b203b77df/DragonUI/THIRD_PARTY_NOTICES.md).
DragonflightUI's pinned texture listing also includes `Textures/UI/redbutton2x.blp`;
DragonUI's `atlas.lua` identifies that family as close/expand controls rather
than the three-slice text button selected here. No addon framework or source code is imported. These
Blizzard pixels retain the artwork scope described at the top of this file;
the ports' MIT licenses do not relicense the underlying artwork.

A static assembly is retained at `docs/designs/retail-buttons/preview.png`.
It demonstrates the real cropped artwork and approximate caption/hover
composition, using a system preview font. It is not an in-game screenshot or a
claim of native rendering verification.

## Dragonflight plain settings frame

The large panel and the two moving-mode windows now reuse the existing
`media/tex/character/Chrome.blp` pixels and the geometry of Blizzard’s
`ButtonFrameTemplateNoPortrait`, which is the layout used by the real
[Dragonflight SettingsFrameTemplate](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_Settings_Shared/Mainline/Blizzard_SettingsPanelTemplates.xml).
The matching eight-piece definition is in
[NineSliceLayouts.lua](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_SharedXML/Mainline/NineSliceLayouts.lua).
The code uses direct BLP paths/UVs, not retail NineSlice or atlas APIs.

The Chrome sheet is already credited in [Character-ARTWORK.md](Character-ARTWORK.md):
NeticSoul/DragonUI commit `6d9cc95eedd1de78fab3b965683df13421e21604`, with
DragonflightUI/DragonUI_NewEra as the art conduits. It retains its source pixels,
original corner sizes and ordinary alpha blending. The settings layout has
75-unit upper corners, 32-unit lower corners, 75-unit side/top spans and a
32-unit bottom span, at the retail `(-8,16)/(4,16)/(-8,-3)/(4,-3)` offsets.
No duplicate chrome image is added. Category rows use the existing choice
artwork and caption without a second framed button. The unused old header crop
and its runtime BLP were removed.

## Retail Edit Mode selections

`media/tex/editor/selection.tga` is the retained preparation input for the new
`selection.blp`. Its source is
[Gethe/wow-ui-textures](https://github.com/Gethe/wow-ui-textures/tree/e80e3278cc833c89e1f3fc79557b68315d750935),
commit `e80e3278cc833c89e1f3fc79557b68315d750935`, whose commit identifies
**10.0.0 (45454)**. The source PNGs are converted Blizzard client artwork:

| Source under `Editmode/`            | Canvas   | Used regions                                                                                                                                                               |
| ----------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `EditModeUI.PNG`                    | 32 × 256 | Highlight corner `(1,73,17,89)`, selected corner `(1,91,17,107)`; highlight top/bottom `(0,19,16,35)` / `(0,1,16,17)`; selected top/bottom `(0,55,16,71)` / `(0,37,16,53)` |
| `EditModeUIVertical.PNG`            | 128 × 16 | Highlight left/right `(1,0,17,16)` / `(19,0,35,16)`; selected left/right `(37,0,53,16)` / `(55,0,71,16)`                                                                   |
| `EditModeUIHighlightBackground.PNG` | 16 × 16  | Complete blue center                                                                                                                                                       |
| `EditModeUISelectedBackground.PNG`  | 16 × 16  | Complete gold center                                                                                                                                                       |

The atlas-member coordinates and corner rotations are also explicitly documented
by [DragonflightUI’s Editmode mixin](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/f59cbc3f7010ef692fb983c7c3c848c4b70f56ce/Mixin/Editmode.mixin.lua).
The matching retail texture-kit names and selection lifetime are in
[Dragonflight 10.2.7 EditModeSystemTemplates](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_EditMode/Mainline/EditModeSystemTemplates.xml).
The selected/current DragonUI reference is commit
`6cfcd75a2e5762637322fd495cd4302b203b77df`; its
[third-party notices](https://github.com/NeticSoul/DragonUI/blob/6cfcd75a2e5762637322fd495cd4302b203b77df/DragonUI/THIRD_PARTY_NOTICES.md)
trace the same Editmode artwork to DragonflightUI. DragonUI’s own green tint is
not applied: SDUI uses the original blue and gold states.

`scripts/prepare_editor_art.py` makes a 256-by-64 sheet. Each state occupies one
16-unit-high row, at y=0 or 32. Columns of 16 pixels hold top-left, top-right,
bottom-left, bottom-right, top, bottom, left, right and center. Corners use exact
90-degree pixel rotations, replacing an unsupported runtime rotation dependency.
There is no tint, resampling or color quantization. The retained
[preparation receipt](Editor-PREPARATION.json) records each source hash, final
RGBA hash and encoded BLP hash. Runtime drawing uses nine regions, fixed 16-unit
corners and stretched edges/center; successful state changes update UVs only.
The exact-palette writer retains separate alpha or falls back to Raw3.

## Source scope and verification

Blizzard owns the underlying game artwork; the source mirrors/addons do not
relicense it. It is bundled for display inside the game under the same project
artwork scope as the existing character/editor assets. The MIT software notices
for NeticSoul/DragonUI contributors and Karl-HeinzSchneider remain in
`core/editor.lua`. No source-addon framework, font, global hook implementation,
retail C_EditMode API or saved gameplay data is imported.

Source research compared the current DragonUI and DragonflightUI editor code
with Blizzard’s 10.2.7 settings/Edit Mode source and the build-pinned texture
mirror. AzeriteUI’s custom options family was considered through the curated
catalog/tree; it was not selected for the native Dragonflight settings style.
The original DragonUI/Reloaded editor art was reviewed alongside the already
bundled Chrome sheet. No complete repository/archive/source cache was created.

A static assembly is retained at `docs/designs/retail-editor/preview.png`. It
illustrates the inspected frame/selection pixels with approximate controls and
fonts. It is not a screenshot or live visual-parity evidence. Format preparation
and pinned Lua/text formatting were performed locally; no local tests,
standalone addon validation, game launch or addon execution was performed.
