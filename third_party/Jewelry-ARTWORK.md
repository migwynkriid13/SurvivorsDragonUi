# Equipped jewelry artwork

The user's simplified design retains only each equipped item icon and its gold circular rim. Space around and between the circles is transparent. The panel, permanent title, dark socket fill, stone, filigree and enclosing border are removed. Native item icons are read at runtime rather than bundled into this artwork.

## Gold rim source

- [Karl-HeinzSchneider/WoW-DragonflightUI, commit b8b35451d4621a8097e887385f72ec03e17765f1](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/tree/b8b35451d4621a8097e887385f72ec03e17765f1).
- Original file: [`Textures/bagborder2.blp`](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/b8b35451d4621a8097e887385f72ec03e17765f1/Textures/bagborder2.blp), 64-by-64 RGBA, preserving source colors and alpha.
- [MIT notice](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/b8b35451d4621a8097e887385f72ec03e17765f1/LICENSE), copyright 2022 Karl-HeinzSchneider. The relevant notice is retained in shipped `modules/ui/jewelry.lua` comments.

Original World of Warcraft artwork remains copyright Blizzard Entertainment. The source addon's software license does not transfer ownership of Blizzard artwork. The project owner has confirmed upstream custom texture redistribution permission; this does not change Blizzard ownership. No upstream Lua or fonts are imported. The previously used stone, filigree and timer trim are absent from the current jewelry texture.

## Preparation and transparency

`scripts/prepare_jewelry_art.py` reads `bagborder2.blp` from a scratch directory supplied with `--sources`. Pillow decodes the image, with a BGRA decoder for uncompressed BLP2 encoding 3 when needed. This tool prepares image assets without loading or executing addon code.

`media/tex/jewelry/Frame.tga` contains five gold rims on a transparent 1024-by-256, uncompressed 32-bit TGA canvas. The runtime reuses the first rim's pixel rectangle `(98, 50)` through `(184, 136)` independently for all five sockets, with UV bounds `98 / 1024`, `184 / 1024`, `50 / 256`, `136 / 256`. Each crop occupies 43 by 43 local units. The default frame scale is the native action-button width divided by 43, giving each rim the same outer diameter as a button. Independent placement matches action-button center spacing and spans buttons 2 through 6; it does not stretch the baked five-rim row.

Native item textures have nominal local size 32 by 32, centered in each rim at local vertical center 46.5. Horizontal pitch is `(button width + button gap) / default jewelry scale`, centered in the existing 317-by-88 anchor frame. Each icon uses 14 nonempty horizontal texture strips from a 16-strip circle partition. Strip widths use the narrower circular boundary at their two edges, so no texture extends beyond the circle. Matching UV crops preserve the source image's proportions. Texture strips are pooled at initialization and change images only when the native item texture changes. This leaves real transparency outside the icon, without opaque black corner covers or a retail mask API.

`media/tex/jewelry/Cooldown.tga` is original generated geometry: an 8-by-8 atlas of 64 circular shade states, each 64 by 64 pixels on a transparent 512-by-512 canvas. State zero is clear, and states 1–63 cover increasing clockwise fractions of the circle, with transparent cell padding. The runtime selects a state from native inventory cooldown values and the native `GetTime` clock; it does not advance a private gameplay timer. The shade remains inside the icon circle, under its gold rim.

Only the two used TGA files ship through the runtime manifest. Source BLPs, sample item icons and previews are excluded. Static image preparation does not establish packaged-client rendering; runtime appearance remains unverified.
