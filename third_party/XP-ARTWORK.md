# Joined XP artwork

The joined XP shell reuses the bundled 512×128 RGBA
`media/tex/actionbars/HDActionBar.tga`. Its SHA-256 is
`94e892425bd9010fb3813a6e6b87323d6ec86ccfe52c1cf06c8ec9935e1096f3`;
its bytes match these pinned sources:

- [alchem1ster's source repository, 49f20659cefcf621abd89fabb67f906b62ec7523](https://api.github.com/repositories/1001127409/contents/media/tex/actionbars/HDActionBar.tga?ref=49f20659cefcf621abd89fabb67f906b62ec7523).
- [Stormhand-dev/DragonflightUI-Reforged, 2a8d2ffb3d9262f0d2af2071b9b47ef27f76f7f8](https://github.com/Stormhand-dev/DragonflightUI-Reforged/blob/2a8d2ffb3d9262f0d2af2071b9b47ef27f76f7f8/media/tex/actionbars/HDActionBar.tga).

Existing source notices remain intact. The owner confirmed redistribution
permission for upstream custom textures. Original World of Warcraft artwork
remains copyright Blizzard Entertainment; public mirrors and software licenses
do not transfer its ownership.

The prepared `HDActionBarXP.tga` preserves rows 0–91, inserts sixteen copies
of row 91, then copies rows 92–127 unchanged. Its 512×144 content occupies a
transparent 512×256 uncompressed 32-bit TGA. No original pixels are recolored
or resampled. At the 36-unit button reference, each half displays at 150×72
units with vertical UVs `0,144/256`; the right half mirrors horizontal UVs.
This extends the walls eight units and retains the original lower bevel and
sixteen transparent source rows below it.

The purple fill and native gain spark retain their original source credits
and preparation in [XPBar-ANIMATION.md](XPBar-ANIMATION.md).

## Optional action-bar ornaments

`media/tex/actionbars/Wyvern.tga` is an unchanged rename of the selected
[original ornament file](https://api.github.com/repositories/1040377421/contents/media/tex/actionbars/WyvernNew.tga?ref=5c6a63fda03fe9b8fd8219e6c1f65c574679077a)
from dbtdsilva's source repository, pinned to commit
`5c6a63fda03fe9b8fd8219e6c1f65c574679077a`. Its Git blob is
`7ffda45b7da232e968f972ff472947945725862c`, matching the retained source
file. The unused alternate gryphon image is removed.

The original 512-by-512 RGBA canvas is displayed at 180 by 180 units,
anchored 45 units inside each action-bar end and 10 units above its center,
matching the pinned source placement. Only the right texture is mirrored.
Nontransparent source bounds are `[110, 93, 388, 405)`; edit bounds include
these visible extents rather than the transparent canvas padding. The
file's colors, alpha and pixels are unchanged, and no faction selection or
additional texture variant is used. The original artwork ownership and
redistribution notice above remains applicable.
