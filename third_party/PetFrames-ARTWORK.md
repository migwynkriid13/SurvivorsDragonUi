# Pet-frame artwork

The user requested regular frames from an existing addon through `$assetlook`,
rather than freshly drawn artwork. The selected pair is the published pet
frame used by DragonUI. Its underlying World of Warcraft art is copyright
Blizzard Entertainment, included for use with the game. Conversion does not
transfer ownership or put Blizzard artwork under an MIT software license.

## Selected published files

Repository: [NeticSoul/DragonUI](https://github.com/NeticSoul/DragonUI), resolved
`main` commit `0b6439e402cdf5c488f515bb93431bc18403e4cf`.

| Published file under `DragonUI/Textures/UnitFrames/` | Original | Shipped copy |
| --- | --- | --- |
| [HD/TargetofTarget-BACKGROUND.blp](https://github.com/NeticSoul/DragonUI/blob/0b6439e402cdf5c488f515bb93431bc18403e4cf/DragonUI/Textures/UnitFrames/HD/TargetofTarget-BACKGROUND.blp) | 256×128, uncompressed BGRA BLP2 | `media/tex/pets/Background.tga` |
| [HD/TargetofTarget-BORDER.blp](https://github.com/NeticSoul/DragonUI/blob/0b6439e402cdf5c488f515bb93431bc18403e4cf/DragonUI/Textures/UnitFrames/HD/TargetofTarget-BORDER.blp) | 256×128, uncompressed BGRA BLP2 | `media/tex/pets/Border.tga` |

The [pet module](https://github.com/NeticSoul/DragonUI/blob/0b6439e402cdf5c488f515bb93431bc18403e4cf/DragonUI/modules/unitframes/pet.lua)
uses the shared small-frame skin, a 34-unit portrait and separate name/health/
power regions. The [skin table](https://github.com/NeticSoul/DragonUI/blob/0b6439e402cdf5c488f515bb93431bc18403e4cf/DragonUI/modules/unitframes/uf_skins.lua)
selects these HD pieces at 128×64. This is the same published portrait/bar
family used for pets and target-of-target, rather than a guessed pet atlas.

`scripts/prepare_pet_art.py --sources SOURCE_DIRECTORY` reads downloaded copies
named `Background.blp` and `Border.blp`, decodes the first BGRA mip and writes
uncompressed RGBA TGA with identical pixels, dimensions and alpha. No crop,
repainting, recoloring or resampling is applied to shipped artwork. Runtime
draws the complete `[0,1]` UV region at 128×64: background below icons/fill,
border above them, ordinary BLEND and unchanged white vertex color.

The icon opening is centered at `(24.5, 22.5)`, with a 34-unit native icon
assembled from fixed horizontal cropped strips. Text uses DEFAULT; no portrait
model, mask API, glow state or source-addon framework is imported. The lower
well's duration fill reuses the already bundled
`unitframes/UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana` at `(40.5, -28)`,
74×7.5, clipping width/UVs together. This blue native mana texture is repurposed
only to show the supplied remaining lifetime. The upper well is text-only.

## Attribution and upstream

DragonUI's [third-party notices](https://github.com/NeticSoul/DragonUI/blob/0b6439e402cdf5c488f515bb93431bc18403e4cf/DragonUI/THIRD_PARTY_NOTICES.md)
identify `HD/` as DragonflightUI's `Unitframe2x` artwork recut into background
and border pieces. They credit Karl-Heinz Schneider and explicitly distinguish
the Blizzard artwork from the conduits' MIT software. DragonUI's
[license](https://github.com/NeticSoul/DragonUI/blob/0b6439e402cdf5c488f515bb93431bc18403e4cf/DragonUI/LICENSE.txt)
contains the same distinction. Its
[upstream MIT notice](https://github.com/NeticSoul/DragonUI/blob/0b6439e402cdf5c488f515bb93431bc18403e4cf/DragonUI/LICENSES/MIT-DragonflightUI.txt)
is retained alongside DragonUI's notice in the shipped module.

The upstream [DragonflightUI pet code](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/f59cbc3f7010ef692fb983c7c3c848c4b70f56ce/Modules/Unitframe/Pet.mixin.lua)
was inspected at `f59cbc3f7010ef692fb983c7c3c848c4b70f56ce`; it also delegates pet
appearance to the small target-of-target frame family. The already bundled
128×64 `pet.blp` was inspected as the existing lower-resolution alternative.
PentSec/DragonUI resolves to `5aefa049d22ba1a9e968b433d96eed7be86d6ac9`; the
selected pair comes from the explicitly pinned NeticSoul version above.

Wider retail research checked Gethe/wow-ui-source at
`b9be9379719047977fca4dba1bb1d9988e8840b3`, whose `version.txt` says
`12.1.5.70448`. Its [PetFrame.xml](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_UnitFrame/Mainline/PetFrame.xml)
still uses `UI-HUD-UnitFrame-TargetofTarget-PortraitOn` for the pet frame.
That current retail source is evidence of family reuse, not a claim that it is
a Dragonflight build or that its mask APIs work in this legacy client.
The current Gethe/wow-ui-textures recursive tree was truncated; targeted root
and TARGETINGFRAME queries did not locate a separate modern pet atlas. No
missing atlas coordinates were guessed. The published legacy-ready DragonUI
pieces provide the usable selected source.

Only the two TGA pieces and their consuming Lua module enter the runtime
manifest/TOC. Downloaded originals, preview icons, previews and the conversion
script stay outside the runtime package. Static previews establish artwork
assembly only; no addon/game execution or local code checks were performed.
