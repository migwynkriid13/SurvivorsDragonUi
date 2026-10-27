# Dragonflight minimap glyph

The transparent launcher uses the gold Dragon Glyph image distributed by
[keyboardturner/HandyNotes_DragonGlyphs](https://github.com/keyboardturner/HandyNotes_DragonGlyphs/tree/fba3a80bfb5b42c7ac302f18bd72f60517ca913d),
commit `fba3a80bfb5b42c7ac302f18bd72f60517ca913d`, file
[`icon.blp`](https://github.com/keyboardturner/HandyNotes_DragonGlyphs/blob/fba3a80bfb5b42c7ac302f18bd72f60517ca913d/icon.blp).
The repository identifies this as its Dragonflight Dragon Glyph map icon; its
file history leads to `21724d4d9f25ed5b03cff6279232d637306edb9b` in November 2022.

The underlying World of Warcraft glyph artwork belongs to Blizzard Entertainment.
The source repository supplies no separate license for this image; no general
artwork or code license is inferred from public access. Retain both Blizzard
artwork ownership and Keyboardturn's distribution credit. No HandyNotes code,
framework or dependency is included.

## Prepared files and display

The inspected source is 128 by 128 pixels, with alpha and a black circular
backing. Preserve its complete decoded canvas without cropping, resampling,
recoloring or painted replacement pixels. The launcher uses **ADD** blending:
black contributes zero color, leaving the gold glyph visible over the map/world
without a circular backing. There is no additional border, highlight texture,
mask or background. A checkerboard inspection of ordinary and additive display
was used to distinguish actual source alpha from this blending behavior; it
does not establish the packaged client's rendered appearance.

| File                                | Role                                                                           |
| ----------------------------------- | ------------------------------------------------------------------------------ |
| `media/tex/minimap/DragonGlyph.tga` | Full-resolution, uncompressed preparation input; outside the runtime manifest. |
| `media/tex/minimap/DragonGlyph.blp` | Prepared lossless BLP2 Raw3, including the required 256-entry palette block.   |

Original file SHA-256:
`e4326ee2a9830009a77108cb8dc54049749244f4d21f517bb7e9a8f2268635b8`.
Decoded top-down BGRA SHA-256:
`6f4ab71a45749a6dc9076e003aa02d070bb194bd3a14b24be3bcf277a9bf769e`.
Prepared runtime SHA-256:
`b8f82f68e17bf1f09ea27e178ccd65fdfe5ed1d7f295ca03c3b0a1ef298bd43b`.

Preparation reads the source with Pillow, writes its decoded RGBA pixels as an
uncompressed TGA and calls `scripts/prepare_client_textures.py`'s `blp_from_tga`.
The normal client-texture preparation step can regenerate the runtime BLP from
this TGA before packaging. No runtime binary reading or modern atlas API is used.

The curated DragonflightUI/DragonUI/Reloaded artwork and the public Gethe client
texture mirror were also inspected during selection. Reforged's round dragon
logo and the native square dragon-head item icon were not selected. The glyph's
owning source uses it as a map marker; SDUI supplies its independent button/input
and square-edge placement. See [MINIMAP-BUTTONS.md](../docs/MINIMAP-BUTTONS.md).
