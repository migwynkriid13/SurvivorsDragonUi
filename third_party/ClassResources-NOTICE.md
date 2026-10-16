# Class-resource artwork

The underlying World of Warcraft artwork belongs to Blizzard Entertainment. Neither the source repositories nor this conversion grant a new license to Blizzard artwork. This addon bundles only texture images, with its own 1.12-compatible resource display.

## Combo points

Source: [Karl-HeinzSchneider/WoW-DragonflightUI, `Textures/Unitframe/classoverlaycombopoints.blp`](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/b8b35451d4621a8097e887385f72ec03e17765f1/Textures/Unitframe/classoverlaycombopoints.blp).

Coordinate reference: [`Modules/Unitframe/Target.mixin.lua`](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/b8b35451d4621a8097e887385f72ec03e17765f1/Modules/Unitframe/Target.mixin.lua#L1116-L1144).

The original 128-by-128 raw BGRA BLP2 is converted to `media/tex/resources/ComboPoints.tga`, an uncompressed 32-bit RGBA TGA preserving its pixels and alpha. The selected socket and red-orb regions use the original 20-by-20 pixel bounds; UVs below use exact pixel fractions instead of rounded decimal fractions.

| State        | Pixel bounds, left/top/right/bottom | UV left/right/top/bottom      |
| ------------ | ----------------------------------- | ----------------------------- |
| Empty socket | `29,66,49,86`                       | `29/128,49/128,66/128,86/128` |
| Red orb      | `29,44,49,64`                       | `29/128,49/128,44/128,64/128` |

## Soul shards

Source: [Gethe/wow-ui-textures, `PLAYERFRAME/ClassOverlayWarlockShards725.PNG`](https://github.com/Gethe/wow-ui-textures/blob/d23deaf8f44a7d280dc974a5c9d5321c013db59b/PLAYERFRAME/ClassOverlayWarlockShards725.PNG).

Coordinate reference: [Ketho/BlizzardInterfaceResources, `Resources/AtlasInfo.lua`](https://github.com/Ketho/BlizzardInterfaceResources/blob/36dd01db2d8fa5086dffda5cbfb3d55f4a70e526/Resources/AtlasInfo.lua#L15263-L15269), extracted Blizzard client atlas data for `interface/playerframe/classoverlaywarlockshards725`, FileDataID `1634969`.

The [mirrored Blizzard `ShardBar.xml`](https://github.com/Gethe/wow-ui-source/blob/fe3a9d7991a529fb826a400d562e3964ef785a15/FrameXML/ShardBar.xml) uses the named shard atlas entries. The numerical coordinates come from the atlas-data reference above, rather than from that XML.

The original 256-by-64 RGBA PNG is converted to `media/tex/resources/SoulShards.tga`, an uncompressed 32-bit RGBA TGA preserving its pixels and alpha. Each selected region is 17 by 22 pixels.

| Native atlas name    | Pixel bounds, left/top/right/bottom | UV left/right/top/bottom    |
| -------------------- | ----------------------------------- | --------------------------- |
| `Warlock-EmptyShard` | `1,38,18,60`                        | `1/256,18/256,38/64,60/64`  |
| `Warlock-ReadyShard` | `23,25,40,47`                       | `23/256,40/256,25/64,47/64` |

## Upstream MIT notice

The combo artwork reference/coordinate adaptation retains the source repository's notice here and in the shipped `modules/unit/resources.lua` comments. The source code license does not relicense the underlying Blizzard artwork.

```text
MIT License

Copyright (c) 2022 Karl-HeinzSchneider

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
