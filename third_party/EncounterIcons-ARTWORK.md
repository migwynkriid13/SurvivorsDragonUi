# Encounter icon artwork

The boss skull and guardian crest come from Blizzard's World of Warcraft client build **12.1.0.69299**. The public [atlas member table][members] and [atlas sheet table][sheets] identify the regions below. Blizzard Entertainment owns the original artwork. The archive provides access to the files and grants no separate artwork license.

| Runtime texture                           | Source                                                                            | Source rectangle     | Preparation                                                                                                                                                                                                                                                                                                |
| ----------------------------------------- | --------------------------------------------------------------------------------- | -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `media/tex/waypoint/WorldQuestBoss.blp`   | [WorldQuest.blp][quest], FileDataID 1339312, 512 × 512, `worldquest-icon-boss`    | [334, 434, 366, 466) | Keep the 32 × 32 crop and its alpha. Apply a light ImageMagick RGB unsharp mask (`0x0.65+0.5+0.015`) and preserve the RGB of fully transparent pixels. Encode as lossless BLP2 Raw3.                                                                                                                       |
| `media/tex/waypoint/GuardianFloating.blp` | [ObjectIconsAtlas.blp][map], FileDataID 1121272, 1024 × 1024, `vignettekillelite` | [203, 395, 267, 459) | Copy the 64 × 64 crop to (0, 0) on a transparent 128 × 128 canvas. Keep all crop pixels in the TGA and lossless BLP2 Raw3. The existing bindings sample [0, 0, 65, 65).                                                                                                                                    |
| `media/tex/timer/WorldQuestBossHalo.blp`  | Alpha of `WorldQuestBoss.blp`                                                     | Full 32 × 32 icon    | Resize the skull mask to 48 × 48 with bilinear sampling and center it at (8, 8) on a 64 × 64 canvas. Use `contour_halo_alpha` from `scripts/prepare_jewelry_runecarver.py`, multiply the mask by 1.65 with clamping, and fill it with RGB (255, 38, 28). Store as lossless BLP2 Raw1 with eight-bit alpha. |

Rectangles use top-left coordinates and exclude the right and bottom edges. The skull is a 16 × 16 marker in Blizzard's World Quest UI. The guardian sprite originally marks rare elites on the map. The halo derives entirely from the skull's alpha.

| File                        | SHA-256                                                            |
| --------------------------- | ------------------------------------------------------------------ |
| WorldQuest.blp source       | `79ff012698575d3b3046761db9cf23e120c110a54abe1c823d3a8ec5a52c2668` |
| ObjectIconsAtlas.blp source | `73fd06a31b77b83d2acbdc2489d9048ba6276325a5abea0804bfef15c5161421` |
| WorldQuestBoss.blp          | `88eb9a15fc40914157402af5e6a57ee4e73d46fd69cd62d5970644735dff489f` |
| GuardianFloating.blp        | `3d52b9d9b1dabb7beeb834fa78a81759529ebac23b6be96285e71dce930fd861` |
| WorldQuestBossHalo.blp      | `1b25f8c8d13a9e2210be765c81b82d6c745657e88dc1a730e3f569316e8356c0` |

[members]: https://wago.tools/db2/UiTextureAtlasMember/csv?build=12.1.0.69299
[sheets]: https://wago.tools/db2/UiTextureAtlas/csv?build=12.1.0.69299
[quest]: https://wago.tools/api/casc/1339312?build=12.1.0.69299
[map]: https://wago.tools/api/casc/1121272?build=12.1.0.69299
