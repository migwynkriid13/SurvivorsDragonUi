# Heroic affix icon proposals

Twenty-one numbered proposals show Bolstering, Sanguine and Explosive together,
centered below the same sample run timer. Sets 01–20 use different trios of real
WoW pictures, now with red outlines. Set 21 repeats 01's original transparent
symbols inside thin red circular rims. These are custom visual associations,
not a claim that Blizzard used these sets for Mythic+ affixes. The user selected
**04 Rally and rupture** pictures for the runtime affix row. On 2026-10-31,
the user selected **02 Minimap bevel** from the
[gold frame comparison](../docs/designs/heroic-affix-frames/index.html), replacing
the red circular rim with square source pictures and the existing minimap
button's gold background. The earlier proposals remain design references.

The local [gallery](../docs/designs/heroic-affixes/index.html),
[overview](../docs/designs/heroic-affixes/overview.png) and five comparison sheets
are retained in the existing ignored design-document directory. Every proposal
also has a full-size PNG and a separate transparent three-icon strip. The
gallery can switch the transparency sample to a light background. These are
static compositions with an Arial proxy for the timer font, not game captures.
All three affixes are shown to compare artwork; the eventual display should
use only the run's actual published English keys.

## Source and build

The sixty original icon PNGs are from the
[Gethe texture mirror](https://github.com/Gethe/wow-ui-textures/tree/d23deaf8f44a7d280dc974a5c9d5321c013db59b/ICONS),
pinned to commit `d23deaf8f44a7d280dc974a5c9d5321c013db59b`. Its commit message
identifies **Shadowlands 9.2.7, build 45114**. This establishes a build in which
the files exist; many are inherited older textures, and no expansion-exclusive
origin is claimed. The mirror's
[README](https://github.com/Gethe/wow-ui-textures/blob/d23deaf8f44a7d280dc974a5c9d5321c013db59b/README.md)
states that its PNG files were converted from client BLP artwork.

[affix-design-sources.json](affix-design-sources.json) records all twenty-one sets,
each exact filename, immutable raw-file URL, original byte SHA-256, canvas size
and source crop. The original bytes remain in `sources/affixes/` separately
from adapted previews. The sample skulls use that same commit's
`TARGETINGFRAME/UI-TargetingFrame-Skull.PNG`, whose separate receipt is in the
manifest. The run-bar border uses the existing prepared timer pieces and their
[published provenance](WidgetStatusBar-SOURCE.md).

The search included the curated PentSec/DragonUI tree and existing SDUI
artwork, the Gethe client texture mirror and Challenge UI families, and wider
WoW affix/icon searches. The curated tree did not supply a distinct affix-icon
family. The selected source is actual client artwork, rather than screenshots
or generated lookalikes. The GitHub connector could not return the large
recursive texture tree or binary images, so bounded public GitHub API reads
and raw-file downloads supplied those missing capabilities.

## Preparation

`scripts/preview_affix_designs.py` prepares the gallery without loading addon
Lua or starting the game. Run it with the workspace's Python/Pillow runtime.
Only originals required by the proposals are downloaded, using the immutable
commit above. Image dimensions and hashes are recorded during preparation.

Every icon first removes the four-pixel source frame margin on all sides.
The complete remaining interior retains its proportions. No proposal uses
an opaque square backing or a square border.

- **Cutout:** source black becomes alpha through inverse premultiplication.
  Alpha is multiplied by the original alpha and maximum RGB channel; RGB is
  divided by that coverage. Values below 12 become fully transparent. A
  circular eleven-pixel edge fade at the 112-pixel preparation size removes
  the cropped square's edges. This is an adapted glow/cutout treatment, not
  original source transparency or a retail mask API.
- **Round:** an antialiased circular alpha mask removes the square corners.
  RGB and native interior shading are retained.
- **Metal rim:** the unselected former gold/silver proposals reuse the existing SDUI
  pet rim, `(576, 56, 648, 128)` in `media/tex/jewelry/Frame.blp`, tinted red
  through its maximum RGB channel while retaining the authored alpha and
  highlight structure. This crop excludes the square jewelry shadows. The
  underlying source notices remain in [Jewelry-ARTWORK.md](Jewelry-ARTWORK.md).
- **Selected 04:** the original neutral jewelry crop at
  `(664,56)-(736,128)` receives the same RGB vertex multiplication as the
  existing jewelry quality-color path, with red `(237,35,38)/255`. The full
  native alpha and metal shading remain, without another silhouette outline.
- **Red outlines, sets 01–20:** the 112-pixel artwork receives five pixels of
  clear padding. Its alpha at or above 56 defines support; a nine-pixel maximum
  filter expands that support by four pixels. Subtracting the support and
  applying a 0.55-pixel antialias blur produces the outline, composed behind
  the original artwork in RGB `(237, 35, 38)` without an opaque backing.
- **Red circle, set 21:** the original transparent 01 artwork scales to 82%
  within the same clear canvas. A separate antialiased circular outline, four
  pixels thick on the 112-pixel preparation canvas, surrounds it. The inside
  and outside stay transparent wherever the original symbol has no pixels;
  no silhouette outline or metallic background is added to this variant.

The full-size transparent strips make the adaptations inspectable separately
from the sample timer. All twenty-one composed proposals and their regenerated
overview were inspected as images. Source images, the preparation script,
receipts and previews remain outside `packaging/runtime-files.json`.

## Selected 04 and runtime preparation

The selected pictures are `ICONS/Ability_Warrior_RallyingCry.PNG` for Bolstering,
`ICONS/Ability_IronMaidens_BloodRitual.PNG` for Sanguine and
`ICONS/Ability_IronMaidens_DetonationSequence.PNG` for Explosive, from the pinned
9.2.7 mirror above. These are user-selected display symbols, with no attack,
damage or mechanic ownership implied. Their original bytes and hashes remain
in the source manifest.

`scripts/prepare_affix_art.py` reads proposal 04 from the shared design list,
removes each four-pixel source margin, retains the full interior's proportions
and alpha, without applying a circle mask. It packs three 64-square cells
at x=0,64,128 on one transparent 256-by-64 canvas. Only the resulting
`media/tex/timer/Affixes.blp` joins the runtime manifest. Lossless BLP conversion
uses the existing client-format preparer, without color quantization or a
runtime mask/portrait dependency. No source image, generator, preview or
external font is shipped.

[affix-selected-art.json](affix-selected-art.json) records the exact source
crops, native atlas cells, original/final hashes and the reused minimap frame.
The background stays a separate cached image, preserving source RGB/alpha.
The run module's artwork notice retains
Blizzard ownership; no upstream addon software is copied.

### Selected 02 gold frame — 2026-10-31

The frame reuses `media/tex/minimap/LauncherBackground.blp`, already shipped for
the minimap launcher. Its unchanged 32-square source and full-resolution TGA
are documented in [MinimapGlyph-ARTWORK.md](MinimapGlyph-ARTWORK.md): Blizzard's
[`BUTTONS/UI-SquareButton-Up.PNG`](https://github.com/Gethe/wow-ui-textures/blob/e80e3278cc833c89e1f3fc79557b68315d750935/BUTTONS/UI-SquareButton-Up.PNG),
commit `e80e3278cc833c89e1f3fc79557b68315d750935`, **10.0.0 build 45454**.
This is shared Blizzard button art present in that export, not a claim of
Dragonflight-exclusive origin.

Only its complete nontransparent normal-state rectangle `(0,3)-(29,29)` is
selected, using UVs `(0,29/32,3/32,29/32)`. It is displayed at 25 by 23 units
on BACKGROUND, with a 16-square source picture on ARTWORK and five-unit gaps
between frames. The gold rails occupy source bounds `(4,5)-(27,27)`; their
center is `(15.5,16)`, while the cropped canvas center is `(14.5,16)`.
The picture therefore sits `25/29` units right of the row center with no
vertical offset. Its smaller size keeps the left and bottom rails visible,
fixing the earlier 18-square picture's overlap without changing the frame.
There is no red tint, circular mask or extra
hover/pressed texture. All three original selected picture interiors retain
their square corners. Unknown keys keep the existing native skull fallback
inside the same gold frame.

This replaces the previous rim region and retains two textures per pooled
affix. Both Performance Mode states share the static presentation, successful
binding cache and failed-binding retries. No runtime payload entry, source
image or source-addon code is added. The earlier red-circle gallery describes
the historical proposals; the selected frame and exact preparation are recorded
in the current source manifest and gold-frame design notes.

## Rights and limits

World of Warcraft artwork is copyright Blizzard Entertainment. Public hosting
does not create another artwork license; the mirror provides no separate
blanket redistribution grant for Blizzard textures. Existing ring notices do
not relicense the underlying Blizzard images. No source-addon implementation
or external font is imported into the runtime.

Only static artwork preparation and source review were performed locally;
no local tests, syntax/standalone validation, addon execution or game startup
was performed. These proposals do not prove
packaged-client rendering, hover behavior, pixel parity or rendering cost.
CI-only mocks cover the production affix view's lifecycle and work boundaries.
