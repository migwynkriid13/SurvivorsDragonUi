# Heroic affix icon proposals

Twenty-one numbered proposals show Bolstering, Sanguine and Explosive together,
centered below the same sample run timer. Sets 01–20 use different trios of real
WoW pictures, now with red outlines. Set 21 repeats 01's original transparent
symbols inside thin red circular rims. These are custom visual associations,
not a claim that Blizzard used these sets for Mythic+ affixes. No affix display
or new runtime asset is installed by this design study.

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
- **Metal rim:** the former gold/silver proposals now reuse the existing SDUI
  pet rim, `(576, 56, 648, 128)` in `media/tex/jewelry/Frame.blp`, tinted red
  through its maximum RGB channel while retaining the authored alpha and
  highlight structure. This crop excludes the square jewelry shadows. The
  underlying source notices remain in [Jewelry-ARTWORK.md](Jewelry-ARTWORK.md).
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

## Rights and limits

World of Warcraft artwork is copyright Blizzard Entertainment. Public hosting
does not create another artwork license; the mirror provides no separate
blanket redistribution grant for Blizzard textures. Existing ring notices do
not relicense the underlying Blizzard images. No source-addon implementation
or external font is imported into the runtime.

No runtime texture conversion, local tests, syntax/standalone validation,
addon execution or game startup was performed. These proposals do not prove
packaged-client rendering, hover behavior, pixel parity or rendering cost.
The selected proposal will need its own runtime preparation and lifecycle work.
