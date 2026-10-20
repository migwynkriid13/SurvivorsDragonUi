# Level Up artwork

The user selected **28 · Framed Icon + Text** from the asset comparison, with the current-level caption centered below the Level Up! heading. The native class icon sits inside an ornamental square gold frame. A small round waiting-count badge overlaps the upper-right. The surrounding background is transparent. Text remains live and uses the game's DEFAULT font.

## Gold frame source

- [NeticSoul/DragonUI, commit 6d9cc95eedd1de78fab3b965683df13421e21604](https://github.com/NeticSoul/DragonUI/tree/6d9cc95eedd1de78fab3b965683df13421e21604).
- Exact file: [`DragonUI/Textures/Collections/IconFrameGold.tga`](https://github.com/NeticSoul/DragonUI/blob/6d9cc95eedd1de78fab3b965683df13421e21604/DragonUI/Textures/Collections/IconFrameGold.tga), a 128-by-128 uncompressed RGBA TGA. The full canvas is copied byte-for-byte, retaining its colors and transparency; no source crop or format conversion is applied.
- The source's [third-party notices](https://github.com/NeticSoul/DragonUI/blob/6d9cc95eedd1de78fab3b965683df13421e21604/DragonUI/THIRD_PARTY_NOTICES.md) identify this isolated image as a cut and resample from DragonflightUI's Spellbook-Parts sheet. The upstream file is [`Textures/UI/Spellbook-Parts.blp`](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/f59cbc3f7010ef692fb983c7c3c848c4b70f56ce/Textures/UI/Spellbook-Parts.blp). The implementation uses the verified isolated TGA rather than guessing coordinates on that upstream sheet. Repository family names do not establish an exact retail client build for these pixels.
- Source software notices: [MIT, NeticSoul and DragonUI contributors, 2026](https://github.com/NeticSoul/DragonUI/blob/6d9cc95eedd1de78fab3b965683df13421e21604/LICENSE), and [MIT, Karl-HeinzSchneider, 2022](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/f59cbc3f7010ef692fb983c7c3c848c4b70f56ce/LICENSE). The applicable notices are retained in shipped `modules/ui/levels.lua` comments.

Underlying World of Warcraft artwork remains copyright Blizzard Entertainment. The repositories' software licenses do not relicense Blizzard artwork. No source-addon Lua, framework, font or runtime dependency is imported.

## Assembly and preparation

`scripts/prepare_levelup_art.py --source /path/to/IconFrameGold.tga` copies the source into `media/tex/levelup/IconFrameGold.tga`. It also draws `CountBadge.tga`, an original gold disk with a muted brown rim and transparent outer corners, at four times the output resolution before downsampling to a 64-by-64 uncompressed RGBA TGA. This is geometric artwork preparation and does not execute addon code.

The runtime draws the full gold frame at 72 by 72 local units. The native square class icon occupies `72 * 55 / 103` units, offset `72 * 21 / 103` from the left and `72 * 17 / 103` from the top. These proportions reproduce the selected comparison's assembly; they are not claimed to be upstream atlas coordinates. The full native class-atlas quadrant remains visible under the frame.

The heading starts 82 units from the left and 12 from the top, in DEFAULT 22 with outline and shadow. Its region fits the active translation's natural glyph width plus four units. The DEFAULT 12 current-level caption anchors its top center to the heading's bottom center, two units below. Shared edit bounds still fit the widest supported heading and retain the existing 0.7 default visual scale and saved geometry.

The count badge starts at 20 by 20 local units. Its right edge anchors 68 units from the visual's left edge, with its top at the visual's top. Larger native counts widen the badge around the live DEFAULT 12 text. Hover reuses the same frame texture with additive blending at 0.35 alpha. Ordinary legacy texture and anchor APIs handle both assets; no retail atlas or mask API is required.

Only the two used TGA files join `packaging/runtime-files.json`. Source sheets, comparison previews and preparation tools are excluded from the shipped payload. Static artwork inspection does not establish in-game rendering; local validation and addon/game execution remain unauthorized.
