# Retail achievement toast artwork

The personal achievement toast uses Blizzard Entertainment's retail artwork.
The [12.0.5 FrameXML](https://github.com/Gethe/wow-ui-source/blob/74f3176472ad1de60081a967ae87f5dc2856f8ac/Interface/AddOns/Blizzard_FrameXML/Mainline/AlertFrameSystems.xml#L173)
defines the background, icon rim, shield and text geometry. The user reference
images show the numbered shield with the surrounding leaves and its zero-point
emblem variant. The retail atlas calls those members `ui-achievement-shield-1`
and `ui-achievement-shield-nopoints`. The template's numbered default at setup
uses the alternate ornate `ui-achievement-shield-2`.

The [atlas member table](https://wago.tools/db2/UiTextureAtlasMember/csv?build=12.0.5.67451)
and [atlas table](https://wago.tools/db2/UiTextureAtlas/csv?build=12.0.5.67451)
resolve atlas `1771` to [FileDataID 4035524](https://wago.tools/api/casc/4035524?build=12.0.5.67451),
a 1024 × 1024 BLP. The downloaded texture is byte-identical in builds
`12.0.5.67451` and `12.1.5.70783`, with SHA-256
`02bde8b1e111d7cca650c159d8b4dea1faaac207fc390145c059c3b205d5e50c`.

| Atlas member                      | Source crop, right and bottom exclusive | Destination in `Toast.blp` |
| --------------------------------- | --------------------------------------- | -------------------------- |
| `ui-achievement-alert-background` | `(640, 174, 950, 275)`                  | `(0, 0)`                   |
| `ui-achievement-iconframe`        | `(110, 518, 184, 592)`                  | `(312, 0)`                 |
| `ui-achievement-shield-1`         | `(948, 312, 1011, 368)`                 | `(388, 0)`                 |
| `ui-achievement-shield-nopoints`  | `(110, 825, 170, 881)`                  | `(452, 0)`                 |

The four crops retain their decoded pixels and alpha on a transparent
512 × 128 BLP2 canvas. Runtime UVs address the cropped regions at their retail
dimensions. The legacy renderer uses ordinary texture regions and anchors for
the 300 × 101 frame, 52 × 52 icon and title. It uses the shared banner fade and
placement. The toast contains no screenshot pixels.

The artwork remains copyright Blizzard Entertainment. The mirrors, crop and
format conversion grant no new license. See the project's
[artwork notice](SDUI-ARTWORK.md) for its treatment of upstream textures.
