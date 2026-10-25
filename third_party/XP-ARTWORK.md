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

`media/tex/actionbars/Gryphon.tga` replaces the previous wyvern ornament.
It contains Blizzard's Dragonflight gryphon artwork, obtained from
[s0h2x/pretty_actionbar's `assets/uiactionbar2x_new.blp`](https://github.com/s0h2x/pretty_actionbar/blob/f60a50a040e77751011c5afe7a51cd9df888e127/assets/uiactionbar2x_new.blp),
commit `f60a50a040e77751011c5afe7a51cd9df888e127` (1.0.3, 2022-10-30).
The source BLP's Git blob is `a8c965a45cbf2486a26bec8d51353a8c19946cf9`.
This uses artwork only; no source addon code or dependencies are imported.
Original World of Warcraft artwork remains Blizzard Entertainment's property;
availability in a public addon does not transfer ownership.

The 512-by-2048 BLP2 sheet uses uncompressed BGRA pixels. The source
[`ui-hud-actionbar-gryphon-thick-left` metadata](https://github.com/s0h2x/pretty_actionbar/blob/f60a50a040e77751011c5afe7a51cd9df888e127/utils/atlas.lua)
selects `[1, 209, 357, 543)`, a 356-by-334 atlas member. Its visible bounds
are `[39, 10, 351, 316)` within that member. The prepared texture decodes
BGRA to RGBA, takes sheet pixels `[40, 219, 352, 525)` unchanged, and places
that 312-by-306 crop at the top left of a transparent 512-by-512,
uncompressed 32-bit TGA. Pixels, colors and alpha are not resampled or
recolored. Only this selected gryphon is packaged; the right side mirrors it.

Dragonflight's
[`MainMenuBar.xml`, 10.0.2 build 47213](https://github.com/Gethe/wow-ui-source/blob/3601b934bca4a9cdf815fd483586a0e5608909ad/Interface/FrameXML/MainMenuBar.xml)
defines gryphon end caps at 104.5 by 98 units, bottom-aligned 22 units below
the bar. The runtime preserves those proportions after trimming: width is
`104.5 * 312 / 356`, height is `98 * 306 / 334`, and the bottom is
`-22 + 98 * 18 / 334`. Before trimming, each cap overlaps its bar end by
14 units; the trimmed horizontal anchor is `14 - 104.5 * 5 / 356`.
This tucks the chest into the shorter bar's side trim and leaves native
button frames in front. UVs select only `0..312/512, 0..306/512` of the TGA.

The existing default-off setting still creates two passive texture regions
only on first enable, binds/crops each once and changes visibility only when
the setting changes. The shared edit bounds include the trimmed visible
extents alongside jewelry, XP and tally, without moving the bar owner or
adding an updater. A static artwork comparison informed the fit; in-game
appearance remains unverified.
