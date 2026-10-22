# Gothic tally proposal artwork

These are **20 assemblies of existing artwork from four public addon
repositories**, rather than 20 independently authored UI projects. The carved
rails, stone, scrollwork, knots, claws and skulls come from the actual texture
files listed below. Preparation crops and slices those pixels, fits their
centres and ends, and adjusts tone where needed to meet the action bar. It does
not replace the ornament with drawn geometric approximations.

Each assembly begins directly beneath the action bar's existing lower silver
edge. That edge is the shared top border: the proposals remove the source
frame's upper rim and add no suspension legs, tabs or gap. The original attack,
coin and cache icons are retained. Sample values are illustrative.

The gallery's [sources.json](sources.json) records the exact files, immutable
commits, source dimensions, crop rectangles and preparation used by each
number. Rectangles use pixel coordinates with the right and bottom excluded.
They describe proposal adaptations, not newly discovered native atlas regions.

## Addon artwork

| Source family | Selected real artwork and use |
| --- | --- |
| [RothUI, `9a9ce974`](https://github.com/zorker/rothui/tree/9a9ce9744ce404991fc06066291614fe1765ee20) | `wow6.0/oUF_Diablo/media/castbar.tga` (R01), `targettarget.tga` (R03), `demonic_fury_border.tga` (R04), `d3_altpower_border.tga` (R05), `combo_back.tga` (R06), `combo_bar_left.tga` (R09), and `vehiclebar.tga` (R16) supply bronze troughs, lower filigree, scroll ends and carved skirts. The left scroll is mirrored on the right. `wow4.0/rTextures/d3_nameplate_border.tga` (R25) supplies knotted iron. `archive/rBottomBarStyler/d2tex/border_left.tga` (R20), also mirrored, supplies Diablo II filigree. The Diablo I bar's stone interior uses crop `[150,100,280,180)`, combined with the existing filigree. Separate `d3_head_garg.tga` and `d3_head_skull.tga` supply the gargoyle and bone footer ornaments. |
| [ARPG, `9c53e246`](https://github.com/kyau/ARPG/tree/9c53e246ff181d7259e3e355836044c5f8ade5be) | `Interface/AddOns/ARPG/Media/Textures/TopBar.tga`, crop `[325,24,699,63)`, supplies its carved lower cornice and textured channel. The crop omits the plaque's original upper rim and keeps its carved lower corners. [Core/Art.lua](https://github.com/kyau/ARPG/blob/9c53e246ff181d7259e3e355836044c5f8ade5be/Interface/AddOns/ARPG/Core/Art.lua) establishes the original full-texture assembly. |
| [Diablo_III_UI, `10aa68fe`](https://github.com/RickyElune/Diablo_III_UI/tree/10aa68fef2bfa11bba0eab42baa952b700eb1be5) | `media/UIButton_300x51_Normal.tga`, lower crop `[88,64,424,98)`, supplies the button's original carved bottom and corners. `media/target.tga` and `target_elite.tga` supply target-frame ornament and the elite footer. Their [native owner](https://github.com/RickyElune/Diablo_III_UI/blob/10aa68fef2bfa11bba0eab42baa952b700eb1be5/embeds/oUF/elements/rare.lua) selects the complete frame; the gallery's lower-only compositions are adaptations. This repository credits galaxy119's original UI. |
| [SpartanUI, `5515bca9`](https://github.com/spartanui-wow/SpartanUI/tree/5515bca906287a190240a5d99cd40a938e76d1de) | Actual `DataBar-Left.png`, `DataBar-Center.png` and `DataBar-Right.png` files from Classic, Tribal, Shard and Midnight supply carved bronze, tusks, angular stone and purple Gothic trim. [Themes/DataBarArt.lua](https://github.com/spartanui-wow/SpartanUI/blob/5515bca906287a190240a5d99cd40a938e76d1de/Themes/DataBarArt.lua) specifies the native end widths, repeated centres and UVs. `Themes/Classic/Images/base-left1.blp` supplies weathered grey stone. The `DataBar-Card.png` screenshot cards, including their baked example text, are not used. |

RothUI's native [cast-bar assembly](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/wow6.0/oUF_Diablo/core/lib.lua),
[resource borders](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/wow6.0/oUF_Diablo/core/bars.lua)
and [Diablo II frame assembly](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/archive/rBottomBarStyler/core.lua)
were inspected. Some optional media-library ornaments have no owning reference
in the targeted code; their proposed assembly is identified as an adaptation.

## Vanilla action-bar context

The upper context uses the original Vanilla action-bar arrangement documented
by [1.12.1 MainMenuBar.xml](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/d162a4c0d198a4381b5b6573d975635ed7316702/1.12.1/FrameXML/MainMenuBar.xml),
with its companion action-bar and button templates at the same commit.
The retained legacy Dwarf bar and end-cap pixels come from
[Gethe's pinned texture mirror](https://github.com/Gethe/wow-ui-textures/tree/e80e3278cc833c89e1f3fc79557b68315d750935/MAINMENUBAR).
That mirror is Dragonflight PTR 10.0.0 (45454); these retained textures are not
claimed byte-identical to the 1.12.1 release.

The compact context adapts that chrome to seven 36-pixel native slots with
six-pixel gaps and a 300-pixel body. XP-on adds the original ten-pixel XP strip;
the tally meets the lower edge in either state. Local packaged-game extracts
were also inspected; its modified Dwarf menu quarter is not used to represent
the complete original bar. Exact extraction and assembly records accompany the
gallery sources. The temporary Friz Quadrata preview face is not added to the
runtime payload.

## Notices and scope

The pinned repository licenses are [RothUI MIT](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/LICENSE.md),
[ARPG LGPL-3](https://github.com/kyau/ARPG/blob/9c53e246ff181d7259e3e355836044c5f8ade5be/LICENSE),
[Diablo_III_UI MIT](https://github.com/RickyElune/Diablo_III_UI/blob/10aa68fef2bfa11bba0eab42baa952b700eb1be5/LICENSE.txt)
and [SpartanUI MPL-2.0](https://github.com/spartanui-wow/SpartanUI/blob/5515bca906287a190240a5d99cd40a938e76d1de/LICENSE).
Preserve their attribution and applicable notices with copied or adapted
material; the pinned license files are retained in [research/licenses](research/licenses/).
These software licenses do not transfer ownership of inherited
Blizzard/Diablo game artwork. Goldpaw's separately restricted DiabolicUI media
is explicitly excluded.

The twenty original images remain static proposals outside the runtime
manifest. The runtime menu contains Gothic 01, 02, 03, 04, 07, 10, 11 and 13,
plus Continuous silver and Soft graphite, under `/sdui` → Kills, Gold & Caches.
The ten prepared textures and their registry
are documented in [runtime-artwork.json](runtime-artwork.json) and
[the runtime sheet](runtime-styles.png). Gothic 13's runtime footer is
proportionally reduced to fit within 39 units below the shared seam; its
original pendant sizing remains in the proposal image. No SpartanUI texture enters runtime.

Demon reliquary is the default. Its center
crop ends at x400 instead of x406 to omit its transparent edge fade, closing
the right join while preserving both end ornaments and their placement. The
[runtime detail](right-join-detail.png) shows the prepared join on a colored
background; the updated gallery uses the same corrected source crop.

Iron sarcophagus's upper backing is clipped to the action bar's visible inset
for 18 units below the seam. Its source R04 border pixels and lower flare stay
unchanged. The [join comparison](iron-join-detail.png) shows the removal of the
background ears using the actual prepared textures.

No source-addon framework or gameplay code is imported, and no preview font
enters the payload. Source inspection and artwork preparation do not establish
live rendering. No local checks, tests or addon/game execution were performed.
