# Loot notification artwork

The user selected **02**, the silver retail loot alert, with the gold
**You received** heading and item name in the game's Friz Quadrata font.
Only that frame crop enters the runtime payload. The original four proposals
remain archived; their slot/status lines and collection glow were proposal
choices and are omitted from the selected view. Already-collected drops never
enter the selected view.

World of Warcraft artwork is copyright Blizzard Entertainment. Cropping,
tinting, repacking and conversion do not relicense it. DragonUI's notices
explicitly distinguish Blizzard artwork for in-game use from its MIT software.
Gethe's texture mirror has no root license grant covering these images; public
availability is not a separate redistribution license. Existing project notices
and the owner's upstream-texture permission remain relevant, but no general
new license is asserted for these candidate pixels. No source addon or framework
is imported. Only the selected, attributed crop enters the runtime payload.

## 01 · Retail item card (unselected)

- Source: [NeticSoul/DragonUI](https://github.com/NeticSoul/DragonUI/tree/27255b131d734113f92a379c55a7df054e36be52),
  commit `27255b131d734113f92a379c55a7df054e36be52`.
- Exact file: [`DragonUI/Textures/UI/looting-itemcard.blp`](https://github.com/NeticSoul/DragonUI/blob/27255b131d734113f92a379c55a7df054e36be52/DragonUI/Textures/UI/looting-itemcard.blp),
  512 × 256, uncompressed BGRA BLP2 encoding 3.
- Atlas definitions:
  [`DragonUI/utils/atlas.lua`](https://github.com/NeticSoul/DragonUI/blob/27255b131d734113f92a379c55a7df054e36be52/DragonUI/utils/atlas.lua).
  Background `looting_itemcard_bg`: `(0, 0, 298, 76)`;
  normal outline `looting_itemcard_stroke_normal`: `(0, 78, 298, 154)`;
  click/hover outline: `(0, 156, 298, 232)`;
  rarity tag: `(304, 0, 512, 15)`. Coordinates exclude right/bottom.
- Owning assembly:
  [`DragonUI/modules/loot_skin.lua`](https://github.com/NeticSoul/DragonUI/blob/27255b131d734113f92a379c55a7df054e36be52/DragonUI/modules/loot_skin.lua)
  draws background then tag on BACKGROUND, outline on BORDER and click-state
  outlines on OVERLAY with ADD blending. Only its background receives quality
  tint. The passive proposal uses background + normal outline, without importing
  the source's loot-window behavior, click states or font choices.
- Retail ownership is corroborated by `LootFrameElementTemplate` in
  [Dragonflight 10.2.7](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/LootFrame.xml),
  [The War Within 11.2.7](https://github.com/Gethe/wow-ui-source/blob/0b78d65dac26c34898ffc19134f224de2ef0f885/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/LootFrame.xml)
  (`version.txt`: `11.2.7.64587`), and
  [Midnight 12.0.0](https://github.com/Gethe/wow-ui-source/blob/f3166dfd584ccf4f7a8e57549e95f9908693c7f9/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/LootFrame.xml)
  (`12.0.0.65614`). The inspected current source also uses it at commit
  `b9be9379719047977fca4dba1bb1d9988e8840b3`, version `12.1.5.70448`.
  These shared atlas names establish cross-expansion use, not an exact native
  client-build provenance for the downloaded DragonUI BLP bytes.
- [Source artwork notice](https://github.com/NeticSoul/DragonUI/blob/27255b131d734113f92a379c55a7df054e36be52/DragonUI/THIRD_PARTY_NOTICES.md)
  and [software license](https://github.com/NeticSoul/DragonUI/blob/27255b131d734113f92a379c55a7df054e36be52/DragonUI/LICENSE.txt).
- Legacy adaptation after selection: crop the verified regions into TGA sheets
  and use ordinary `SetTexture`, `SetTexCoord`, draw layers and native tint.
  No `SetAtlas`, retail mixin, mask or source-addon dependency is needed.

## 02 · Silver loot alert (selected)

- Source: [Gethe/wow-ui-textures](https://github.com/Gethe/wow-ui-textures/tree/e80e3278cc833c89e1f3fc79557b68315d750935),
  commit `e80e3278cc833c89e1f3fc79557b68315d750935`, identified by its commit
  as Dragonflight PTR `10.0.0 (45454)`.
- Exact file: [`LootFrame/LootToast.PNG`](https://github.com/Gethe/wow-ui-textures/blob/e80e3278cc833c89e1f3fc79557b68315d750935/LootFrame/LootToast.PNG),
  1024 × 256 RGBA PNG. The verified background is `(289, 148, 565, 244)`,
  276 × 96 pixels. It is a silver frame with a dark textured interior.
- Owning source: `LootWonAlertFrameTemplate` in
  [Dragonflight's `AlertFrameSystems.xml`](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_FrameXML/Mainline/AlertFrameSystems.xml).
  Its UVs are `(0.28222656, 0.55175781, 0.578125, 0.953125)` on that sheet.
  The same file/region is still referenced in the inspected 11.2.7 and 12.0.0
  source. The preview preserves side caps and stretches the middle horizontally;
  it uses none of the neighboring backgrounds, shine or glow cells.
- Adaptation after selection: convert the isolated crop to a legacy TGA and
  draw it with regular alpha blending, retaining side-cap proportions.
  The proposed text and collection glow are our composition, not that template's
  original label, roll controls or exact animation.

### Shipped adaptation

`media/tex/loot/Toast.tga` is a 512-by-128 RGBA canvas. The unchanged 276-by-96
background crop is placed at `(0, 0)` with transparent padding. Runtime UVs are
`(0, 276/512, 0, 96/128)` and regular alpha blending; no neighboring glow,
shine or alternative frame is included. The single card keeps the crop's native
aspect ratio, with an inset 50-by-50 icon and two text lines. The existing
WhiteIconFrame rim is tinted from the received item color or native quality.
Missing native icon data is omitted, never replaced by an example icon.

The same pinned Dragonflight `AlertFrameSystems.xml` supplies a 0.2-second
fade-in and a 1.5-second fade-out starting at 4.05 seconds for the normal item
alert. The addon reproduces those cosmetic timings with ordinary legacy UI
alpha updates. It does not import the retail animation XML, mixins, sheen,
sounds, roll controls or item acquisition code.

The game-owned `Fonts\\FRIZQT__.TTF` is requested for both the gold caption
and item name, at sizes 12 and 14 without an outline and with a black shadow.
The inspected installed game includes `data/fonts/frizqt__.ttf`; its native
`data/interface/framexml/fonts.xml` uses that face for `GameFontNormal`.
The addon ships no font bytes and falls back to resolved DEFAULT if the native
font request fails. Its heading and Layout caption use the fourteen-language
addon catalogs; item names and colors remain received game data.

## 03 · Plain addon metal

This uses the existing `media/tex/character/Chrome.tga` 1024 × 256 sheet and its
verified eight corner/edge regions. The source pins, original BLP canvases,
rectangles and ownership notices remain in [Character-ARTWORK.md](Character-ARTWORK.md).
The static proposal reuses the shared `panel` assembly helper in
`scripts/preview_guardian_designs.py` with shallow card proportions. Its dark
interior is an ordinary fill. No additional texture is required.

## 04 · Floating loot label

This combines the existing `media/tex/levelup/Backdrop.tga` and `Glow.tga`, each
512 × 128, with a native-quality icon rim and an ordinary thin gold baseline.
The soft textures are the addon's previously prepared artwork, not newly found
Blizzard atlas regions; see [LevelUp-ARTWORK.md](LevelUp-ARTWORK.md).
The plus touches the item name, matching compact chat. These are static examples
of the possible collection glow, not a selected animation or timing policy.

## Shared icon rim and preview examples

All four proposals reuse existing `media/tex/character/QualityBorder.tga`, with
its complete original canvas tinted by the sample item color. Its original
Blizzard `COMMON/WhiteIconFrame.PNG` source and crop are recorded in
[Character-ARTWORK.md](Character-ARTWORK.md). No quality index is inferred from
the sample color by runtime code.

Representative preview icons are
[`ICONS/INV_Boots_Plate_04.PNG`](https://github.com/Gethe/wow-ui-textures/blob/d23deaf8f44a7d280dc974a5c9d5321c013db59b/ICONS/INV_Boots_Plate_04.PNG)
and
[`ICONS/INV_Helmet_25.PNG`](https://github.com/Gethe/wow-ui-textures/blob/d23deaf8f44a7d280dc974a5c9d5321c013db59b/ICONS/INV_Helmet_25.PNG),
64 × 64 each, at the mirror's pinned `9.2.7 (45114)` commit
`d23deaf8f44a7d280dc974a5c9d5321c013db59b`. They are sample pixels, not verified
icon assignments for the packaged game's named custom items. They do not ship.
Georgia substitutes for DEFAULT in the original proposal images. The selected
preview uses the game's existing Friz Quadrata through a local preview-only
font path. No font file or font setting is added. Common collected, common new
and epic collected samples remain historical proposals; the selected preview
shows only eligible common and epic drops, with no collection subtitle.

## Research coverage and stored artifacts

Task-specific tree searches covered NeticSoul/DragonUI, PentSec/DragonUI,
Karl-HeinzSchneider/WoW-DragonflightUI, Stormhand-dev/DragonflightUI-Reforged,
ghbset/DragonUI_NewEra, mabu95/PhoUI and alchem1ster/DragonflightReloaded at
resolved commits. The useful DragonUI item-card source and its owning code were
inspected; other tree matches were discovery leads, not independently licensed
designs. The companion pack and frame chrome were considered alongside existing
bundled equivalents. Repeated fork artwork is not counted as a new option.

The wider web search led to the Gethe texture/source mirrors and the owning
retail templates above. The texture mirror's recursive tree was truncated;
only identified candidate files and targeted refs were inspected, without an
exhaustive-coverage claim. Its `live` branch identifies 9.2.7, so it was not
mistaken for current Midnight. Expansion-specific source tags and the pinned
Dragonflight PTR texture commit supplied the build evidence instead.

`docs/designs/loot-notifications/asset-regions.png` exposes the actual selected
candidate regions against a checkerboard. `designs.json` records the four
proposals and source files with `selected: "02"`. `selected.png` shows the final
two-line direction using the same native card geometry. Original bytes remain in the
temporary source directory, separate from crops and compositions.
No proposal image, example icon, downloaded original or gallery file is in the
runtime manifest. `scripts/prepare_loot_art.py` writes only the chosen runtime
crop and its static preview; `--font` supplies a local game font for the preview.
Static artwork preparation does not establish game rendering. No addon/game
execution or local checks were performed.
