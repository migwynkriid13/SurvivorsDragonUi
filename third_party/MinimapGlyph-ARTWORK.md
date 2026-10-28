# Dragonflight minimap glyph

The launcher uses the gold Dragon Glyph image distributed by
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
without its circular backing. The independently selected square background is
described below; no highlight texture or mask is added.
A checkerboard inspection of ordinary and additive display
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

## Selected square background — 2026-10-28

The user selected **05 Small square button** from the local comparison. Its
source is Blizzard's
[`BUTTONS/UI-SquareButton-Up.PNG`](https://github.com/Gethe/wow-ui-textures/blob/e80e3278cc833c89e1f3fc79557b68315d750935/BUTTONS/UI-SquareButton-Up.PNG)
from the public Gethe client texture mirror, commit
`e80e3278cc833c89e1f3fc79557b68315d750935`, labelled **10.0.0 (45454)**. This is
shared native button artwork in an early Dragonflight export, not a claim that
the image originated in that expansion. The mirror documents BLP-to-PNG
conversion. The underlying artwork is © Blizzard Entertainment; public access
does not grant a separate image license.

The inspected 32 by 32 image is retained without cropping or resampling in
`media/tex/minimap/LauncherBackground.tga`, an uncompressed preparation input.
`LauncherBackground.blp` is its lossless BLP2 Raw3 runtime copy, prepared with
the same `blp_from_tga` helper as the glyph. The full preparation canvas and alpha
are unchanged. Runtime UVs select the complete nontransparent rectangle
`(0,3)-(29,29)`, using `(0,29/32,3/32,29/32)`, and center it at 37 by 33 units
behind the existing 34-square glyph, matching proposal 05. It uses ordinary
alpha blending on BACKGROUND; the glyph retains ADD on ARTWORK. No hover,
pressed or disabled background image is imported.

Blizzard's
[`SquareIconButtonTemplate`](https://github.com/Gethe/wow-ui-source/blob/15881d522c44cd106d3d8660106ec9f9d2f44167/Interface/AddOns/Blizzard_SharedXML/Shared/Button/IconButtonTemplate.xml)
uses `UI-SquareButton-Up` as the normal state, with separate Down, Disabled and
additive mouse-highlight images. That source commit is labelled
**12.1.5 (70575)**; continued use does not make the shared image Midnight-original.

Source PNG SHA-256:
`0b0c62a7efa80ca7160f6f82a12e0e578950004739900ee8af2e920a9f8357fd`.
Decoded top-down BGRA SHA-256:
`e238fef4f0dfdbc6ff42a41f0e4adf15eb0fc3aad54342e4461dd3fea66997e0`.
Prepared TGA SHA-256:
`20543d7a4b0414404518e1efe562725c10b2a65b87fff57f2ee021847e37a82c`.
Prepared runtime SHA-256:
`3e78a7d5d3e6c239b3ebd1ef48e334f7ce81dc186e59ab64242ca6df5ee71004`.

The curated DragonflightUI/DragonUI/Reloaded artwork and the public Gethe client
texture mirror were also inspected during selection. Reforged's round dragon
logo and the native square dragon-head item icon were not selected. The glyph's
owning source uses it as a map marker; SDUI supplies its independent button/input
and square-edge placement. See [MINIMAP-BUTTONS.md](../docs/MINIMAP-BUTTONS.md).
