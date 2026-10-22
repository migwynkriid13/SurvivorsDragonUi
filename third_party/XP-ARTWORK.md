# Joined XP artwork

The joined XP shell reuses the bundled 512×128 RGBA
`media/tex/actionbars/HDActionBar.tga`. Its SHA-256 is
`94e892425bd9010fb3813a6e6b87323d6ec86ccfe52c1cf06c8ec9935e1096f3`;
its bytes match these pinned sources:

- [alchem1ster/DragonflightReloaded, 49f20659cefcf621abd89fabb67f906b62ec7523](https://github.com/alchem1ster/DragonflightReloaded/blob/49f20659cefcf621abd89fabb67f906b62ec7523/media/tex/actionbars/HDActionBar.tga).
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
