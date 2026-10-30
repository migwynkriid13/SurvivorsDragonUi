# Bildad Heroic numerals

The user selected [Bildad from FontGet](https://www.fontget.com/font/bildad/)
for the run timer's Heroic numerals. The downloaded archive's `LICENSE.md` says
the font is free for personal use and requires FontGet.com credit when
distributed. Its exact notice and font copyright are retained in
[`media/tex/timer/LICENSE.txt`](../media/tex/timer/LICENSE.txt).
This personal-use artwork needs appropriate licensing before commercial use.

Only the I, V and X glyphs are rasterized, forming I, II, III, IV, V, VI, VII,
VIII, IX and X. The original TTF is neither installed nor retained in the addon.
The source font SHA-256 is
`a35066a71965582df52571d5cd679cdcf416179c15f6dbfe83f7c76abc905929`.

`scripts/prepare_heroic_numerals.py` fetches the public archive in memory and
requires that exact source hash. It renders white glyphs at 66 source pixels
with a three-pixel black outline, preserving transparent backgrounds. Ten
128-by-64 cells occupy the first ten slots of a 512-by-256 atlas in row order.
The remaining six slots stay transparent. At runtime each cell is 32 by 16
units, and vertex tint supplies the Heroic palette without extra images.

`media/tex/timer/HeroicNumerals.tga` is the retained lossless authoring image.
The existing `prepare_client_textures.save_image` writer produces the lossless
paletted BLP with eight-bit alpha in `HeroicNumerals.blp`; only that BLP and the
license notice enter the runtime package. The recipe and
[`heroic-numerals-art.json`](heroic-numerals-art.json) record source, layout and
output hashes. Preparation runs image code only; it does not execute the addon
or game. No downloaded archive or font file is retained.
