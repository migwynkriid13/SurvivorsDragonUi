# Stats character/equipment icon

World of Warcraft artwork is copyright Blizzard Entertainment, Inc. The user
selected option 1 from the local ten-icon Stats study: the silver-and-gold
helmet/cog used by the character window's equipment-manager tab. It is reused
as the Stats header icon, without importing another addon's code or framework.

## Verified source and crop

- Original sheet: [Gethe/wow-ui-textures, PaperDollInfoFrame/PaperDollSidebarTabs.PNG](https://github.com/Gethe/wow-ui-textures/blob/d23deaf8f44a7d280dc974a5c9d5321c013db59b/PaperDollInfoFrame/PaperDollSidebarTabs.PNG).
- Immutable commit: `d23deaf8f44a7d280dc974a5c9d5321c013db59b`, identified by its
  [commit message](https://github.com/Gethe/wow-ui-textures/commit/d23deaf8f44a7d280dc974a5c9d5321c013db59b)
  as `9.2.7 (45114)`. This establishes its presence in that Shadowlands build;
  the long-lived artwork is not claimed to originate in that expansion.
- Original canvas: 64×256 PNG, RGBA. Selected pixel rectangle:
  `(1,120)-(34,155)`, right/bottom excluded, 33×35.
- Independent owning-code evidence:
  [DragonUI sidebartabs.lua](https://github.com/NeticSoul/DragonUI/blob/407dd0069f2b853388483e9e7e169198abf4c6d0/DragonUI/modules/characterpanel/sidebartabs.lua)
  uses `equipIcon = { 0.015625, 0.53125, 0.46875, 0.60546875 }` on the stock
  PaperDollSidebarTabs sheet, matching those exact pixels. The source draws
  the icon at 33×35; the Stats adaptation preserves that ratio.

## Preparation and rendering

`media/tex/stats/CharacterEquipment.tga` retains an uncompressed 32-bit RGBA
preparation canvas. Its dimensions are 64×64, with every selected source pixel
copied unchanged to `(15,14)-(48,49)` and transparent padding elsewhere. There
is no resampling, recoloring, compositing or generated artwork in this asset.
The existing `scripts/prepare_client_textures.py` `save_image` helper wraps
those pixels in lossless BLP2 Raw1 where exact palette storage is possible,
otherwise Raw3. The TGA basename is also recognized by its normal preparation
pass. The selected original PNG and the comparison studies stay outside the
runtime payload.

The runtime manifest includes only `media/tex/stats/CharacterEquipment.blp`.
The Stats module samples UVs `(15/64,48/64,14/64,49/64)`, drawing at
`24 * 33 / 35` wide by 24 frame units high, centered in its existing icon slot.
Ordinary BLEND preserves the icon's alpha, silver/gold colors and shaded edges.
The existing single icon region and success-aware binding/retry lifecycle are
reused; no new frame, updater or setting is added. The minimap's Dragonflight
glyph remains independently used and attributed by its original owner.

## Rights and evidence limits

The PNG mirror does not grant a standalone artwork license. DragonUI's
[third-party notices](https://github.com/NeticSoul/DragonUI/blob/407dd0069f2b853388483e9e7e169198abf4c6d0/DragonUI/THIRD_PARTY_NOTICES.md)
likewise distinguish Blizzard character-panel textures from software covered
by MIT. Cropping and format conversion do not change Blizzard's ownership.
This notice records the selected client artwork and its addon use, without
claiming that the mirror or another addon's code license relicenses the image.

The local design preview is a static composition, not an in-game capture.
No local tests, standalone checks or addon/game execution were run.
