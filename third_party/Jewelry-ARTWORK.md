# Equipped jewelry artwork

Selected **03 — Cold-lit runes** uses static Runecarver metal and rune accents, desaturated to grey to match the action-bar surround, with no separate inner-circle rim. The thin-bezel attachment keeps each item joined to the existing action bar without an extra inner/lower curved rail line. Empty slots retain the selected original WoW inventory pictures inside the carving, without a gold circle. The socket body keeps the original bar material, without a panel, title or side ornament. Native item icons are read at runtime rather than bundled into this artwork.

## Selected grey-metal Runecarver housing

- Original Blizzard texture: [`Runecarving/RuneCarvingUI.PNG`](https://github.com/Gethe/wow-ui-textures/blob/da4d3587e46ee7db8655b978d49b7d55024084ff/Runecarving/RuneCarvingUI.PNG), **1024 × 2048**, Gethe mirror commit `da4d3587e46ee7db8655b978d49b7d55024084ff`, **Shadowlands 9.0.5 build 37705**.
- Source SHA-256: `8df6e6c889eda1e100b9550762b573a647730b0435a6702ae194b55b830f124c`.
- `runecarving-frame-runes-lit`: sheet rectangle `(451,1135)-(899,1589)`, **448 × 454**.
- `runecarving-frame-glow`: sheet rectangle `(1,1135)-(449,1589)`, **448 × 454**.
- Atlas names/UVs come from [TextureAtlasViewer Data.lua](https://github.com/LanceDH/TextureAtlasViewer/blob/e58691c23218b25a368f20c8cfebd8f482ed8ce3/Data.lua), embedded **build 37864**. The selected crops were inspected against the earlier pinned 37705 sheet; the complete atlas is not an isolated widget.
- The [native Runeforge crafting XML](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_RuneforgeUI/Blizzard_RuneforgeCraftingFrame.xml) separates the normal and runes-lit backgrounds. Its **10.2.7 build 55461** source pin corroborates native use, rather than matching the earlier texture export's build. This jewelry assembly uses the lit artwork continuously, without importing crafting logic or animation.

`scripts/prepare_jewelry_runecarver.py --source /path/to/RuneCarvingUI.PNG` accepts only the pinned source bytes. It clears the original inner crafting controls with an antialiased normalized-radius 0.33 cut, resizes the remaining lit frame to 118 × 120 and places it at `(5,4)` on a transparent 128 × 128 canvas. The original halo resizes to 124 × 126 at `(2,1)`, with source alpha multiplied by 0.32, below the frame. The completed cell blends 95% grayscale with 5% source RGB to neutralize the cyan metal, runes and halo while retaining their shading and alpha. This color treatment is baked by the preparation script; runtime performs no desaturation. A changed-only 90% native-rarity/10% white vertex-color multiplier subtly tints the prepared grey housing. No native crafting state or item power is introduced.

The durable authoring input is `media/tex/jewelry/Runecarver.tga`; the original full sheet and intermediate crops do not ship or remain as task downloads. `prepare_jewelry_art.py` includes this complete cell at authoring rectangle `(768,0)-(896,128)`. The existing client-texture repacker moves it to `(384,0)-(512,128)` in the legal **512 × 128** `Frame.blp`, retaining the existing gold, pet/meter and neutral rarity cells. This reuses an existing runtime file and does not change the shared manifest.

Each of the five new static `BORDER` regions uses UVs `384/512, 1, 0, 1`, centered on the corresponding icon, at local size `43 * 128 / 108`. At the reference 36-unit action buttons this is a 42⅔-unit canvas including clear padding and the soft halo. The original five circle regions are removed entirely, without a replacement border. No gold or rarity-colored circle is drawn around equipped or empty icons. Native rarity RGB colors the effects-only hover text and the housing multiplier; missing quality keeps its existing green text fallback and untinted grey metal. The animated halo below uses native RGB with clear moving highlights. Pet/meter crops, cooldown values and source/slot identities are unchanged; the inset icon fit and end-cap correction are described below.

Only the existing Layout edit envelopes grow to include the larger static canvas: attached top clearance becomes 41⅓ units at the reference button size, while the detached region uses the larger of the socket and carving sizes around the same center. This does not move icons, rims, rails, roots or confirmed geometry. The five regions reuse the current overlay, parent visibility and attachment/world cleanup in both Performance Mode states. They add no frame, getter, event, updater, setting or saved state. Carving texture, geometry and UV writes happen at construction; only changed visible rarity updates vertex color. The steady halo is baked into that same region. Source/region counts do not establish native rendering or FPS. Only static artwork preparation, source review and pinned formatting were performed, with no local tests, standalone validation or addon/game execution.

This is original World of Warcraft artwork, copyright Blizzard Entertainment. Public availability and software licenses do not transfer its ownership or supply a blanket art redistribution license. Existing project permission for upstream custom art does not relicense this Blizzard texture; its provenance remains in the shipped jewelry module. No source addon code, fonts or framework is imported.

## Steady rarity glow

One lazy `OVERLAY` region per equipped slot reuses the Runecarver housing crop
`384/512, 1, 0, 1` in the existing `Frame.blp`. It shares the housing's size,
center and original alpha, with additive blending, fixed alpha 0.4 and validated
native rarity RGB. The original carved shading and baked halo supply the glow's
shape; there is no upward movement, pulse or texture animation. Geometry, UVs,
texture, blend and intensity bind only at construction. Color and visibility
change only when needed through the existing equipment reader.

Empty or unknown-quality slots have no extra glow. Visibility, editing,
Performance Mode and world/disabled cleanup hide it while retaining regions
for reuse; Performance Mode keeps the static housing tint. Icon size, slot
order, attachment and native cooldown animation are unchanged. The retired
moving-halo atlas, its authoring copy and preparation helper are removed, so
this effect adds no runtime file or separate artwork dependency. The reused
housing retains the Blizzard attribution above. Native appearance remains
unverified; no addon or game was executed locally.

## Shared pet/meter rim source

- [Karl-HeinzSchneider/WoW-DragonflightUI, commit b8b35451d4621a8097e887385f72ec03e17765f1](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/tree/b8b35451d4621a8097e887385f72ec03e17765f1).
- Original file: [`Textures/bagborder2.blp`](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/b8b35451d4621a8097e887385f72ec03e17765f1/Textures/bagborder2.blp), 64-by-64 RGBA, preserving source colors and alpha.
- [MIT notice](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/b8b35451d4621a8097e887385f72ec03e17765f1/LICENSE), copyright 2022 Karl-HeinzSchneider. The relevant notice is retained in shipped `modules/ui/jewelry.lua` comments.

Original World of Warcraft artwork remains copyright Blizzard Entertainment. The source addon's software license does not transfer ownership of Blizzard artwork. The project owner has confirmed upstream custom texture redistribution permission; this does not change Blizzard ownership. No upstream Lua or fonts are imported. The former panel filigree and timer trim remain absent.

## Preparation and transparency

`scripts/prepare_jewelry_art.py` reads `bagborder2.blp` from a scratch directory supplied with `--sources`. A shared Raw1/Raw3 decoder preserves indexed colors and the separate alpha block; Pillow handles the other source formats. Pillow's own Raw1 path is not used because it omits that alpha block. This tool prepares image assets without loading or executing addon code.

`prepare_jewelry_art.py` retains its 1024-by-256 authoring canvas. The legal runtime `media/tex/jewelry/Frame.blp` is **512 × 128**, with the gold rim at `(1,1)-(73,73)`, pet/meter rim at `(129,1)-(201,73)` and neutral rarity rim at `(257,1)-(329,73)`. The client repacker copies these from the original authoring crops without resampling; see [Client compatibility](../docs/CLIENT-COMPATIBILITY.md). Jewelry no longer binds the old gold or neutral rim cells. Their shared authoring/source records remain for the pet/meter artwork; removing a jewelry drawing region does not alter another consumer's source pixels. All five Runecarver housings use only the fourth cell, centered on their original item and socket positions. The jewelry frame scale remains the native action-button width divided by 43. Native rarity reads also supply the stronger housing tint and separate animated halo below, without restoring a circle region or changing housing UVs.

Native item hover frames remain 32 by 32 at local vertical center 46.5.
The rendered item uses a centered artwork box set by `ICON_ART_SIZE` (currently 33.897596 units), shared by empty-slot
pictures and cooldown shade geometry. At reference 36-unit buttons this is
about 28.38 UI units, fitting inside the unchanged Runecarver opening. The
sixteen source bands keep the original fourteen interior UV windows, while
midpoint widths restore nonzero top and bottom caps. Uniform inset scaling
preserves image proportions; source UVs retain `1 / 1.05` magnification, from
`1 / 42` through `41 / 42`, including the complete selected vertical range.
Parts carry their scaled height of `ICON_ART_SIZE / 16` local units. A full five-item row uses
80 pooled image regions instead of 70, through the existing grouped compositor
and hidden/world retirement. No icon getter, clock, worker, frame, extra border
or saved value is added. This fit correction supersedes the earlier exact
fourteen-band geometry requirement; native rendering remains unverified.

`media/tex/jewelry/Cooldown.tga` is original generated geometry: an 8-by-8 atlas of 64 circular shade states, each 64 by 64 pixels on a transparent 512-by-512 canvas. State zero is clear, and states 1–63 cover increasing clockwise fractions of the circle, with transparent cell padding. The runtime selects a state from native inventory cooldown values and the native `GetTime` clock; it does not advance a private gameplay timer. The shade remains inside the icon circle and Runecarver housing.

Pet frames use the runtime 72-by-72 crop `(129,1)-(201,73)`, from
authoring rectangle `(576,56)-(648,128)`. `prepare_pet_rim` copies the original first rim's
RGB pixels and multiplies its alpha by an antialiased annular mask centered at
`(36, 36)`, retaining the gold band while removing the baked inner and outer
shadow. The circle has transparent padding inside its crop, avoiding a cut
through the shadow at the right edge. The original jewelry and pet/meter
runtime cells remain unchanged; no new runtime file is added.

The damage meter reuses that same prepared pet-rim crop for its circular source
icons: a 31-unit gold rim surrounds a 26-unit native circular icon at the existing
row icon center. It retains the original gold RGB/alpha, without a quality tint
or another prepared image. Legacy fallback strips clip only the source icon;
the complete ring is never sliced. Jewelry uses its own inset sixteen-band icon fit; this does not alter the meter rim. See
[DAMAGE-METER.md](../docs/DAMAGE-METER.md).

## Thin socket attachment

`scripts/prepare_jewelry_sockets.py` reads the existing `media/tex/actionbars/HDActionBar.tga` as texture data, without importing or executing addon code. The original file and its existing upstream artwork attribution remain intact. At the native reference of 36-unit buttons, six-unit gaps and a 300-by-64 bar background, it copies the original 12-unit upper strip into one continuous 300-by-38 rail and extends it around five sockets. Each shape unites a 20-unit-radius circle with the bar below it, leaving a 13.7-unit-radius circular opening transparent. Distance to this shape's outer boundary selects the native border's original color and alpha rows, with no compressed bevel or opaque replacement stroke. The horizontal boundary starts at rail coordinate 33.5, matching source row 30 in the four-pixels-per-unit native composition with its 26-unit offset. Straight feet and gaps retain the same native rows directly, rather than being drawn as separate pieces. The bottom four image rows blend into the original lower background's row mapping. Bar material fills the inside of each bend, without a separate inner or lower curved line.

`media/tex/jewelry/SocketRail.blp` is a 2048-by-256 uncompressed BLP2 Raw3 canvas, preserving the original RGBA pixels. Its upper-left 1200-by-152 rectangle contains the complete rail, prepared at four pixels per UI unit for a nominal 300-by-38 display; the remaining pixels are clear. Runtime UVs are `0`, `1200 / 2048`, `0`, `152 / 256`. One bar-owned texture spans from six units outside each side of the bar, with its top 40 units above the button tops and bottom two units above them. The sockets and straight spans therefore share one sampling rectangle and anchor space. The existing bar backgrounds draw below the narrow replacement strip. The complete original backgrounds return when jewelry is unavailable or hidden. All seven button positions and button artwork are unchanged.

The prepared jewelry BLP files ship through the runtime manifest. TGA preparation inputs, original source BLPs, sample item icons and previews are excluded. Static image preparation does not establish packaged-client rendering; runtime appearance remains unverified.

## Detached silver outline

The same preparation script also writes `media/tex/jewelry/SocketDetached.tga`, an uncompressed 256-by-256 RGBA canvas with a 160-by-160 occupied rectangle at its upper-left. A complete 20-unit-radius circle uses the same native border profile and 13.7-unit-radius transparent opening as the attached sockets. There are no feet or horizontal bar spans. Each of the five detached slots reuses this crop at 40 by 40 units at the native button reference. The gray texture sits behind the unchanged item icon and gold rim, preserving the silver-gray outline around the entire circle. The rail is restored to the original bar artwork while detached; neither the original action-bar source nor item artwork is modified. The prepared `SocketDetached.blp` is included in the shared runtime manifest; its TGA remains a preparation input. Exact palette packing preserves its full canvas and alpha.

## Original WoW empty-slot pictures

The user selected proposal **01 — Original WoW**, with the full pictures visible inside the circular jewelry openings. The necklace, ring and trinket reuse Blizzard’s painted inventory placeholders rather than the former generated geometric silhouettes.

- Source mirror: [Gethe/wow-ui-textures, commit e80e3278cc833c89e1f3fc79557b68315d750935](https://github.com/Gethe/wow-ui-textures/tree/e80e3278cc833c89e1f3fc79557b68315d750935), early Dragonflight **10.0.0 build 45454**. These are inherited WoW inventory pictures, not artwork exclusive to that expansion.
- Each original is a 64-by-64 RGBA PNG: [PaperDoll/UI-PaperDoll-Slot-Finger.PNG](https://github.com/Gethe/wow-ui-textures/blob/e80e3278cc833c89e1f3fc79557b68315d750935/PaperDoll/UI-PaperDoll-Slot-Finger.PNG), [UI-PaperDoll-Slot-Neck.PNG](https://github.com/Gethe/wow-ui-textures/blob/e80e3278cc833c89e1f3fc79557b68315d750935/PaperDoll/UI-PaperDoll-Slot-Neck.PNG) and [UI-PaperDoll-Slot-Trinket.PNG](https://github.com/Gethe/wow-ui-textures/blob/e80e3278cc833c89e1f3fc79557b68315d750935/PaperDoll/UI-PaperDoll-Slot-Trinket.PNG).
- Original downloaded bytes are retained under `third_party/sources/jewelry/`, outside the runtime manifest. Blizzard owns the artwork; the mirror does not supply a separate blanket redistribution license. The existing software-license notice above does not relicense these pictures. The shipped jewelry module records the artwork pin and Blizzard ownership.

`scripts/prepare_jewelry_placeholders.py` removes only the four-pixel square frame margin, using source rectangle `(4, 4, 60, 60)`. It scales the entire 56-by-56 interior proportionally on the existing 64-by-64 placeholder canvas: rings use 54 by 54 centered at `(5, 5)`, the necklace uses 50 by 50 at `(7, 7)`, and trinkets use 40 by 40 at `(12, 12)`. Rings and the necklace nearly reach the inner gold edge while their painted shapes retain clearance; trinkets grow only slightly from the earlier 36-pixel fit. The source interior is not zoom-cropped. The original circular background alpha is retained after compositing, keeping the enlarged square ground from creating opaque outer corners. The source paint is brightened by 1.55 to match the chosen preview, without a new tint. Its dark ground is lifted to the charcoal circle where needed so no extra square frame is visible. Outer corners remain transparent.

The painted pictures receive an additional 20% brightness increase after their original preparation and resizing. A mask selects only pixels where the resized source paint already contributes above the charcoal ground; the increase cannot expose or brighten previously hidden square background pixels. Circular background pixels and alpha, gold rims and socket artwork retain their previous values.

The script writes the existing uncompressed RGBA `EmptyNeck.tga`, `EmptyRing.tga` and `EmptyTrinket.tga` preparation inputs. Run `scripts/prepare_client_textures.py` afterwards to produce their existing **BLP2 Raw3** runtime files with the required palette block. Conversion preserves all prepared pixels; TGA inputs, original PNGs, the generator and optional contact sheet stay outside the runtime manifest. No new runtime filename is needed.

The full 64-by-64 image maps to the existing 32-by-32 placeholder frame, independently of the equipped item’s 5% zoom and cropped strips. Both rings share the ring picture and both trinkets share the trinket picture. Attached and detached rows retain their original rims, dimensions and placement; no native reads, tooltip/cooldown state, layout lifecycle, setting or saved value changes. Only static artwork preparation and previews were performed; game-side rendering remains unverified.

The following historical static preview shows the original placeholder preparation with the former gold rim. That extra rim is no longer drawn by jewelry; the current Runecarver-only preview is above. It is artwork evidence, not an in-game capture. The preview is outside the runtime manifest.

![Prepared empty jewelry artwork inside the original gold rims](../docs/previews/jewelry-empty-slots.png)
