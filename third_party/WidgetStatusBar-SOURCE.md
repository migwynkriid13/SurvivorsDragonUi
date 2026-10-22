# Blizzard WidgetStatusBar artwork

Original artwork is owned by Blizzard Entertainment. The Gethe archive is a public extraction of World of Warcraft client UI assets; it does not grant a new license to Blizzard artwork.

Source: https://github.com/Gethe/wow-ui-textures/blob/d23deaf8f44a7d280dc974a5c9d5321c013db59b/Widgets/WidgetStatusBar.PNG

Original PNG retained as `media/tex/timer/WidgetStatusBar.png`. `WidgetStatusBar.tga` is an uncompressed 32-bit BGRA TGA copy of the original 256 × 256 RGBA sheet, preserving its alpha channel.

Crop coordinates come from the original client `UiTextureAtlasMember` DB2 table for Dragonflight 10.1.5 build 50232, exported by Wago Tools:

- https://wago.tools/db2/UiTextureAtlasMember/csv?build=10.1.5.50232
- https://wago.tools/db2/UiTextureAtlas/csv?build=10.1.5.50232

Atlas ID: `1925`; texture FileDataID: `4352554`; source dimensions: `256 × 256`.

Related original UI source: https://github.com/Gethe/wow-ui-source/blob/10.1.5/Interface/AddOns/Blizzard_UIWidgets/Blizzard_UIWidgetTemplateStatusBar.lua

All coordinates below are pixels measured from the top-left of the sheet. Right and bottom bounds are exclusive. Extracted pieces keep source pixels and alpha unchanged on power-of-two transparent canvases. Fill textures repeat their last source row into the single padded row so a native 1.12 status bar can use the whole texture without a transparent seam.

| File (.tga) | Crop left, top, right, bottom | Content size | Canvas size | UV right | UV bottom |
| --- | --- | --- | --- | --- | --- |
| BorderLeft | 1, 172, 36, 203 | 35 × 31 | 64 × 32 | 0.546875 | 0.96875 |
| BorderRight | 1, 205, 36, 236 | 35 × 31 | 64 × 32 | 0.546875 | 0.96875 |
| BorderCenter | 0, 1, 64, 32 | 64 × 31 | 64 × 32 | 1.0 | 0.96875 |
| BackgroundLeft | 94, 172, 123, 190 | 29 × 18 | 32 × 32 | 0.90625 | 0.5625 |
| BackgroundRight | 94, 192, 123, 210 | 29 × 18 | 32 × 32 | 0.90625 | 0.5625 |
| BackgroundCenter | 0, 67, 64, 85 | 64 × 18 | 64 × 32 | 1.0 | 0.5625 |
| FillBlue | 0, 87, 256, 102 | 256 × 15 | 256 × 16 | 1.0 | 0.9375 |
| FillYellow | 0, 155, 256, 170 | 256 × 15 | 256 × 16 | 1.0 | 0.9375 |
| FillWhite | 0, 138, 256, 153 | 256 × 15 | 256 × 16 | 1.0 | 0.9375 |
| Spark | 75, 205, 83, 237 | 8 × 32 | 8 × 32 | 1.0 | 1.0 |

The original atlas names use the `widgetstatusbar-` prefix: `borderleft`, `borderright`, `bordercenter`, `bgleft`, `bgright`, `bgcenter`, `fill-blue`, `fill-yellow`, `fill-white`, and `spark`.

## Fixed-width pill background

`BackgroundFixed.tga` combines the existing background crops for the run timer
and boss pills. Its 284-by-18 content uses the 29 left-cap columns, 226 copies
of each center row's first pixel, and the 29 right-cap columns, on a transparent
512-by-32 canvas. `scripts/prepare_timer_background.py` reproduces the file from
the shipped crops without a new download or image resampling.

The original center rows are horizontally uniform opaque black, and the cap
columns at both joins have the same pixels. The composite keeps each cap's
one-source-pixel-per-local-unit mapping and the same vertical crop. Native
half-texel crop clamping therefore retains the original filtering at the
outside edges and identical black samples at the internal joins, including
under uniform Layout scaling. The variable-width tally retains its original
three pieces. Border pieces stay separate because their joining rows differ.
