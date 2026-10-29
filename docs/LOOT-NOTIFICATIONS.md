# Loot notifications

`/sdui` → **Loot notifications** offers **SDUI**, **Game** and **Off**:

- **SDUI** is the default and uses the silver cards described below.
- **Game** explicitly enables the game's original loot boxes and stops SDUI intake.
- **Off** hides both popup styles; loot still appears in chat.

**Show marks rewards** is on by default. In SDUI mode, an already-collected item
with a positive conversion reward can show `Item name → +1 Mark` on the existing
card. The native amount is retained, including plural amounts. Duplicates with
no positive reward remain excluded. Standalone earned-marks chat notices do not
create a second popup for the same event. Game mode leaves popup content to the
game. The checkbox retains its value but is dimmed and ignores input in Game/Off.

`lootMode` (`sdui`, `game`, `off`) and `lootShowMarks` (boolean) use the existing
display table. Missing/invalid values and both full resets restore SDUI and marks
on. Shared live preview, Confirm, Cancel/world/logout/reload discard and profiles
apply. Changing either choice retires queued/visible cards; old notices never
replay when returning to SDUI. Move, scale and hide stay in the separate Layout
group, and a Layout-hidden custom view does not turn native boxes back on.

The user selected **02**, Blizzard's silver loot alert, with the retail-style
gold **You received** heading and quality-colored item name. The slot header
and collection subtitle are omitted. Both lines request the game's original
`Fonts\\FRIZQT__.TTF` (Friz Quadrata), with resolved DEFAULT as a fallback.
The installed game's native `data/interface/framexml/fonts.xml` selects this
face for `GameFontNormal`, and `data/fonts/frizqt__.ttf` is present. No font
file or font setting ships with the addon.

[Selected static preview](designs/loot-notifications/selected.png).
The [original proposals](designs/loot-notifications/index.html) remain outside
the runtime payload. Their earlier slot/status lines are not the selected view.

## Selected view

`modules/ui/loot_view.lua` registers a real, passive three-card pool, prepared
once on the first SDUI readiness request. An initial Game/Off choice creates no
card textures or labels. Preparation failures stay unready and preserve native
fallback without allocating another pool. Each card
uses the unmodified 276-by-96 silver LootToast crop, with a 50-by-50 native item
icon when available and the existing quality rim. Names keep their received
color; exact native item quality supplies a color only when the message has none.
Unavailable icons and their rims are omitted, with text using the freed space.
Names may wrap within the native-style two-line name area. No tooltip, click
handler, roll button, sound, collection subtitle or slot line is added.

Explicit native **already collected** status is rejected before queueing,
metadata resolution or sequence assignment unless SDUI mode's enabled marks
option accepts a positive integer conversion. `IsMarkReward` and `CanShow`
share that eligibility between intake and the view; collection identity stays
`collected` and never becomes a new-item claim. Regular chat hides that explicit `collected`
result unless a positive marks conversion was supplied. The conversion shows
`+ [Item] +1 Mark` in chat, keeping native brackets, links and item color while
omitting the collection suffix, independently of the popup choice. Zero-reward
duplicates remain hidden; raw diagnostics retain the input.
Absent collection status stays unknown and is eligible; no collection database
or item-name inference decides whether a drop is new.

Cards fade in over 0.2 seconds and begin a 1.5-second fade at age 4.05, following
the inspected retail alert timing. The pool stacks upward in occurrence order,
80 units apart, and waits when all three cards are occupied. Its separate
cosmetic updater runs only while cards exist, including while Layout hides the
group, so hidden cards expire normally. Exact-reference metadata can retry at
0.2-second intervals for the first two seconds. A cosmetic update failure clears
the view and marks it unready, releasing native ownership on the service tick.

The shared `lootNotifications` Layout group starts centered above the default
action bar, with its bottom silver border meeting the action artwork's top edge.
The anchor uses static `DFRL.actionBarDefaults`: `bottom + height + topInset`,
minus the loot crop's 12-unit bottom padding. With a native 36-unit button height,
the shared border is at 105 and the loot frame's bottom is at 93 UI units.
Both groups remain independently movable; moving or resizing the action bar
does not change the loot group's default or confirmed position.

The loot edit bounds stay 276 by 256, with additional cards stacking upward.
Existing move, uniform resize, hide, Confirm, Cancel, discard and reset behavior
applies. Existing confirmed/draft geometry is retained; both full resets use the
new default. Only confirmed geometry uses the existing `SurvivorsDragonUiLayout`
table. The two display choices above add no SavedVariable.

## Shared message intake

`DFRL.messages.ParseLootMessage(text)` is the shared self-loot parser,
extracted as a side-effect-free shared function. `PrettifyMessage` uses its
`chatText` result, preserving the current `+Item` chat wording, hyperlinks,
quality colors, collection suffixes and unknown-message fallback. The native
fourteen-language lookup and English compatibility fallback remain shared.
No additional collection database or item-name list is introduced.

An accepted record contains:

- `name`: the displayed item name without link/color markup or display brackets.
- `label`: the existing compact item label with its original link/color markup.
- `itemReference`: the original inner `item:...` payload, when present.
- `color`: the original eight hexadecimal color digits, when present. This is
  a color, never evidence for an inferred item-quality index.
- `collection`: `collected`, `new`, or absent when no status was supplied.
- `collectionText`: the supplied localized status without color markup or the
  final sentence period. Collected parentheses remain part of the supplied text.
- `marks`: the received positive integer text from a collected item's marks
  suffix, when supplied. It is not a queried balance or an inferred reward.
- `item` and `suffix`: the received item markup and recognized collection suffix
  used by the optional chat formatter. Only the enabled chat wrapper adds
  `chatText`, the exact compact chat result including its existing plus prefix.

The parser and native delivery deduplication live in `core/messages.lua`, outside
custom chat initialization. With **Use default chat** enabled after reload, the
existing loot controller subscribes to `CHAT_MSG_LOOT`/`CHAT_MSG_SYSTEM` only
while SDUI loot intake is active. Game/Off mode, unready/released ownership and
world cleanup detach that intake. No native chat `AddMessage`/`OnEvent` wrapper,
capture collector or Copy dialog is needed. Custom-chat mode keeps its existing
raw-delivery observation and does not add those service message subscriptions.

Unknown suffixes still decline the match. Item and collection state are copied
from the received notice, never inferred from names, inventory, item quality,
equipment changes or a saved collection. Only native self-loot notices on the
system/loot channels and the already-supported direct native chat writes qualify;
other chat channels cannot create a popup.

`modules/chat/capture.lua` remains the single raw Lua chat intake. Its shared
per-frame delivery counts identify copies delivered to additional chat windows
in the same native UI tick. Both raw event diagnostics and the optional loot
consumer use that same decision. Distinct identical messages delivered twice to
one frame remain two occurrences, including within the same tick. The loot
consumer also collapses direct-write copies across frames; diagnostics retain
all direct writes as before. There is no amount summing, item grouping, timeout
deduplication window or second event-based loot producer.

This observes messages that reach the existing Lua `AddMessage` hook. It does
not claim access to renderer-only writes that bypass that hook. The supplied
screenshots establish that the example item messages already reach our compact
chat path, not that every native loot-notice variant has been observed.

## Renderer contract

`modules/ui/loot.lua` registers the shared `DFRL.loot` service without a renderer
or an OnUpdate handler. The selected `LootView` module attaches after the service
and Layout initialize. Attachment requires loaded card textures and usable fonts;
until the registered renderer reports ready, native visibility is retained.

Each pooled card retains its last successfully bound icon, color and text
placement. Metadata retries keep their original timing, while unchanged results
skip texture, text, color and anchor writes. Failed icon assignments remain
retryable, and retiring a card clears its icon binding before reuse. Opacity is
written only when the existing fade curve changes; the full-opacity hold and
hidden-card retirement retain their original lifetimes.

The view registers one object through `SetRenderer`:

```lua
DFRL.loot.SetRenderer({
    IsReady = function() return viewIsReady end,
    Push = function(entry) return acceptIntoVisiblePool(entry) end,
    Clear = function() clearVisiblePool() end,
})
```

Callbacks are plain functions, not methods receiving `self`. `IsReady` must
return the boolean `true` only after the real view and its resources are ready.
`Push` receives a fresh record and returns `true` once the chosen view accepts
that occurrence. A false/nil return leaves it queued while the view is full.
The renderer must not replace its registration from inside these callbacks.
An exception in `Push` clears the view/queue, detaches the renderer and releases
SDUI native-visibility ownership. An unready SDUI renderer also releases it.
`SetRenderer(nil)` explicitly detaches the custom renderer; a selected Game/Off
mode still owns its explicit native visibility. `IsActive()` reports successful current
takeover; `Clear()` clears queued and visible notices without changing the
registered view or its readiness.

The session queue retains the latest 32 occurrences and delivers at most four
every 0.2 seconds. Each has its own increasing `sequence` and cosmetic
`receivedAt` UI time. Overflow retires the oldest queued notice; it does not
alter chat or actual item acquisition. Arrays are synchronized through
`table.setn` for Lua 5.0. Nothing is replayed from before attachment, world leave,
logout or reload. The selected renderer owns its visible pool, text, animation,
lifetime and shared layout registration.

## Native item metadata

`Resolve(entry)` returns a fresh record, preserving the original name and color.
It first feature-detects `GetItemInfo` and passes only the exact original
`item:...` reference when supplied. Successful native data can add `quality`,
`equipLoc`, localized `equipText` and `icon`. An icon records `iconSource =
"native"`. No item id or substitute item is guessed.

Native self-loot notices also arrive as colored names without links. These
previously returned before any icon lookup. The generated native gear catalog
now supplies exact name/icon metadata in all fourteen languages, following the
SCT catalog approach. Native class captured through `UnitClass("player")` at
delivery can refine same-name variants within that source. Generated matches
record `iconSource = "catalog"`; they supply no inferred quality, slot or item id.
Missing/conflicting mappings stay unavailable. Details, the reported Novice's
Circlet join and pinned extraction evidence are in [LOOT-ICONS.md](LOOT-ICONS.md).

Linked notices retain the existing bounded metadata retries even while showing
a catalog icon, so a later native template can replace the weaker fallback.
The view omits unavailable fields and `Push` may receive partial metadata.

The inspected base-client implementation is
[`item_stats.rs` at `f55bb79b1343629df2705d9e4207a7612a886253`](https://github.com/samwhosung/benilla/blob/f55bb79b1343629df2705d9e4207a7612a886253/crates/benilla-ui/src/script/item_stats.rs).
Its argument parser accepts an ID or inner `item:` reference and rejects an
entire colored hyperlink/name. Its nine returns put equipment location eighth
and icon ninth. This establishes the inspected base-source contract, not that
the packaged game's exact custom items currently publish every field. The
screenshots' native icons and slot headers are not proof of Lua item metadata.

## Native HUD ownership and cleanup

The supplied [official API](AzerothSurvivors-Addon-API-2026-10-15.txt) identifies
`loot` / `hudLoot` as the native boss-loot notice and states that these preferences
are saved. The service uses only feature-detected `AZS_IsHudShown("loot")` and
`AZS_SetHudShown("loot", ...)`. It captures the original boolean separately
from an uncaptured preference, hides only after explicit renderer readiness and
confirms the setter through the getter. Missing/invalid API data leaves the
service inactive.

Internal writes guard synchronous `CVAR_UPDATE` callbacks. An observed later
external `hudLoot` change updates the preference to restore; the active custom
view still owns suppression. Release restores the captured/latest preference
only while native visibility still matches our hidden state, preserving an
originally hidden choice and a later visible external value. World leave,
logout, detach, unready/faulted views and the wrapped real `ReloadUI` clear
transient data and release ownership. The reload wrapper restores native
visibility before the game's normal save. World leave/logout/reload stop the
update handler; world entry reapplies the selected mode.

The same owner now accepts an explicit target boolean: its existing argument-free
`Acquire()` still means hidden, while loot's Game mode uses `Acquire(true)`.
It retains the original/latest external preference across mode previews, so
Cancel does not permanently enable a previously hidden native box. Failed
handoffs retain the last and attempted owned states for restoration. Synchronous
CVar callbacks remain guarded. No native visibility write occurs when the getter
already matches. Game/Off detach the service updater after a successful handoff;
only unsuccessful native handoffs retry on its existing 0.2-second controller.
Both skip custom parsing, item metadata, queueing, card animation and painting.

Accepted conversion cards reuse the original item icon/name/quality, card regions
and lifetime. Their extra text is cached by item name/amount and invalidated on
language change or retirement; no new icon, currency art, balance getter, saved
reward history or independent marks popup is added. Failed optional icons retain
the existing retry policy and hidden cards keep their original expiry behavior.

Other HUD parts, compact chat, raw diagnostics, loot rewards and collection
progress keep their existing ownership. No native frame is guessed, no globals
for item acquisition are replaced, and no gameplay data is saved.

## Artwork and verification

The original proposals follow the supplied common-item collected/new notices
and earlier epic-item notice. Their representative icons and Georgia font are
historical proposal choices. The selected preview contains only eligible drops
and uses the installed game's Friz Quadrata. Its icons remain representative,
not verified assignments for custom game items. Static previews are not client
captures and do not establish native metadata or runtime rendering.
Exact files, crops, expansion evidence and reuse notices are in
[Loot notification artwork](../third_party/LootNotifications-ARTWORK.md).
`scripts/preview_loot_designs.py` prepares the archived static artwork proposals.
`scripts/prepare_loot_art.py --sources <scratch> --font <native-friz-path>` repacks
the selected crop and composes the selected static preview; it executes no Lua.
Original downloaded files remain separate in a temporary source directory.
The runtime manifest contains the shared service, selected view and single
Toast TGA. Gallery images, originals, proposal data and example icons do not ship.

Local tests, syntax checks, formatting tools and addon/game execution remain
unauthorized and were not run. GitHub Actions provides the authorized static
formatting/dead-code/version checks. Runtime functionality and exact visual
parity still require permitted game validation.
