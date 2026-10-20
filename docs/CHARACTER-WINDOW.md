# Character window

The character window opened with C uses a metal frame, equipment
columns around the existing character model and a scrollable right-hand stats
panel. The Character, Skills and Honor bottom tabs stay hidden, including after
native updates try to show them. Mouse wheel, scrollbar and arrow buttons reach the
complete stats list. This is an addon skin of the native window.

The native character name and level/race/class caption share one centered row
inside the top metal border, with a three-unit word gap. Both use gold DEFAULT
text. Native name, rank and
level updates still supply the captions, including translated wording; their
combined width stays clear of the close button. Other native panes show only
the name. The portrait and native guild/title captions stay hidden, including
after native Show attempts. A plain Blizzard metal corner replaces the
portrait ring; the window border and working close button remain.

The character content starts just below the title bar. Window height follows
the bottom of the weapon artwork, with six units of clearance. At the current
equipment placement that is 452 units high, removing the empty strip below the
weapons. The sidebar follows the shorter window and retains a 402-unit scroll
viewport. Equipment positions and sizes, the model viewport and the top anchor
remain unchanged. Other native panes keep their original 512-unit height.

The default left placement has a 12-unit horizontal inset so the window border
clears the screen edge. Native vertical placement, center/pushed positions and
other anchors remain unchanged. Opening or moving the panel back to the native
left slot reapplies the inset without accumulating it or saving a position.

The weapon, shield/off-hand, ranged and ammo row sits 32 units above its first
placement. Its top artwork edge aligns with the wrist row's bottom artwork
edge. Horizontal positions and button sizes stay the same; the model viewport,
scenery and lower trim end higher to keep the equipment row clear.

Equipped items of uncommon or higher quality have a colored inner border,
using Blizzard's `WhiteIconFrame` artwork and the native item-quality palette.
The original full-opacity rim now has a 40%-alpha additive brightness pass and
a 30%-alpha additive outer rim extending one UI unit beyond the button. All three
reuse the same transparent artwork and native color, making the quality outline
brighter and wider while keeping the item icon clear. Button and icon dimensions,
metal surrounds, cooldowns and input bounds remain unchanged.
All equipment slots, including weapons, ranged/relic and ammo, share the same
handling. Poor/common, empty and unknown-quality slots keep the neutral metal
surround. Native slot updates refresh the border after equipment changes;
opening the pane refreshes every border. The skin reads
`GetInventoryItemQuality` and `GetItemQualityColor`, with the native quality
color globals as a fallback. It never infers rarity from the item's name or
tooltip, recolors its icon or replaces native slot scripts. Borders hide on
world leave/logout and no item data is saved. One shared hide path clears all
three layers together before each native quality read, including missing,
common-quality and empty-slot results.

## Native behavior

`modules/ui/character.lua` retains `CharacterFrame`, `PaperDollFrame`, the
existing `CharacterModelFrame` and every native equipment button. It does not
replace `ToggleCharacter`, key bindings, the micro-menu click, close/Escape
handling, equipment events, pickup/drop/click handlers, cooldowns or tooltip
scripts. It changes their appearance and geometry. The model keeps its native
unit binding, rotation, equipment updates and camera; no portrait model or
camera controls are introduced.

The twelve primary stat rows keep their native names, labels, values and
handlers. The game still owns their calculation and formatting. The skin
reparents their `CharacterAttributesFrame` into the stats scroll child.

Each category lays out its visible stats in two columns of label/value pairs,
in native order from left to right, then down. Both columns share the existing
panel width, with a 12-unit gutter. Each pair uses the taller row's measured
height, so long translated labels and values wrap without overlapping the next
pair. An odd final stat stays in the left column. Hidden conditional stats leave
no empty cells; category heights and the scroll range follow the visible rows.
The category headings still span both columns. Both columns use the shared
scroll area; equipment and model geometry are independent of row layout.

The native `AZSMoreStats` container and its existing rows join that same scroll
child. Rows retain their native conditional Show/Hide state and tooltip fields.
The skin does not read `AZS_STATS`, copy values, reconstruct tooltips or maintain
its own list of conditional stats. It discovers the container's native row
children, retaining their numeric name order. Labels and values use DEFAULT,
with wrapping and measured heights for long translated text. Native resistance
controls remain available when the game shows them.

Native stat updates queue one layout pass after the current UI callback. This
allows the game to finish updating and translating its rows first. Work stops
after the queued pass and while the window is hidden. The scroll position is
session-only, clamped when the list shrinks and reset on world leave/logout.
Missing native extra stats leave the primary panel usable.

The hidden tabs retain their native contents and scripts; C and any existing
native key bindings still control their panes. Pet and any other available
native tabs retain their existing visibility. The skin does not enable a tab
the game hides. Non-character panes keep their original content area.
There are no new preferences, commands, SavedVariables or runtime dependencies.

## Source evidence

Read-only inspection on 2026-10-20 used the supplied game's executable:

- Size: 139,779,584 bytes.
- SHA-256: `96e24dcd0e53fc13a6fdef5826aa46f77a29aa1aad4abd585adf04e94b2756d3`.
- The embedded character-stat source begins at file offset `112821936`. It
  defines `AZS_Row`, `AZS_Update`, `AZS_MoreRow` and `AZS_UpdateMore`, and wraps
  the stock `PaperDollFrame_Set*` functions for the player.
- Its primary rows show Health, Damage, Haste, Crit, Crit Dmg, Armor, Area,
  Targets, Echo, Speed, Regen and Pickup. The extra panel includes Lifesteal,
  Kill Heal, Thorns, Lives, Experience, Gold, Luck, Buff Power, DoT Stacks,
  DoT Haste and conditional damage modifiers. The implementation consumes the
  existing controls rather than duplicating that list in runtime code.
- The embedded `ToggleCharacter` wrapper preserves the stock function and
  rejects the Reputation tab. The skin leaves that wrapper intact.

The native frame names, equipment scripts, model handlers and tab mechanics
were also read in the
[1.12.1 FrameXML source](https://github.com/MOUZU/Blizzard-WoW-Interface/tree/d162a4c0d198a4381b5b6573d975635ed7316702/1.12.1/FrameXML).
The packaged game's own additions take precedence over that stock reference.
Raw executables, extracted game scripts and gameplay snapshots are not shipped.

## Artwork and verification limits

See [Character-ARTWORK.md](../third_party/Character-ARTWORK.md) for pinned
Blizzard texture sources, source rectangles, attribution and preparation.
Only the loaded module and used TGA files join the shared runtime manifest.

Local tests, validation, syntax/formatting tools and addon/game execution were
intentionally not run. The authorized GitHub Actions job checks formatting,
local dead code and TOC metadata. Artwork inspection and those checks do not
establish in-game appearance, model rendering, scrolling, input or tooltips.
