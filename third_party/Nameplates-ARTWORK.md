# Dragonflight nameplate artwork

World of Warcraft artwork © Blizzard Entertainment, Inc. The PNG sources are
Blizzard client exports mirrored by Gethe. The export and the local conversion
do not establish a separate license for Blizzard artwork.

Both source images are pinned to [Dragonflight 10.0.0 build 45454][build].
Blizzard's [10.0 FrameXML][frame] assigns the health bar texture, dark backdrop
and left-hand classification seat. Its [classification code][classification]
uses `nameplates-icon-elite-gold` for elite and world-boss units.

| Runtime asset                                  | Source and preparation                                                                                                                                                                                                                            |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `media/tex/nameplates/DragonflightBarFill.blp` | [`TARGETINGFRAME/UI-TargetingFrame-BarFill.PNG`][bar], 512 × 64. Preserve the full grayscale fill and all source pixels.                                                                                                                          |
| `media/tex/nameplates/DragonflightElite.blp`   | [`TARGETINGFRAME/Nameplates.PNG`][atlas], 256 × 128. Crop the gold dragon at x 0–39 and y 29–65, inclusive. Copy the 40 × 37 crop at (1, 1) on a transparent 64 × 64 canvas. The runtime draws the upper-left 42 × 39 with its one-pixel padding. |

The runtime BLP files use the project's `blp_from_bgra` and `lossless_palette`
encoders in `scripts/prepare_client_textures.py`. The renderer clips the fill
and supplies the reaction tint, dark backdrop and one-unit border. The 100 × 7
outer bar and 14 × 13 badge use local dimensions chosen to match the supplied
reference proportions.

DragonUI's [retail nameplate notes][dragonui] describe a separate repack. The
artwork above comes from the pinned 10.0 client sheets. The original Kui
renderer attribution and GPL text are retained in [the Kui notice][kui].

[build]: https://github.com/Gethe/wow-ui-textures/commit/e80e3278cc833c89e1f3fc79557b68315d750935
[frame]: https://github.com/Gethe/wow-ui-source/blob/28ab53f48c691a976daa33acb509e96d9b850503/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlates.xml#L146
[classification]: https://github.com/Gethe/wow-ui-source/blob/28ab53f48c691a976daa33acb509e96d9b850503/Interface/FrameXML/CompactUnitFrame.lua#L1164
[bar]: https://github.com/Gethe/wow-ui-textures/blob/e80e3278cc833c89e1f3fc79557b68315d750935/TARGETINGFRAME/UI-TargetingFrame-BarFill.PNG
[atlas]: https://github.com/Gethe/wow-ui-textures/blob/e80e3278cc833c89e1f3fc79557b68315d750935/TARGETINGFRAME/Nameplates.PNG
[dragonui]: https://github.com/NeticSoul/DragonUI/blob/407dd0069f2b853388483e9e7e169198abf4c6d0/DragonUI/THIRD_PARTY_NOTICES.md#retail-nameplate-artwork
[kui]: Kui-Nameplates-NOTICE.txt
