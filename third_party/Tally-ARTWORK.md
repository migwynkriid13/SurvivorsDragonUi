# Kills, Gold & Caches artwork

The ten shipped frames use the sources below. Pixel rectangles are
`(left, top, right, bottom)`, with right and bottom excluded. The prepared
1024×128 RGBA TGAs contain 600×128 pixels at double resolution, with an open
top edge shared with the action bar in attached mode. Each style also has a
closed detached variant on the same canvas. Crops are fitted to the frame and toned
toward gray; icons, counter text and fonts are not part of the artwork.

## Selected sources and crops

RothUI source files are pinned to
[zorker/rothui, 9a9ce9744ce404991fc06066291614fe1765ee20](https://github.com/zorker/rothui/tree/9a9ce9744ce404991fc06066291614fe1765ee20).

| Shipped frame       | Source and crop                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Continuous silver   | Existing `HDActionBar.tga`: side `(0,35,7,92)` and lower edge `(16,105,512,112)`, mirrored right. Source credits: [XP-ARTWORK.md](XP-ARTWORK.md).                                                                                                                                                                                                                                                                                                              |
| Soft graphite       | Original rounded lower contour and shading made for this addon.                                                                                                                                                                                                                                                                                                                                                                                                |
| Roth scrollwork     | [castbar.tga](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/wow6.0/oUF_Diablo/media/castbar.tga), `(0,58,512,107)`.                                                                                                                                                                                                                                                                                                           |
| Roth shrine         | [targettarget.tga](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/wow6.0/oUF_Diablo/media/targettarget.tga): caps `(0,58,43,107)` and `(213,58,256,107)`; center strips `(43,58,213,80)` and `(43,99,213,107)`, omitting the internal divider.                                                                                                                                                                                 |
| Gothic cornerwork   | [d3_altpower_border.tga](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/wow6.0/oUF_Diablo/media/d3_altpower_border.tga), `(81,28,430,61)`.                                                                                                                                                                                                                                                                                     |
| Iron sarcophagus    | [demonic_fury_border.tga](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/wow6.0/oUF_Diablo/media/demonic_fury_border.tga), `(0,16,256,32)`; side samples `(4,16,12,24)` and `(244,16,252,24)`. Upper backing is inset 3.515625 units through its first 18 units.                                                                                                                                                               |
| Knotted iron        | [d3_nameplate_border.tga](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/wow4.0/rTextures/d3_nameplate_border.tga), `(3,22,253,51)`.                                                                                                                                                                                                                                                                                           |
| ARPG carved cornice | [kyau/ARPG TopBar.tga](https://github.com/kyau/ARPG/blob/9c53e246ff181d7259e3e355836044c5f8ade5be/Interface/AddOns/ARPG/Media/Textures/TopBar.tga), `(345,24,679,63)`, fitted to 300×40 units with saturation 0.45 and brightness 1.4.                                                                                                                                                                                                                         |
| Gothic leaf corners | [Diablo_III_UI UIButton_300x51_Normal.tga](https://github.com/RickyElune/Diablo_III_UI/blob/10aa68fef2bfa11bba0eab42baa952b700eb1be5/media/UIButton_300x51_Normal.tga), `(88,64,424,98)`.                                                                                                                                                                                                                                                                      |
| Demon reliquary     | [Diablo_III_UI target.tga](https://github.com/RickyElune/Diablo_III_UI/blob/10aa68fef2bfa11bba0eab42baa952b700eb1be5/media/target.tga): left cap `(58,60,106,106)`, mirrored for the right; rail `(106,88,400,106)` at `(29,23)`, 242×14 units. [target_elite.tga](https://github.com/RickyElune/Diablo_III_UI/blob/10aa68fef2bfa11bba0eab42baa952b700eb1be5/media/target_elite.tga) footer `(208,100,304,128)` is centered at x150, y26, sized 48.222222×14 units. |

Knotted iron uses its native open upper walls and alpha, fitted to 300×37
units with 30-source-pixel end caps. It has no projected top backing.
ARPG follows the source's curved shoulder with a mirrored alpha contour
`(0,10), (3,9), (8,8), (13,6), (17,3), (20,0)` within the listed crop.
This removes the upper side slabs while retaining the lower carved curls;
its interior and remaining source alpha are preserved.

The other Gothic interiors reuse RothUI's
[combo_back.tga](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/wow6.0/oUF_Diablo/media/combo_back.tga),
`(0,32,64,44)`, clipped inside each frame's silhouette. Silver and graphite
leave dividers to the live renderer.

## Detached surrounds

Most `_detached.tga` variants reflect each prepared frame's structural
lower half above its counter center, retaining the source alpha and the
original lower half. The matching upper corners and rail close the frame
without a shared action-bar edge.

Iron sarcophagus keeps its complete attached artwork without resizing it,
shifted down six units. Its top bevel reflects the attached pixel rectangle
`(7,60,593,72)` into a 600×12 strip. The seven-pixel side inset matches the
attached walls rather than the wider lower flare. This retains the long walls,
lower cornerwork and interior instead of replacing them with a differently
scaled full source frame.

Demon reliquary restores its complete native left wing from `target.tga`
`(58,40,106,106)`, fitted to 31×52 units, and mirrors it for the right wing.
The existing lower rail moves down 16 units; its vertical reflection closes
the top at `(29,0)`, 242×14 units. Both modes reflect the left structural
artwork and backing horizontally to remove the darker right-side join.
The unchanged `target_elite.tga` pendant is composited afterward at y26 when
attached and y42 when detached, keeping it only on the lower edge.

Per-mode texture, full extent and counter-center metadata are generated
together in `core/tally.lua`. The existing palettes and notices apply to
both variants. No counter icons or text are baked into either texture.

The reproducible preparation source is
[`prepare_tally_variants.py`](../scripts/prepare_tally_variants.py). Its five
original inputs, immutable URLs and SHA-256 fingerprints are recorded in
[`tally-sources.json`](tally-sources.json). See
[TALLY-ATTACHMENT.md](../docs/TALLY-ATTACHMENT.md) for the preparation command.

## Notices

RothUI's [MIT license](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/LICENSE.md)
credits Erik Raetz, 2011–2018. Diablo_III_UI's
[MIT license](https://github.com/RickyElune/Diablo_III_UI/blob/10aa68fef2bfa11bba0eab42baa952b700eb1be5/LICENSE.txt)
credits Lars Norberg, 2017; its original UI is credited to galaxy119. ARPG's
[LGPL-3.0 license](https://github.com/kyau/ARPG/blob/9c53e246ff181d7259e3e355836044c5f8ade5be/LICENSE)
applies to its prepared cornice where applicable. The shipped
[core/tally.lua](../core/tally.lua) retains the full MIT and LGPL notices.
Original Blizzard/Diablo artwork remains its owners' property; repository
software licenses do not transfer ownership of inherited game artwork.

`AffordableGlow.tga` (64×32 ellipse), `AffordableRays.tga` (128×128 radial
light) and `AffordableSparkle.tga` (32×32 glint) are original white RGBA masks
made for this addon. Their soft alpha edges contain no imported artwork.
