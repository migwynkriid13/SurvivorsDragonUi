# Equipped jewelry

The user selected design **20 — Reliquary**, then simplified it to just the item icons and gold circular rims. The panel background, permanent title and side ornaments are removed. The row uses the character's five normal equipment slots: necklace, first ring, second ring, first trinket and second trinket. It is independent of the native six-pickup run build and does not add an ability row or infer run jewelry from worn gear, stats or chat.

## Data and interaction

`modules/ui/jewelry.lua` resolves `NeckSlot`, `Finger0Slot`, `Finger1Slot`, `Trinket0Slot` and `Trinket1Slot` through `GetInventorySlotInfo`, requiring five distinct valid native IDs. `GetInventoryItemTexture("player", id)` supplies each current icon. An empty or unavailable texture leaves that socket blank. No sample icons, item IDs, item names, item statistics, invented ranks or sixth slot are shipped.

Hover uses native `GameTooltip:SetInventoryItem("player", id)`, retaining the game's item description, quality and tooltip cooldown text. The row has no item-use, equip, pickup, replacement or drag handlers outside shared layout editing. Optional cooldown swipes read only native `GetInventoryItemCooldown` start/duration/enable values and use `GetTime` on the same UI clock. A generated 64-state circular shade atlas visualizes the remaining fraction without putting a square model or dark corner cover around the icon. Missing optional APIs omit those features; they do not invent gameplay timing or disable valid icons.

The base client's [inventory readers](https://github.com/samwhosung/benilla/blob/f55bb79b1343629df2705d9e4207a7612a886253/crates/benilla-ui/src/script/char_stats.rs) establish the ordinary equipped-item API and native cooldown clock, separate from the supplied AZS run tables. Source presence does not confirm the exact packaged client's live equipment publication or rendering.

Refresh is bounded to five reads per second per slot while in the world, with world-entry refresh and inventory/cooldown events scheduling the next refresh. Polling also allows native template data that arrives after an inventory event to appear. Cosmetic shade painting is bounded to 30 Hz while visible and changes UVs only when the atlas state changes. Missing required APIs or no native player hides the row and clears icons, cooldowns and owned tooltips. World leave/logout clear them immediately and stop reads/painting until world entry. No equipment or cooldown data is saved.

## Layout and original build

The original 317-by-88 anchor frame and icon positions remain unchanged, preserving confirmed positions/scales. The `/sdui` edit region now fits only the 219-by-43 gold-rim row. Defaults remain above the action bar's static default artwork top with a 12-unit anchor-frame gap, independent of moved/scaled action bars. `/sdui` identifies the group as **Equipped jewelry** and uses the existing move, uniform scale, Hide frame, Confirm, Cancel, discard and full-reset behavior. The group label is editor-only. Only confirmed geometry and the optional hidden flag enter `SurvivorsDragonUiLayout`; no setting or SavedVariable is added.

The original native build HUD is hidden again at the user's request. `Native build rows` in `modules/ui/ui.lua` hides it on initialization, world entry and build-setting changes while in the world, skipping already-hidden values and guarding synchronous callbacks. This affects the native build preference only; clock, encounter and tally takeover are unchanged. Hiding the native six-pickup build does not establish a data mapping between those pickups and the five equipped items.

Artwork sources, circular clipping and conversion are recorded in [Jewelry-ARTWORK.md](../third_party/Jewelry-ARTWORK.md). No local tests, syntax checks, addon execution or game startups are authorized or performed. GitHub Actions checks formatting, local dead code and TOC version metadata; in-game behavior remains unverified.
