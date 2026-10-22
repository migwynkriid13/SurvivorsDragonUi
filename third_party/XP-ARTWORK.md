# Joined XP artwork

The user selected **01 — Continuous lower rail** from the
[static comparison](../docs/designs/xp-attachment/comparison.png). The original
action-bar walls continue around XP, with one lower bevel and no separate XP
end caps. The purple fill profile, native gain spark and jewelry rail are reused.
The fill's overall fading is reduced by 30% as described in
[XPBar-ANIMATION.md](XPBar-ANIMATION.md), retaining its slightly rounded ends.

## Selected source

The bundled `media/tex/actionbars/HDActionBar.tga` is a 512-by-128 RGBA half-shell.
Its bytes match both inspected sources, SHA-256
`94e892425bd9010fb3813a6e6b87323d6ec86ccfe52c1cf06c8ec9935e1096f3`:

- [alchem1ster/DragonflightReloaded, commit 49f20659cefcf621abd89fabb67f906b62ec7523](https://github.com/alchem1ster/DragonflightReloaded/blob/49f20659cefcf621abd89fabb67f906b62ec7523/media/tex/actionbars/HDActionBar.tga).
- [Stormhand-dev/DragonflightUI-Reforged, commit 2a8d2ffb3d9262f0d2af2071b9b47ef27f76f7f8](https://github.com/Stormhand-dev/DragonflightUI-Reforged/blob/2a8d2ffb3d9262f0d2af2071b9b47ef27f76f7f8/media/tex/actionbars/HDActionBar.tga).

This is existing Reloaded-family artwork, not a newly verified
expansion-exclusive texture. Existing source notices remain intact. The owner
has confirmed redistribution permission for upstream custom textures. Original
World of Warcraft artwork remains copyright Blizzard Entertainment; public
mirrors and software licenses do not transfer its ownership. No source-addon
Lua, framework or font is imported.

## Preparation and runtime assembly

`scripts/prepare_xp_art.py` reads only the bundled texture. It preserves rows
0–91, inserts sixteen copies of row 91 before the lower chamfers, then copies
rows 92–127 unchanged. The result is 512-by-144 content in a transparent,
uncompressed 32-bit 512-by-256 TGA, `media/tex/actionbars/HDActionBarXP.tga`.
Preparation does not recolor, redraw or resample the source.

At the existing 36-unit button reference, each original half displays at
150 by 64 units. Joined halves display at 150 by 72, with vertical UVs
0 through 144/256; the right half reverses horizontal UVs. This preserves
pixel density and extends the straight walls eight units before their original
lower corners and bevel. The two existing bar-owned background regions switch
to this source while joined XP is available.

Jewelry's top cut still removes twelve units at the reference size; its crop
uses the active shell height and occupied UV span. The original top returns
when jewelry is detached. XP's old border regions appear only when detached.
The fill sits three units below the button bottoms, inset nine units from
each artwork edge, above the lower bevel. Normal blending and purple tint stay.

The selected shell TGA is the only attachment-specific texture in the runtime
manifest. The prepared softened fill separately replaces its original source
in the ZIP. Original source textures remain unchanged in the repository;
generators, research files and previews remain outside the ZIP.

## Other inspected candidates

- [NeticSoul/DragonUI XP sheet](https://github.com/NeticSoul/DragonUI/blob/0b6439e402cdf5c488f515bb93431bc18403e4cf/DragonUI/Textures/XP/uiexperiencebar.blp): 2048-by-64 BGRA BLP2. Its [owner](https://github.com/NeticSoul/DragonUI/blob/0b6439e402cdf5c488f515bb93431bc18403e4cf/DragonUI/modules/mainbars.lua) selects border rectangle `[1, 1, 572, 18)`. Its separate 2048-by-32 `Overlay.tga` has segment marks. Both have independent end caps, so neither was imported.
- [s0h2x/pretty_actionbar](https://github.com/s0h2x/pretty_actionbar/blob/f60a50a040e77751011c5afe7a51cd9df888e127/assets/uiexperiencebar.blp): 2048-by-64 sheet. Its [owner](https://github.com/s0h2x/pretty_actionbar/blob/f60a50a040e77751011c5afe7a51cd9df888e127/modules/mainbars.lua) applies XP atlas regions to a separately positioned bar. The complete sheet was inspected, not treated as an isolated widget.
- [Karl-HeinzSchneider/WoW-DragonflightUI](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/f59cbc3f7010ef692fb983c7c3c848c4b70f56ce/Textures/uiexperiencebar2x.blp): 2048-by-256 sheet with colored fills and segmented trim, inspected as a full sheet. [DustinChecketts/Turtle-Dragonflight's left XP frame](https://github.com/DustinChecketts/Turtle-Dragonflight/blob/b2c62e9095e1c859bff0209db09f4ff5b9884f5a/img/XP/leftFrame.tga) is a 512-by-32 separate end-cap texture.

[DragonUI's notices](https://github.com/NeticSoul/DragonUI/blob/0b6439e402cdf5c488f515bb93431bc18403e4cf/DragonUI/THIRD_PARTY_NOTICES.md)
trace XP artwork through DragonflightUI, Pretty Actionbar and RetailUI and
exclude Blizzard artwork from the software MIT license.

## Retail source comparison

The inspected Blizzard source uses `UI-HUD-ExperienceBar-Background` and a
separate `UI-HUD-ExperienceBar-Frame` in these versions:

- [Dragonflight 10.2.7, commit 6b65c2922baca3db5a28fb39b69c95cef1047bec](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_ActionBar/Mainline/StatusTrackingBarTemplate.xml).
- [The War Within 11.2.7, commit 0b78d65dac26c34898ffc19134f224de2ef0f885](https://github.com/Gethe/wow-ui-source/blob/0b78d65dac26c34898ffc19134f224de2ef0f885/Interface/AddOns/Blizzard_ActionBar/Mainline/StatusTrackingBarTemplate.xml).
- [Midnight 12.1.5, commit b9be9379719047977fca4dba1bb1d9988e8840b3](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_ActionBar/Mainline/StatusTrackingBar.xml), whose `version.txt` reports 12.1.5.70448.

These establish a separate retail-frame pattern, not a native connected-XP
widget. The texture mirror's `live` branch still resolves to older 9.2.7 and
its recursive tree is truncated; it was not treated as current retail artwork.
The selected design requires no retail atlas, mask or new runtime download.
Static previews establish source appearance only; game rendering is unverified.
