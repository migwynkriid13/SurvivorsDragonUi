# Level Up artwork

The selected **04 · Artisan metal** design uses a dark profession panel,
silver beveled corners and a small crest at the top and bottom. The native class
icon sits in the matching silver rim beside the single live **LEVEL UP** heading.
The existing gold waiting-count badge retains its original plain DEFAULT 12 font.
The heading retains DEFAULT 22, global outline/shadow choices and translations.

The local static preview is `docs/designs/level-up-styles/artisan-selected.png`,
excluded from Git and the runtime payload. It is an enlarged artwork assembly,
with an example Mage icon and five waiting
levels. Georgia approximates the runtime DEFAULT font. It does not establish
client rendering or native font metrics.

## Source and ownership

- Source: [ghbset/DragonUI_NewEra, commit 2384e1d96dd58ef325b236c0dfccbd21a08bfccb](https://github.com/ghbset/DragonUI_NewEra/tree/2384e1d96dd58ef325b236c0dfccbd21a08bfccb).
- File: [`Textures/Professions/4417031-professions-chrome-sheet.blp`](https://github.com/ghbset/DragonUI_NewEra/blob/2384e1d96dd58ef325b236c0dfccbd21a08bfccb/Textures/Professions/4417031-professions-chrome-sheet.blp), BLP2, 2048 × 2048.
- File SHA-256: `64d0b5b23103d999d0b8ab7a695c77fc5e0867c7233a04ab60860cc067106f8c`.
- The source's [`modules/professions/Assets.lua`](https://github.com/ghbset/DragonUI_NewEra/blob/2384e1d96dd58ef325b236c0dfccbd21a08bfccb/modules/professions/Assets.lua) transcribes the named regions from build **12.0.5.67451**. This verifies shared profession artwork in Midnight-era data; it does not establish Midnight as its original expansion.

Blizzard Entertainment owns the underlying World of Warcraft artwork. The source
mirror describes extracted retail art and supplies no separate artwork grant;
public availability does not resolve redistribution rights. No source-addon
Lua, framework or retail atlas API is imported. The gold badge is original
geometric artwork; the silver halo derives from the selected Blizzard border.

All rectangles below use `(left, top, right, bottom)` with exclusive far edges.

| Named source region                 | Source rectangle      | Prepared use                             |
| ----------------------------------- | --------------------- | ---------------------------------------- |
| `professions-qualitypane-bg-top`    | `(478,431,738,531)`   | First 45 rows at atlas `(0,0,260,45)`    |
| `professions-qualitypane-bg-bottom` | `(740,431,1000,530)`  | Last 45 rows at `(0,45,260,90)`          |
| `professions-slot-frame`            | `(405,1643,445,1683)` | Complete 40 × 40 rim at `(272,0,312,40)` |

The proposed one-row middle region is unnecessary at this height: the original
comparison already joined these top and bottom caps. The implementation retains
that exact 260 × 90 assembly, without tinting or resampling its source pixels.

## Preparation and runtime geometry

`scripts/prepare_levelup_art.py --source /path/to/professions-chrome.blp`
prepares `media/tex/levelup/Artisan.tga` and its lossless Raw3 BLP2 counterpart.
The 512 × 256 canvas fits the current native client's power-of-two size gate.
The border-shaped silver halo occupies `(0,128,260,218)`; the unused remainder
of the lower half is transparent. Its source mask uses each panel pixel's
largest RGB channel, subtracts 32 to exclude the dark interior, scales the
remaining brightness by 0.55 and multiplies by the source alpha. A one-pixel
Gaussian blur softens that mask. The halo color is `(205,216,221)`.
Omitting `--source` rebuilds only this halo from the retained authoring atlas;
the original panel and icon-rim pixels stay in place.
`CountBadge.blp` and its existing 64 × 64 authoring TGA are unchanged.

Five side-by-side panel strips use x boundaries `0,20,106,154,240,260` and the
same `0..90` vertical range. At the existing 72-unit panel height, left/right
corners keep 16-unit widths and the central crests keep 38.4 units. Only the two
plain spans stretch between those three anchored pieces. Native anchors follow
the measured caption width; changing language or font adds no regions or
per-frame layout loop. Adjacent strips share their original atlas neighbours
for filtering.

Content measurement keeps its 60-unit title inset and ten-unit side padding;
the heading paints three units left of that inset for optical centering. A 40-unit
class icon centers inside a 44-unit silver rim; its upper-right badge keeps the
existing count measurement and widening behavior. The complete panel remains
centered within the same multilingual Layout owner, at the existing 0.7 visual
scale. Confirmed position, scale, counts, native action and ownership are not
rewritten.

The current runtime binds only the static panel and original icon rim from this
atlas. Both Performance Mode states show the same eight textures: five panel
strips, the class icon, silver rim and gold badge. The former five halo strips
and duplicated icon highlight are removed, along with their pulse math, hover
state, mode listener and per-frame cosmetic callback. The retained atlas's lower
halo cells are no longer bound or displayed; its dimensions and static source
pixels are unchanged.

Hiding, zero count and world/reload retirement retain their existing cleanup.
The ten-Hz native state reader still owns counts and HUD handoff, and Show primes
that reader. Removing the pulse drops six texture regions and its per-frame
alpha writes without adding an event, frame, updater, setting or saved state.
These counts do not establish native draw calls, memory use or FPS.

Only `Artisan.blp` and `CountBadge.blp` ship for this component. The retired
`Backdrop.blp`, `Glow.blp` and `IconFrameGold.blp` are removed from the runtime
manifest and installed tree. The full downloaded sheet and inspection output
are temporary, and the authoring TGA and selected preview stay outside the
payload. Local work uses artwork preparation, source review and pinned
formatting. CI-only cases cover fixed corners/crests and strip anchors, caption
fitting/reuse, eight static regions and no cosmetic updater through both mode
states and Hide/Show, plus the existing hidden/native lifecycle. No local
tests, standalone validation or addon/game execution were performed.

## Retained earlier design sources

The original comparison retains its gold-framed alternatives. The retired gold
rim, backdrop and glow authoring TGAs are available in Git history; they no longer
stay in runtime media. The loot and Guardian preview tools recreate their shared
original geometric backgrounds through `legacy_backdrops()` in the artwork
preparation module, without retaining duplicate images or downloading artwork.

The earlier gold rim came from [NeticSoul/DragonUI, commit 6d9cc95eedd1de78fab3b965683df13421e21604](https://github.com/NeticSoul/DragonUI/blob/6d9cc95eedd1de78fab3b965683df13421e21604/DragonUI/Textures/Collections/IconFrameGold.tga),
128 × 128. Its notices trace it to DragonflightUI's
[`Textures/UI/Spellbook-Parts.blp`](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/f59cbc3f7010ef692fb983c7c3c848c4b70f56ce/Textures/UI/Spellbook-Parts.blp).
The prior preparation mirrored the clean 38 × 38 upper-right quadrant
`(61,19,99,57)` into a plain rim and cleared its inner opening. The earlier
black backdrop and gold glow were original geometric images from that design.
Blizzard ownership remains separate from the software notices below.

```text
MIT License
Copyright (c) 2026 NeticSoul and DragonUI contributors
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
