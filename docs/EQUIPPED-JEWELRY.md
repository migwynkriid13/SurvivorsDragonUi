# Equipped jewelry

The Runecarver artwork uses grey-metal housings matched to the action bar. Runecarver supplies the surround: the old circle is removed from the top and sides, while attached jewelry keeps the small bottom arch that joins the bar. Equipped items add a crown gem, three socket stones and a soft outer halo in their rarity color. The row meets the original straight action-bar edge, with no jewelry panel, permanent title or side ornament. It uses the character's five normal equipment slots, ordered left to right as first ring, second ring, necklace, first trinket and second trinket. By default, the necklace occupies the middle socket in both attached and detached modes, including its empty-slot placeholder. It is independent of the native six-pickup run build and does not add an ability row or infer run jewelry from worn gear, stats or chat.

## Settings and placement

Open `/sdui` → **Jewelry** for equipped-jewelry visibility, attachment and the
game's original jewelry/ability rows. These controls now live together on this
page rather than under Action bar.

**Custom jewelry order** is off by default, keeping **ring → ring → neck →
trinket → trinket**. Turn it on to choose the item from a dropdown for each of the five positions,
from left to right. Choosing an item swaps its position with the selected item,
so each equipped slot appears once. The order works attached or detached.
Turning it off restores the original order while retaining your custom choice.

Changes preview immediately. Confirm saves the choice; Cancel, world leave,
logout and reload discard an unconfirmed change. Profiles include the order,
and both full resets turn custom order off. Disabling equipped jewelry dims its
custom-order controls without clearing the choice. Item artwork, size, rarity
effects and effects-only hover text retain their behavior.

## Data and interaction

`modules/ui/jewelry.lua` resolves `NeckSlot`, `Finger0Slot`, `Finger1Slot`, `Trinket0Slot` and `Trinket1Slot` through `GetInventorySlotInfo`, requiring five distinct valid native IDs. `GetInventoryItemTexture("player", id)` supplies each current icon. Item art retains its centered 5% source magnification in both modes. The rendered icon and empty-slot picture use a 33.90-unit artwork box centered on the unchanged 32-unit hover frame, giving the Runecarver opening clearance. Sixteen bands include the formerly missing top and bottom caps, preserving the complete selected vertical image range without adding another circle. No sample equipped items, item IDs, item names, item statistics, invented ranks or sixth slot are shipped.

Empty sockets use the selected original WoW inventory pictures for the necklace, both rings and both trinkets over subtle charcoal circles. The complete source interiors are scaled down and centered with clearance inside the Runecarver housings, so the chain and trinket are not clipped by the circular opening. Source pixels and preparation are recorded in [Jewelry-ARTWORK.md](../third_party/Jewelry-ARTWORK.md). The Runecarver housings, spacing and positions remain the same in attached and detached modes. A successful native texture read returning nil or an empty string shows the matching placeholder; an actual item texture replaces it at the existing refresh cadence. Read failures keep the icon area clear. Placeholders are cosmetic artwork, never stored as equipped-item textures: empty slots clear effects and skip the item tooltip reader. Disable, missing required APIs/player and world cleanup hide them with the rest of the row. No new setting or saved state is added.

Equipped items retain native rarity colors in their effects-only hover text,
including poor and common quality. `GetInventoryItemQuality("player", id)`
supplies the rank; `GetItemQualityColor` or the native `ITEM_QUALITYn_COLOR`
table supplies RGB. Missing, failed or invalid metadata keeps the existing
green hover-text fallback while the normal equipment refresh retries. It never
keeps a removed item's color. Empty slots have no hover card.

Silver, green, blue, purple and orange gems and halos follow native item
quality. Poor and common items share silver. Empty slots and unavailable or
unsupported qualities use the original grey housing. Effects-only hover
text uses native rarity RGB.
Both Performance Mode states and layout editing share the static artwork.
Sources and preparation are recorded in
[Jewelry-ARTWORK.md](../third_party/Jewelry-ARTWORK.md).

Hover shows only the equipped item's native **Equip**, **Use** and **Chance on hit** effect descriptions. A private `GameTooltipTemplate` under a permanently hidden parent reads `SetInventoryItem("player", id)`; this reader never owns or clears the shared `GameTooltip`, whose visual styling is handled separately by the common hover module. The reader scans at most 64 native rows, skipping the item title and selecting effect rows by the native localized `ITEM_SPELL_TRIGGER_*` prefixes, with English fallback labels only when those globals are missing. The complete matched trigger label and its following whitespace are removed for display, including multiword labels such as Chance on hit. Effect wording, numbers and wrapped text are preserved; no arbitrary first word of a description is removed. Binding, equipment type, requirements, flavor text, sale value and separate cooldown metadata are omitted. No effect values are inferred from the icon or item name. Missing APIs, unavailable descriptions or items without recognized effect rows produce no popup; a hovered slot retries at the existing five-Hz cadence so late native data can appear.

The compact formatter uses 69 complete item-effect templates in all thirteen game languages from the inspected embedded catalogs: 31 general stat templates, 16 named modifiers and 22 special modifiers. It covers the earlier screenshot cases and adds experience, double casts, lifesteal, healing on kill, weapon/pet and conditional damage, thorns, percentage regeneration, damage-reduction scaling/caps, DoT haste, revival, named healing/absorb/cooldown/area/duration/weakening/strength/proc-rate modifiers and legendary effects. The source fingerprint and English mapping are in [JEWELRY-EFFECTS.md](JEWELRY-EFFECTS.md); multilingual data, matching and maintenance are in [LOCALIZATION.md](LOCALIZATION.md).

The rule tables lazily compile escaped literal sentences with bounded fields per language. Values, ability subjects, integer/decimal text and supplied units come from the live native description, without numeric conversion, rounding or fixed item values. Both singular/plural target wording and native signed additional-target counts are supported. Conditions, fixed health thresholds, ranges, durations, proc chances, life limits and explicit numeric caps remain visible. Matching tolerates wrapped whitespace and an optional final period and requires the complete description; unknown wording, unsupported value formats, unsupported languages and already concise native captions retain their original wording. These rewrites affect only jewelry hover text, with no change to equipment-slot selection, gameplay stats, other item tooltips or chat formatting. Armor and flat Health lines in inventory tooltips remain metadata outside the effects-only card.

A native trailing `(max)` marker or its localized equivalent is preserved after compacting any recognized template. For example, `Reduces all damage taken by 11% (max).` displays as `- 11% Damage taken (max)`. A native `, at most N times a second` special-effect suffix retains its count and time unit as well. The formatter removes these suffixes only while matching the underlying sentence, then restores them after a successful rewrite. Unknown descriptions keep their original wording and markers. No cap is inferred from an item name, percentage or hardcoded threshold.

The effects appear above the hovered circle in a mouse-transparent dark card with the same thin rounded border as the native unit/ability hovers, adapted from PentSec/DragonUI's tooltip approach. `core/tooltips.lua` supplies the shared backdrop helper; jewelry keeps its own visible frame and private inventory reader. The card has rarity-colored DEFAULT 13 text, without the former editor-style bronze border, gold divider or speech-bubble pointer. The background uses the native tooltip texture, a three-unit inset and the shared dark fill. The editor keeps its existing diamond-metal appearance.

Its width fits the native natural width of the longest effect line, rounded up with one unit of glyph clearance plus 10 units of padding on each side. The text column caps at 272 units for a 292-unit maximum card width. Each hover refresh refits the pooled card and remeasures wrapped height with native 1.12 `GetStringWidth`/`GetHeight`, adding 10 units of top and bottom padding. Unavailable width measurements hide the card until the existing refresh can measure it. It anchors 12 units above the hovered icon, requests screen clamping when available and retains both attachment modes, editing suppression and cleanup on leave, hiding, removal, disable and world exit. No hover or effect state is saved.

The user excluded both the **Targeting** line and health bar from the native unit hover as well. Jewelry adds neither; its effects-only content and all compact values remain unchanged. The shared native-hover styling is independent of the jewelry scanner, which never owns or clears `GameTooltip`. See [TOOLTIPS.md](TOOLTIPS.md) for scope and native API boundaries and [Tooltip-STYLE.md](../third_party/Tooltip-STYLE.md) for the pinned source and shipped license notice.

The base client's [item-tooltip renderer](https://github.com/samwhosung/benilla/blob/f55bb79b1343629df2705d9e4207a7612a886253/crates/benilla-ui/src/script/tooltip_item/render.rs#L615-L627) emits these trigger descriptions as distinct wrapped rows. This supports filtering the native description without reimplementing item calculations; it does not establish packaged-game behavior or expose a new jewelry API.

The row has no item-use, equip, pickup, replacement or drag handlers outside shared layout editing.

The base client's [inventory readers](https://github.com/samwhosung/benilla/blob/f55bb79b1343629df2705d9e4207a7612a886253/crates/benilla-ui/src/script/char_stats.rs) establish the ordinary equipped-item API, separate from the supplied AZS run tables. Source presence does not confirm the exact packaged client's live equipment publication or rendering.

Refresh is bounded to five reads per second per slot while in the world, with immediate refresh on world entry and inventory changes scheduling the next refresh. Polling also allows native template data that arrives after an inventory event to appear. Missing required APIs or no native player hides the row and clears icons and owned tooltips. World leave/logout clear them immediately and stop reads and painting until world entry. Equipment data stays in memory.

## Layout and original build

By default, the five circles line up with action buttons **2 through 6**, one above each button. Center spacing matches button width plus its six-unit gap. While attached, the row is parented to the action bar, so its attachment follows the bar's confirmed position, uniform scale, visibility and editing draft. At the 36-unit reference button size, each rendered item is about 28.38 units wide around its unchanged 26.8-unit hover frame, with its center 20 units above the button tops. The 42⅔-unit Runecarver canvas includes its soft halo and shares the icon center. The socket rail is anchored directly to the action bar, with its centers at the same positions.

The three `SocketRail` BLP strips retain the original straight upper edge and
small bottom arch beneath each housing, with the existing transparent item
cutouts. The lower connector curves underneath the solid Runecarver rim and
meets the bar smoothly, with no exposed cut ends. It keeps the original native
bevel and bar join. The old circle is removed from the top and sides.
They retain their shared bar-owned geometry, UVs and neighbour gutters. The
original `HDActionBar.tga`, seven buttons and lower background stay unchanged.
When jewelry is unavailable or hidden, the original complete bar background
is restored.

The original 317-by-88 internal jewelry frame remains. Attached mode uses **Action bar** for the combined assembly, extending its edit region to include the sockets. Detached mode parents the same icons to a separate UIParent-owned container registered as **Equipped jewelry (detached)**, with its own uniform scale, location and optional hidden flag under the existing `jewelryBar` layout key. This keeps attached and detached geometry separate without moving either registered owner between parents. Confirm, Cancel, Hide frame, discard and full reset use the shared lifecycle. Earlier standalone geometry is reused only when detached; it never moves the attached row. Reattaching retains detached geometry for the next detachment. No migration flag or SavedVariable is added. Existing action-bar geometry, other groups' geometry, native button handlers and equipment-data behavior are preserved. Both layout groups suppress jewelry tooltips while editing.

**Equipped jewelry** in `/sdui` → **Jewelry** defaults on. Turning it off hides the five icons and Runecarver housings, restores the original complete action-bar edge and contracts the action-bar editing bounds. Equipment reads stop while disabled. The toggle previews immediately, saves its normalized `equippedJewelry` boolean in the existing `SurvivorsDragonUiDisplay` table only with Confirm, and rolls back on Cancel, world leave/logout/reload. Both full resets restore on. It does not change native build visibility or action-bar geometry.

**Attach jewelry to action bar** defaults on and is dimmed and mouse-disabled while Equipped jewelry is off. It retains its value while disabled. Off keeps the same Runecarver housings and restores the original action-bar edge, without adding detached silver circles. The five former backing regions and unused `SocketDetached` source/runtime files are removed. Independent defaults retain their original placement derived from static bar appearance metadata, without reading moved/scaled bar geometry. Only Confirm saves the normalized `attachJewelry` boolean in the existing display table. Cancel and world leave/logout/reload discard mode and detached-layout drafts; both full resets restore attached mode and default geometry. The native-build visibility choice remains independent.

The independent **Hide default jewelry / abilities** HUD toggle defaults on. `Native build rows` in `modules/ui/ui.lua` feature-detects the official getter/setter and applies the inverse of the `hideNativeBuild` display boolean on initialization, world entry, display changes and native `hudBuild` changes while in the world. Turning it off explicitly shows both original weapon/jewelry rows. Matching visibility causes no repeated write, and synchronous callbacks are guarded. Confirm alone saves the boolean in the existing display table. Cancel and world leave/logout/reload restore the committed choice; the module discards display drafts before world-exit or native reload saving, independently of event-handler order. Both full resets restore hiding. There is no per-frame polling, prior-visibility snapshot or new SavedVariable. Clock, encounter and tally takeover are unchanged. Hiding the native six-pickup build does not establish a data mapping between those pickups and the five equipped items.

Artwork sources, circular clipping and conversion are recorded in [Jewelry-ARTWORK.md](../third_party/Jewelry-ARTWORK.md). No local tests, syntax checks, addon execution or game startups are authorized or performed. GitHub Actions checks formatting, local dead code and TOC version metadata; in-game behavior remains unverified.
