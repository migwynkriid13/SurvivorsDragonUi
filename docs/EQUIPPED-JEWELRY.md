# Equipped jewelry

The user selected design **20 — Reliquary**, using only jewelry, and explicitly chose the character's five normal equipment slots: necklace, first ring, second ring, first trinket and second trinket. This row is independent of the native six-pickup run build. It does not add an ability row or infer run jewelry from worn gear, stats or chat.

## Data and interaction

`modules/ui/jewelry.lua` resolves `NeckSlot`, `Finger0Slot`, `Finger1Slot`, `Trinket0Slot` and `Trinket1Slot` through `GetInventorySlotInfo`, requiring five distinct valid native IDs. `GetInventoryItemTexture("player", id)` supplies each current icon. An empty or unavailable texture leaves that socket blank. No sample icons, item IDs, item names, item statistics, invented ranks or sixth slot are shipped.

Hover uses native `GameTooltip:SetInventoryItem("player", id)`, retaining the game's item description, quality and tooltip cooldown text. The row has no item-use, equip, pickup, replacement or drag handlers outside shared layout editing. Optional cooldown swipes read `GetInventoryItemCooldown` and use the stock 1.12 `CooldownFrameTemplate` Model with `CooldownFrame_SetTimer`. Missing optional tooltip/cooldown APIs omit those features; they do not invent gameplay timing or disable valid icons.

The base client's [inventory readers](https://github.com/samwhosung/benilla/blob/f55bb79b1343629df2705d9e4207a7612a886253/crates/benilla-ui/src/script/char_stats.rs) establish the ordinary equipped-item API, separate from the supplied AZS run tables. The stock [cooldown template](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/Cooldown.xml) and [timer helper](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/Cooldown.lua) use the native `GetTime` clock. Source presence does not confirm the exact packaged client's live equipment publication or rendering.

Refresh is bounded to five reads per second per slot while in the world, with world-entry refresh and inventory/cooldown events scheduling the next refresh. Polling also allows native template data that arrives after an inventory event to appear. Missing required APIs or no native player hides the row and clears icons, cooldowns and owned tooltips. World leave/logout clear them immediately and stop reads until world entry. No equipment or cooldown data is saved.

## Layout and original build

The 317-by-88 jewelry group defaults above the action bar's static default artwork top, with a 12-unit gap. Its position is independent of moved/scaled action bars. `/sdui` identifies it as **Equipped jewelry** and uses the existing move, uniform scale, Hide frame, Confirm, Cancel, discard and full-reset behavior. Only its confirmed geometry and optional hidden flag enter `SurvivorsDragonUiLayout`; no setting or SavedVariable is added.

The original native build HUD remains visible for comparison. `Native build comparison` in `modules/ui/ui.lua` restores it once per initialization, including a prior saved hidden preference. Later native option changes remain available. This affects the native build preference only; clock, encounter and tally takeover are unchanged.

Artwork sources, crops and conversion are recorded in [Jewelry-ARTWORK.md](../third_party/Jewelry-ARTWORK.md). No local tests, syntax checks, addon execution or game startups are authorized or performed. GitHub Actions checks formatting, local dead code and TOC version metadata; in-game comparison remains unverified.
