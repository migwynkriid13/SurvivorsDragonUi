# Jewelry rendering follow-up

The request is to reduce rendering cost with five different equipped icons while
preserving their current appearance and behavior, using addon changes only.
This investigation found a further candidate, but it has not established a safe
replacement. The runtime retains the existing fourteen strips per icon.

## Geometry in place of sampling clamps

Each current strip maps an affine section of the native icon and clamps that
section half a source texel inside its UV boundaries. This preserves its edge
colors at fractional layout scales. Each different crop window is a different
material state in the inspected renderer.

A clamped affine coordinate has three intervals: a constant first edge, the
affine interior and a constant last edge. Splitting both axes therefore produces
nine rectangles that reproduce the same coordinate function in exact arithmetic.
Repeating texture coordinates outside the usual zero-to-one range disable the
additional per-quad crop clamp in the reference renderer.

A losslessly rotated source image and negated UVs avoid the low-bit loss of
adding an integer UV offset. A 180-degree rotation can preserve the original
DXT endpoint words and permute the compressed blocks and selectors. This is a
construction using prepared source images; the addon cannot rotate native image
bytes at runtime. A finite prepared catalog would also need the original path
for unknown or future native icons.

For a smaller variant, split only the vertical clamp into three rectangles and
use vertically flipped source images with negative V coordinates. The fourteen
strips have seven symmetric width pairs. Giving each pair a separate,
identical-pixel alias makes its horizontal clamp constant within that alias.

| Five different icons | Visible texture regions | Material groups |
| --- | ---: | ---: |
| Current fourteen-strip renderer | 70 | 70 |
| Vertical subdivision with seven aliases per icon | 210 | 35 |
| Subdivision on both axes | 630 | 5 |

The candidate group counts assume their described alias handles and identical
clamp states; they are not measurements of the live frame or total HUD. Extra
factory frames or hidden catalog regions are additional implementation costs.
Fewer material groups and more regions are competing costs. The pet captures
removed both; they cannot establish which dominates for these alternatives.

## What the packaged client supports

Read-only inspection used the supplied `AzerothSurvivors.exe`, SHA-256
`e069bf3152f8d8f7160d66388907fc181c733bd170aa150d3b7ff7adf251e048`.
These are executable virtual addresses, not addon calls:

- XML metadata producer `0x145182880` tests texture-coordinate edges outside
  zero-to-one at `0x145182cbb` through `0x145182cd2` and stores its wrap flag.
- XML visual loader `0x1451538a0` consumes that flag at `0x145153cca` through
  `0x145153ce7`; texture installation passes through `0x1452371a0` and
  `0x1450f1800`.
- `SetBackdrop` callback `0x14571fe40` parses through `0x145231790` and installs
  through `0x1451e81b0`. Its background builder reads the tile flag at
  `0x1451e87b6`; builder `0x1451c76a0` selects the wrapped texture variant at
  `0x1451c79b2` through `0x1451c79d7`.

This establishes two addon entry points for repeating textures. It corrects the
earlier claim that removing the seventy states necessarily requires a client
change. It does not establish that the proposed replacement is faster or renders
identically.

## Remaining questions

Subdivision changes interpolation and rasterization arithmetic. Exact rational
coordinate equivalence is insufficient to prove identical finite-precision
samples, edge coverage or final pixels at every supported position and scale.
An Actions-only sampling reference can expose differences in its stated model;
it cannot stand in for the packaged renderer.

Wrapped files and aliases have different native texture identities. Texture
sorting can therefore change their relative order against unrelated artwork at
the same stratum, frame level and draw layer. The native action-button normal
and pushed textures provide a concrete peer when detached jewelry overlaps the
buttons. The packaged `Data/patch.MPQ` defines `UI-Quickslot2` and
`UI-Quickslot-Depress` in `ActionButtonTemplate.xml` at lines 74 and 86.
`ActionButton.lua` installs normal artwork for occupied and empty actions at
lines 162 and 171. The action icon itself is BACKGROUND; it is not the ARTWORK
peer cited here.

Dynamic backdrop factories also own their generated regions. Replacing a
backdrop destroys the old region; resizing a resolved factory can rewrite its
UVs. A bounded implementation must retain ownership and prevent those native
updates from undoing its sampling coordinates. Static XML catalogs avoid that
factory behavior but leave allocated regions behind as different icons appear.

An ordinary atlas with duplicated edge pixels does not solve the fractional
clamp: its plateau is generally a live mixture of adjacent source texels.
Storing that mixture in an eight-bit image rounds it, while simply duplicating
the integer texels changes it. A full-quad alpha mask or native portrait circle
also changes the existing strip outline or filtering.

Native inline image text is unavailable as an alternative compositor. The
packaged UI text parser at `0x14067e210` calls iterator `0x145148690`, which uses
the markup decoder at `0x14513aa40`. Its dispatch table at `0x146ba71d0` sends
both `T` and `t` to the literal-pipe return at `0x14513ac51`. A FontString would
display `|T...|t` literally rather than draw the requested image.

`scripts/check_jewelry_repeat_sampling.py` is a standalone Actions-only
reference for the full subdivision candidate. It separates exact rational
equivalence from two stated float32 interpolation models across all fourteen
strips, scales from 0.4 through 3, physical pixel phases and translated origins.
It reports arithmetic discrepancies without treating a UV tolerance as visual
acceptance. It does not execute addon code, decode icons or emulate the GPU.

No prepared native item images, alternate renderer, client changes or game
execution are included. The five-different-icons rendering request remains
open. The existing universal layout/cooldown savings are separate improvements.
