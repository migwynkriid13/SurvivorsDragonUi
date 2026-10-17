# Equipped jewelry artwork

The user selected design **20 — Reliquary**, narrowed to the five normally equipped jewelry slots. The gold capsule, stone inset, circular sockets and filigree are a new composition of original geometry and the upstream artwork below. Original World of Warcraft artwork remains copyright Blizzard Entertainment. Source-addon software licenses do not transfer ownership of Blizzard artwork. No source-addon Lua, fonts or sample item icons are imported.

## Pinned inputs

| Source | Original file | Use |
| --- | --- | --- |
| [Karl-HeinzSchneider/WoW-DragonflightUI, b8b35451](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/tree/b8b35451d4621a8097e887385f72ec03e17765f1) | [`Textures/bagborder2.blp`](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/b8b35451d4621a8097e887385f72ec03e17765f1/Textures/bagborder2.blp) | Gold circular socket rims, preserving source alpha. |
| [PentSec/DragonUI, 623eca58](https://github.com/PentSec/DragonUI/tree/623eca5893c9d475a7b77bd25808bdbe801d247c) | [`DragonUI/Textures/Collections/IconFrameGold.tga`](https://github.com/PentSec/DragonUI/blob/623eca5893c9d475a7b77bd25808bdbe801d247c/DragonUI/Textures/Collections/IconFrameGold.tga) | Filigree crop `(0, 90, 114, 123)`, rotated 90 degrees and mirrored at the opposite end. The source square frame is omitted. |
| [Stormhand-dev/DragonflightUI-Reforged, 2a8d2ffb](https://github.com/Stormhand-dev/DragonflightUI-Reforged/tree/2a8d2ffb3d9262f0d2af2071b9b47ef27f76f7f8) | [`media/tex/castbar/CastingBarBackground.blp`](https://github.com/Stormhand-dev/DragonflightUI-Reforged/blob/2a8d2ffb3d9262f0d2af2071b9b47ef27f76f7f8/media/tex/castbar/CastingBarBackground.blp) | Stone inset, clipped inside the capsule at approximately 30% source opacity. |
| Existing Blizzard WidgetStatusBar artwork | `media/tex/timer/BorderCenter.tga`, crop `(21, 0, 42, 7)` | Fine gold top/bottom highlights. Its unchanged provenance is in [WidgetStatusBar-SOURCE.md](WidgetStatusBar-SOURCE.md). |

WoW-DragonflightUI's [MIT notice](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/b8b35451d4621a8097e887385f72ec03e17765f1/LICENSE) credits copyright 2022 Karl-HeinzSchneider. DragonUI's [license and artwork distinction](https://github.com/PentSec/DragonUI/blob/623eca5893c9d475a7b77bd25808bdbe801d247c/DragonUI/LICENSE.txt) credits copyright 2026 NeticSoul and DragonUI contributors; see its [third-party notices](https://github.com/PentSec/DragonUI/blob/623eca5893c9d475a7b77bd25808bdbe801d247c/DragonUI/THIRD_PARTY_NOTICES.md). The relevant MIT text and artwork credits are retained in shipped `modules/ui/jewelry.lua` comments. The project owner has confirmed upstream custom texture redistribution permission; this does not change Blizzard ownership.

## Preparation and runtime geometry

`scripts/prepare_jewelry_art.py` prepares `media/tex/jewelry/Frame.tga`. Supply a scratch directory containing the three original files under their base filenames through `--sources`; the existing timer trim is read from the checkout. The script uses Pillow, with a BGRA decoder for uncompressed BLP2 encoding 3. It runs only as artwork preparation, never as an addon or game check.

The capsule body is 253 by 57 UI units. Its frame, filigree, label space and shadow occupy a 317-by-88 layout group. Artwork is rendered with antialiasing, then placed at two texture pixels per UI unit on an uncompressed 32-bit 1024-by-256 TGA canvas. The visible rectangle is 634 by 176 pixels; runtime UV right/bottom are `317 / 512` and `88 / 128`.

Five 32-pixel circular apertures start at `(54.5, 30.5)` and advance 44 UI units. Native item textures and optional stock cooldown models draw below the frame; the opaque material around each aperture covers their square corners. This uses ordinary 1.12 texture/frame ordering without a retail texture mask API. The gold rims draw over the apertures. The label uses native DEFAULT 10 with outline and shadow; no text or item image is baked into the TGA.

Only the used TGA ships through the shared runtime manifest. Source BLP/TGA inputs, preview PNGs and alternative designs are excluded. Static artwork preparation does not establish native rendering or cooldown-model layering in the packaged game; runtime appearance remains unverified.
