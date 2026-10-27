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
three layers together for missing, common-quality and empty-slot results.
Valid updates retain already-correct visibility and RGB instead of hiding and
repainting the three rims first. Actual texture colors are compared where the
client supplies the getter; otherwise the last successful tint is reused and
forgotten on clearing. Native reads and unknown-quality retries remain intact.

## Native behavior

`modules/ui/character.lua` retains `CharacterFrame`, `PaperDollFrame`, the
existing `CharacterModelFrame` and every native equipment button. It does not
replace `ToggleCharacter`, key bindings, close/Escape
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

Ordinary native stat updates coalesce into one queued layout pass after the
current UI callback, using one stable callback rather than replacing it for
every request. This lets the game finish updating and translating its rows
first. Opening the character pane/window instead flushes that pass at the end
of the existing Show handler, after its native callback. The first visible
paint therefore receives the prepared two-column layout instead of briefly
showing the native Run Stats sizing. Work stops after the queued pass and while
the window is hidden. Hiding the pane or
window and world cleanup cancel the request and clear its queued state, so
reopening can schedule normally. The scroll position is session-only, clamped
when the list shrinks and reset on world leave/logout. Missing native extra
stats leave the primary panel usable.

## Presentation caching

Row text measurements are reused while their label/value text, FontStrings,
font settings, effective parent scale and column widths match. Pending glyph
measurements remain retryable. Visible rows are paired directly without a new
compaction table. Primary-row storage is reused; extra rows are rediscovered
and sorted when their native child structure changes, with the existing
`GetChildren` path retained when a child-count getter is unavailable.

The native game still rewrites extra-row anchors and the extra-card height on
each stats update, even when displayed values are unchanged. Rows and the Run
Stats title also pass through the shared font helper on refresh: it compares
their actual current face, size and flags, skipping matching font writes rather
than treating a retained FontString identity as proof of its style. The skin compares
actual anchors, widths, heights and levels before writing, so those native
resets are repaired while unchanged primary rows and text placement are left
alone. Native text, conditional visibility and tooltip fields remain live.
Category heights, scroll bounds, scroll offsets and arrow enablement only
change when needed, with a forced offset refresh after content resizing or
pane opening.

The header reuses name and level-caption measurements while text, fonts,
parent scale, pane and window width match. Native name/rank/level changes still
invalidate measurement, and actual header placement and visibility are checked
after native updates. Closed windows skip header work. The native model,
camera, equipment updates and all three quality-rim passes remain unchanged.
No polling loop, setting, asset or SavedVariable is added.

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

The 2026-10-25 performance follow-up also read the current installed executable
without running it: 142,111,232 bytes, SHA-256
`0258b8a43d9ba3170b15e5fc07a646a606eb2972a5dd6aa0e6349a07ec390e2c`.
Its `AZS_Row` starts at offset `120805068`, `AZS_Update` at `120805431` and
`AZS_UpdateMore` at `120808696`. The primary updater writes native text and
tooltip fields; the extra updater also resets each visible row's anchors and
the container height. Its `PaperDollFrame_OnEvent` at `120812574` refreshes
stats on received `AZS` messages while visible. These source boundaries explain
why cached measurements must still allow native geometry repairs; they do not
establish an event rate or runtime FPS impact.

## Artwork and verification limits

See [Character-ARTWORK.md](../third_party/Character-ARTWORK.md) for pinned
Blizzard texture sources, source rectangles, attribution and preparation.
Only the loaded module and used TGA files join the shared runtime manifest.

The performance follow-up was formatted locally with pinned StyLua 2.6.0 and
Prettier 3.9.10. Source/diff inspection covered native anchor resets, text/font
and scale changes, missing quality data, conditional rows, scroll clamping,
pending refresh cancellation and reopening. Local tests, standalone syntax or
validation checks and addon/game execution were not run. GitHub Actions was not
awaited. In-game appearance, model rendering, scrolling, input, tooltips and FPS
impact remain unverified.

The 2026-10-27 opening-size correction uses the existing synchronous Show hooks and the existing flush/cancel function. It adds no polling, frame, region, asset or saved state. Opening may run the cached layout once for the pane and once for its owner after each native callback; ordinary stat updates remain coalesced. Local work was limited to source/diff inspection, data-only native-source reading and pinned formatting. The reporter's size-jump symptom and its correction have not been exercised in-game.
