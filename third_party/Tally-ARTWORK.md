# Tally compartment and appearance proposals

The selected runtime styles are Continuous silver, Soft graphite and Gothic
proposals 01, 02, 03, 04, 07, 10, 11 and 13. The selected Gothic pixels
come from RothUI, Diablo III UI and ARPG. Their
[pinned artwork records](../docs/designs/tally-gothic/ARTWORK.md) and
[runtime preparation records](../docs/designs/tally-gothic/runtime-artwork.json)
include the source files, crops and notices. The full
[twenty-design gallery](../docs/designs/tally-gothic/index.html), original bytes
and thirty earlier geometric studies remain outside the runtime payload.

The attached tally forms a continuous lower compartment, sharing the action
bar's original bottom silver edge as its only top border. There is no gap,
second top rail, mounting tab or leg. Detached mode retains the original gold
pill. All three native icons remain unchanged. All thirty appearance
proposals, cursor preview images and research notes stay outside the shared
runtime manifest. No source-addon framework, font, retail atlas API or dependency
is imported.

## Runtime compartment assembly

Attached mode hides the existing pill background, yellow fill and bezel,
restoring them when detached. A single prepared legacy RGBA TGA starts at
`DFRL.GetActionBarSilverBottom()`, without a top-border texture of its own.
`core/tally.lua` supplies the style registry and retains the required shipped
source notices. Each 1024-by-128 canvas contains 600-by-128 pixels at double
resolution; UV `(0,600/1024,0,1)` displays a 300-by-64 logical canvas. Actual
lower extents are separate from transparent canvas padding.

Continuous silver's sides and lower edge use the unchanged bundled
`media/tex/actionbars/HDActionBar.tga` half-shell. Each side samples source
rectangle `(0,35,7,92)`, mirrored on the right. Two mirrored lower halves
sample `(16,105,512,112)`. The dark body is inset by source x12
(3.515625 local units at the 300-unit default width), meeting the beveled
corners. The bar's original lower silver edge remains the compartment's only
top border. Its existing dark body is baked beneath those strips. Source
ownership and notices remain those pinned in [XP-ARTWORK.md](XP-ARTWORK.md).
Soft graphite uses the original study's rounded lower contour and shading,
with counter dividers left to the live renderer. Gothic styles preserve the
actual source ornaments and preparation described in the linked records.
Only Gothic 13's runtime footer is proportionally smaller than its proposal,
keeping its 39-unit extent inside the default joined-XP clearance. The runtime
manifest contains ten prepared TGA files and the registry, without any
source-addon framework or font. No SpartanUI artwork was selected for runtime.

Demon reliquary (`gothic13`) is the default. It uses the center-rail crop
`(106,88,400,106)`, omitting the source's six
faded rightmost columns before x406. The original destination rectangle and
ornament dimensions remain unchanged; the corrected crop closes its
right-side join. See the [prepared detail](../docs/designs/tally-gothic/right-join-detail.png).

Iron sarcophagus's backing mask is inset by `300 * 12 / 1024` units on each
side for its upper 18 units, matching the action bar's visible lower edge.
The lower rim's wider silhouette is no longer projected straight up outside
that edge. Only the backing alpha mask changes; all R04 crops, side-wall pixels,
lower flare, artwork dimensions and counter layout remain the same.

The runtime registry also records the content center and scale separately from
the artwork. Demon reliquary, Gothic leaf corners and Gothic cornerwork use a
13-unit center and 95% content scale. Roth shrine uses a 12-unit center and
Roth scrollwork a 10-unit center, both at 90%. ARPG carved cornice uses a
14-unit center at 100%. Centers are UI layout reference units at the 300-unit
artwork width. The latest two-unit upward moves for Roth scrollwork and ARPG
retain their existing content scales, native font, icons and frame borders.
Prepared frame pixels, crops and lower extents remain unchanged. See the
[content-fit record](../docs/TALLY-ATTACHMENT.md#content-fit).

## Artwork actually used in the proposals

- `media/tex/actionbars/HDActionBar.tga`: 512×128 RGBA half-shell; the right half
  is mirrored. The prepared joined-XP half uses 512×144 occupied pixels in
  `HDActionBarXP.tga`'s 512×256 canvas. Both keep sixteen transparent source
  rows below their visible silver bevel. The proposals display each half at
  150×64 or 150×72. The original pixels and verified source pins are in
  [XP-ARTWORK.md](XP-ARTWORK.md), including
  [alchem1ster commit 49f20659](https://github.com/alchem1ster/DragonflightReloaded/blob/49f20659cefcf621abd89fabb67f906b62ec7523/media/tex/actionbars/HDActionBar.tga)
  and
  [Reforged commit 2a8d2ffb](https://github.com/Stormhand-dev/DragonflightUI-Reforged/blob/2a8d2ffb3d9262f0d2af2071b9b47ef27f76f7f8/media/tex/actionbars/HDActionBar.tga).
  Concept 01 previews the same side and bottom source strips listed in the
  runtime assembly above. Every concept draws its lower body behind the
  original shell, retaining the original silver edge as its only top seam.
  Original bytes remain in the runtime sources.
- Existing `HDActionBarBtn.tga`, softened purple XP fill and character-window
  metal lower edge are composed at the rectangles in the preview script.
  Gothic/cornice variants use `Chrome.tga` rectangle `(896,0,928,64)` only
  along their lower lip. Existing notices remain authoritative:
  [Character-ARTWORK.md](Character-ARTWORK.md) and [XP-ARTWORK.md](XP-ARTWORK.md).
  Other compartment outlines, subdivisions, shading and colors are new
  geometric proposal compositions. No proposal adds its own top stroke.
- Runtime kills uses `Interface\\Cursor\\Attack.blp`; cache cost uses
  `Interface\\Cursor\\LootAll.blp`, both unchanged at 18×18. Preview-only PNG
  equivalents are the full 32×32 images from
  [Attack.PNG](https://github.com/Gethe/wow-ui-textures/blob/e80e3278cc833c89e1f3fc79557b68315d750935/CURSOR/Attack.PNG)
  and
  [LootAll.PNG](https://github.com/Gethe/wow-ui-textures/blob/e80e3278cc833c89e1f3fc79557b68315d750935/CURSOR/LootAll.PNG),
  commit `e80e3278cc833c89e1f3fc79557b68315d750935`, a Dragonflight PTR
  10.0.0 (45454) texture snapshot. They do not replace native runtime textures.
  Gold uses the top-left 32×32 quadrant of bundled 64×64
  `media/tex/chat/cleaner_coins.tga` (`SetTexCoord(0,0.5,0,0.5)`), unchanged.

World of Warcraft and inherited Diablo artwork remain Blizzard Entertainment's
property. Public mirrors and addon software licenses do not transfer ownership
of game images. The project owner has confirmed permission for the upstream
custom textures already bundled here; that confirmation is not extended to
newly researched third-party media.

## Wider Diablo-style source search

The source research inspected real TGA files and their owning code, separately
from the thirty new compositions. No external Diablo-style texture was added
to runtime or used to make those compositions.

| Source and exact candidate                                                                                                                            | Inspected image and assembly                                                                                                                                                                                                                                                                                                                                                                            | Practical idea and limits                                                                                                                                                      |
| ----------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [RothUI `d3_bottom.tga`](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/wow6.0/rBBS_RothUI/media/d3_bottom.tga)       | 512×128 TGA, occupied bounds `(0,85,512,128)`. Its [config](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/wow6.0/rBBS_RothUI/config.lua) uses the full image, scale .82, LOW level 6, bottom y−10; [style](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/wow6.0/rBBS_RothUI/style.lua) parents it to the same drag owner as the bars. | Best thin dark-bronze rail reference, with curled ends. Old WoD-era artwork, not Midnight. Root MIT code license does not resolve inherited Diablo-art rights.                 |
| [RothUI Diablo 2 bar](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/wow6.0/rBBS_Diablo2/media/bar.tga)               | 1024×128, occupied `(24,37,992,128)`; full canvas at .55 scale in its [config](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/wow6.0/rBBS_Diablo2/config.lua).                                                                                                                                                                                                          | Silver scrollwork is useful inspiration, but baked button slots prevent treating the whole file as a tally rail.                                                               |
| [RothUI Diablo 1 bar](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/wow6.0/rBBS_Diablo1/media/bar.tga)               | 1024×256, occupied `(0,13,1024,243)`; full canvas at .7 scale.                                                                                                                                                                                                                                                                                                                                          | Grey stone material reference; much deeper than this tally needs.                                                                                                              |
| [RothUI backdrop border](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/wow6.0/rBBS_Backdrop/media/border_diablo.tga) | 128×16, an eight-piece native backdrop strip; owner uses edgeSize16/inset3, also edgeSize9.                                                                                                                                                                                                                                                                                                             | A practical scalable-border family, not an isolated horizontal rail.                                                                                                           |
| [ARPG `TopBar.tga`](https://github.com/kyau/ARPG/blob/9c53e246ff181d7259e3e355836044c5f8ade5be/Interface/AddOns/ARPG/Media/Textures/TopBar.tga)       | 1024×64, occupied `(80,0,944,63)`; [Art.lua](https://github.com/kyau/ARPG/blob/9c53e246ff181d7259e3e355836044c5f8ade5be/Interface/AddOns/ARPG/Core/Art.lua) uses full texture, TOP y6, scale .64, BACKGROUND layer3.                                                                                                                                                                                    | Strong Gothic lip and central plaque reference. Its README explicitly identifies Diablo 3 art and RothUI influence; LGPL metadata does not resolve ownership of inherited art. |
| [ARPG `BottomBar.tga`](https://github.com/kyau/ARPG/blob/9c53e246ff181d7259e3e355836044c5f8ade5be/Interface/AddOns/ARPG/Media/Textures/BottomBar.tga) | 2048×256, occupied `(316,61,1732,256)`; same owner uses full image at 2048×255, .64 scale.                                                                                                                                                                                                                                                                                                              | Black steel, silver curled figures and teal details; orb cutouts make it too broad as a direct tally background.                                                               |

The inspected RothUI and ARPG trees were complete. Their pinned commits are
`9a9ce9744ce404991fc06066291614fe1765ee20` and
`9c53e246ff181d7259e3e355836044c5f8ade5be`. Their
[MIT](https://github.com/zorker/rothui/blob/9a9ce9744ce404991fc06066291614fe1765ee20/LICENSE.md)
and [LGPL/project notices](https://github.com/kyau/ARPG/blob/9c53e246ff181d7259e3e355836044c5f8ade5be/README.md)
were inspected with the game-art distinction above.

[DiabolicUI](https://github.com/GoldpawsStuff/DiabolicUI) was also researched,
including its `bars-single`, `bars-floater`, small bar and border families at
commit `2e663e13fcccbb16a61eff2ec21b631500f0db54`. Its
[license](https://github.com/GoldpawsStuff/DiabolicUI/blob/2e663e13fcccbb16a61eff2ec21b631500f0db54/LICENSE.md)
explicitly excludes media and forbids its redistribution/modification. It is a
linked visual reference only; none of its textures appears in the deliverables.
[Arahort's D2 Resurrected variant](https://www.curseforge.com/wow/addons/diabolicui-arahort-edition)
is another linked stone/silver/recessed-panel idea. Conflicting Public Domain
metadata and custom/art-origin notices leave file-specific reuse unresolved;
no media from it was selected. The older galaxy119/Roth_UI mirror could not be
pinned through the connector and was not counted as inspected.

## Curated ports and retail comparison

Targeted repository-tree searches revisited NeticSoul/DragonUI and
s0h2x/pretty_actionbar. Actual existing candidate/atlas previews from the
DragonflightUI, Reloaded/Reforged and Turtle families were inspected as whole
sheets. Their published experience-bar strips have their own endcaps and/or
segment overlays. Existing [XP source pins](XP-ARTWORK.md) identify the exact
artwork, source rectangles and notices; duplicate inherited art is not counted
as an independent design.

Six pinned Blizzard `StatusTrackingBar.xml` / `StatusTrackingBarTemplate.xml`
files were re-fetched across
[Dragonflight 10.2.7 (55461)](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_ActionBar/Mainline/StatusTrackingBar.xml),
[The War Within 11.2.7.64587](https://github.com/Gethe/wow-ui-source/blob/0b78d65dac26c34898ffc19134f224de2ef0f885/Interface/AddOns/Blizzard_ActionBar/Mainline/StatusTrackingBar.xml)
and
[Midnight 12.1.5.70448](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_ActionBar/Mainline/StatusTrackingBar.xml).
They define separate XP background/frame/overlay components, not this custom
kills/gold/cache tally connector. That observation is limited to those reviewed
components. No coordinates for an unverified atlas member are guessed.

The practical match is the installed action bar's silver bevel, reused as the
top edge of a continuous lower tally compartment. The proposals retain that
shared seam while varying the lower shape, materials and subdivisions. Static
proposals show composition and artwork only; they do not establish native
client rendering.
