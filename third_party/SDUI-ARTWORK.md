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

### `media/tex/editor/border.tga`

The 1024-by-128 destination contains only the eight diamond-metal border cells
used by the editor, from the 512-by-512 `chrome-dialog.tga` source. The center is
not included. Corners retain fixed dimensions; only straight edges stretch.

| Cell | Source rectangle | Destination |
| --- | --- | --- |
| Top left | `(4, 276, 132, 404)` | `(0, 0)` |
| Top right | `(140, 276, 268, 404)` | `(128, 0)` |
| Bottom left | `(140, 140, 268, 268)` | `(256, 0)` |
| Bottom right | `(276, 140, 404, 268)` | `(384, 0)` |
| Left edge | `(4, 4, 132, 132)` | `(512, 0)` |
| Right edge | `(140, 4, 268, 132)` | `(640, 0)` |
| Top edge | `(4, 140, 132, 268)` | `(768, 0)` |
| Bottom edge | `(276, 4, 404, 132)` | `(896, 0)` |

### `media/tex/editor/header.tga`

The 256-by-32 destination contains the 199-by-32
`options_categoryheader_1` cell from the 1024-by-256 `chrome-options.tga` source:
rectangle `(572, 4, 771, 36)`, placed at `(0, 0)`. It is drawn with restrained
opacity behind the editor title.

### `media/tex/editor/choice.tga`

The 256-by-64 destination contains two 187-by-21 cells from `chrome-options.tga`:

| Cell | Source rectangle | Destination |
| --- | --- | --- |
| Selected row | `(398, 180, 585, 201)` | `(0, 0)` |
| Hover row | `(594, 180, 781, 201)` | `(0, 32)` |

### `media/tex/editor/divider.tga`

The 1024-by-1 destination contains the 630-by-1 `options_horizontaldivider` cell
from `chrome-options.tga`: rectangle `(288, 220, 918, 221)`, placed at `(0, 0)`.

### `media/tex/editor/checkbox.tga`

The 64-by-32 destination contains two 30-by-29 cells from the 128-by-256
`controls-basic.tga` source:

| Cell | Source rectangle | Destination |
| --- | --- | --- |
| Checkbox | `(64, 4, 94, 33)` | `(0, 0)` |
| Checkmark | `(4, 52, 34, 81)` | `(32, 0)` |

## Format and shipped attribution

The source files are 32-bit RLE TGA images. Their RGBA pixels were decoded,
cropped without resizing or recoloring and repacked into the dimensions listed
above. The destination files are uncompressed, true-color TGA images: image type
2, 32 bits per pixel, BGRA byte order, top-left origin and eight alpha bits. The
files use power-of-two dimensions and do not require retail atlas support or a
BLP2 decoder at runtime. Draw opacity and the solid panel colors are set in Lua.

`core/editor.lua` carries the complete MIT notices for NeticSoul and DragonUI
contributors and Karl-HeinzSchneider, plus the Blizzard artwork attribution and
exact source commit, so the required text remains with the shipped implementation
when standalone attribution Markdown is omitted from release ZIPs.

Source-art inspection and pixel-format conversion do not establish compatibility
with the packaged game. No addon execution or in-game validation was performed.
