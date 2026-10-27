# Early Dragonflight cursor artwork

The cursor uses Blizzard Entertainment's original silver gauntlet from the
10.0.0 build 45454 interface texture atlas. The source mirror is
[Gethe/wow-ui-textures](https://github.com/Gethe/wow-ui-textures/tree/e80e3278cc833c89e1f3fc79557b68315d750935),
commit `e80e3278cc833c89e1f3fc79557b68315d750935`, whose commit message identifies
that build. The exact file is
[`CURSOR/UICursor2x.PNG`](https://github.com/Gethe/wow-ui-textures/blob/e80e3278cc833c89e1f3fc79557b68315d750935/CURSOR/UICursor2x.PNG).
It is 512 by 256 pixels with RGBA transparency. The mirror's README identifies
its PNG files as conversions of the client BLP artwork.

The selected normal-hand region is `[1, 1, 129, 129)`, a complete 128-by-128
member excluding the one-pixel atlas gutter. These are the 128-pixel normal
cursor coordinates in
[`sfmict/CursorMod`'s `Data-Mainline.lua`](https://github.com/sfmict/CursorMod/blob/1da61b38c5cc452d38a1fdfea6e192682dfb0add/Data-Mainline.lua),
commit `1da61b38c5cc452d38a1fdfea6e192682dfb0add`. The region was also inspected
against the actual atlas. CursorMod supplies coordinate evidence only; no
CursorMod code, custom cursor image, framework or dependency is shipped.

This is artwork present in an early Dragonflight build, not a claim that the
gauntlet was first introduced in Dragonflight. It is displayed without tint,
rotation, additive blending, an extra outline or a separate glow.

## Ownership

Original World of Warcraft artwork remains copyright Blizzard Entertainment.
The public mirror provides no separate redistribution license for the artwork;
its accessibility does not transfer ownership or establish a new image license.
Keep Blizzard ownership and the source-mirror credit with the asset. The runtime
Lua module contains the corresponding shipped attribution notice.

## Prepared files

| File                               | Role                                                                                                              |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `media/tex/cursor/UICursor2x.tga`  | Complete 512-by-256 source canvas, preserving every decoded RGBA pixel. Preparation only.                         |
| `media/tex/cursor/PointSource.tga` | Full-resolution 128-by-128 selected region, copied without resampling. Preparation only.                          |
| `media/tex/cursor/Point.tga`       | Intentional 32-by-32 LANCZOS adaptation for the native custom-cursor size contract. Preparation only.             |
| `media/tex/cursor/Point.blp`       | Runtime BLP2 Raw3 with eight-bit alpha and the required palette block, losslessly converted from the adapted TGA. |

`scripts/prepare_cursor_art.py` reproduces the region and size adaptation from
the retained source atlas. `scripts/prepare_client_textures.py` performs the
shared lossless BLP preparation. Only the final BLP enters the runtime manifest.
No source/addon cursor-size API, atlas API or external dependency is required
at runtime. The native cursor hotspot remains the top-left corner.

SHA-256 values:

- Original source PNG: `f18ad35fcaf11e88cf99cc54b4319e0f68839cfb3feda9a67eebbdc7446d5776`.
- Full source TGA: `f3a283858af5b2f67fb622ce8ed2bcbfced3485828e6c7178999c428660aff0d`.
- Selected hand TGA: `1bb6a862c18ade3129932be48b1ef4c3df80b365e6fa32dbace0e681081f85bb`.
- Adapted TGA: `1c2ddc7d9926658533a68f4ed0d287dce28af7c452bdb84b97ae2d3dd7098a94`.
- Runtime BLP: `8d35cf1c4212728d26e473298a92aa3fa114b7c5dd476602b5167c46f5b04d13`.

The local before/after reference is the installed game's original
`Interface\Cursor\Point.blp`, found in `Data/patch.MPQ` after inspecting later
patches. Its SHA-256 is
`b844b9538685f949d7942525cf069ac8d79ecea8fcbd34be937e0ee12e1b0699`.
That local extraction is a comparison input and does not ship. Its 32-by-32
image and the prepared new BLP are decoded with the shared authoring reader,
including indexed color's separate alpha block. Static comparisons establish
asset pixels and dimensions, not in-game rendering or pointer behavior.
