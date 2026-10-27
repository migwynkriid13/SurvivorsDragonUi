# Details! The War Within meter artwork

The meter reuses Karl-HeinzSchneider's original **Details! Skin 'The War Within'**
artwork under its MIT license. Source repository:
[WoW-Details-Skin-TheWarWithin](https://github.com/Karl-HeinzSchneider/WoW-Details-Skin-TheWarWithin),
pinned commit `45264df190af6d5a39ba61cb88f267c873ab2ae5`.
The source README credits the design's inspiration to `/u/Sm0keO`.

The unchanged copyright and full MIT terms ship in
`media/tex/meter/LICENSE.txt`, alongside the runtime artwork. The repository's
original addon code, bundled libraries, default-profile import, fonts, coffee
image, class/spec sheets and augmentation artwork are not imported.

## Selected sources

All three source images have a 256-by-32 canvas, sampled with full UVs.

| Source at the pinned commit | Original file SHA-256                                              | Runtime path                     |
| --------------------------- | ------------------------------------------------------------------ | -------------------------------- |
| `Textures/header.blp`       | `529027aff4e358e822907c028b52248adf0487abe8658dfccbe4c52c37ddaed7` | `media/tex/meter/Header.blp`     |
| `Textures/bar.blp`          | `eba12d2b6215e3efeb056b91fa6c708c9671399cd3fdeda6a0842654c21c0c83` | `media/tex/meter/Bar.blp`        |
| `Textures/background.blp`   | `6fd49a9c55bf833f49956497b5789ac260dd6059ed54a178343eed85ae594f7a` | `media/tex/meter/Background.blp` |

The source skin's `Core.lua` selects a 32-unit title bar, 28-unit rows with a
four-unit gap, Friz Quadrata text, class-colored fills and these three textures.
The SDUI renderer retains the 32-unit header and row step, drawing native
per-source labels above the textured rails. It uses the resolved game DEFAULT
font and shared class palette, with the game's explicit proc tint. It does not
pretend that retail Details class/spec portraits identify these native sources.
Source icons instead use the existing jewelry atlas's prepared gold ring and
native circular rendering, with a clipped fallback for older clients; see
[Jewelry-ARTWORK.md](Jewelry-ARTWORK.md). No additional image is imported or
regenerated for those rings.

## Preparation

Decode the first mip of each pinned source BLP with Pillow, convert to RGBA and
save as an uncompressed TGA of the same canvas under `media/tex/meter/` with the
runtime stem. Do not resize, crop, redraw, recolor or discard alpha. The checked-in
TGAs are these full-resolution preparation inputs; they stay outside the runtime
manifest. Decoded RGBA SHA-256 values:

| Input            | Decoded RGBA SHA-256                                               |
| ---------------- | ------------------------------------------------------------------ |
| `Header.tga`     | `4bb2ee17261c5c39fee756ee81564cdc5a8fcd1bcc1de0e36fc7efa9ec9d69ed` |
| `Bar.tga`        | `ab642be42e60cae5bd0381d276628ead440c05d2c749db3c996642b88285db38` |
| `Background.tga` | `b2a94f8fde2559cb2ede6c17d08b31b35dc671bf9712c8c7b7f08149d5dc87eb` |

Run `python3 scripts/prepare_client_textures.py` after regenerating the TGAs. The
converter writes lossless BLP2 Raw1 when one exact RGB palette fits all pixels,
with alpha retained separately; otherwise it keeps Raw3. Both encodings include
the required palette block. The bar now uses Raw1; header and background remain
Raw3. Native and browser clients receive the same prepared files.
Container conversion preserves every decoded pixel and the full original UVs;
it does not undo compression already present in the author's source BLP.

The runtime manifest adds only the three prepared images, their MIT notice and
`modules/ui/meter.lua`. The module obtains all artwork through the addon's shared
asset root. See [DAMAGE-METER.md](../docs/DAMAGE-METER.md) for data and lifecycle
boundaries. No in-game appearance or compatibility claim follows from inspecting
the source artwork.

## Native healing source icons

The shared source metadata also references native general-jewelry/amulet icons,
including Hakkar's `INV_Jewelry_Necklace_22`. These paths are independently
extracted from the installed game and shared with SCT; public addons supply
research evidence only. No public Lua implementation or icon bitmap was copied.
See [SOURCE-ICONS.md](../docs/SOURCE-ICONS.md).

The healing meter references the installed client’s original Blizzard icons by native `Interface\\Icons` paths: `Spell_Nature_Rejuvenation`, `Spell_Shadow_LifeDrain02`, `Spell_Shadow_DeathPact`, `Spell_Holy_HolyBolt` and `Spell_Shadow_GatherShadows`. These are separate from the skin author’s MIT-licensed header/bar/background artwork; no icon bitmap is copied into the addon. The exact native producer pairs, executable fingerprint and data-only extraction are recorded in [DAMAGE-METER.md](../docs/DAMAGE-METER.md#native-healing-icons). The existing gold ring and circular renderer are reused.
