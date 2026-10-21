# Loot notification preparation

The user will choose the visual design. The four static proposals are in
[the gallery](designs/loot-notifications/index.html) and
[comparison sheet](designs/loot-notifications/comparison.png). No proposal,
placeholder view, popup geometry or extra artwork is selected for the runtime.
The native loot notice remains available until a real renderer registers and
explicitly reports that it is ready.

## Shared message intake

`DFRL.CleanerChat.ParseLootMessage(text)` is the existing self-loot parser,
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
- `chatText`: the exact compact chat result, including its existing plus prefix.

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

`modules/ui/loot.lua` registers the design-independent `DFRL.loot` service. It
starts without a renderer and without an OnUpdate handler. No `hudLoot` read or
write, item lookup, card, sound, layout group, setting or saved field is started
by the current preparation.

The chosen view will register one object through `SetRenderer`:

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
native visibility ownership. An unready renderer also releases ownership.
`SetRenderer(nil)` explicitly detaches; `IsActive()` reports successful current
takeover; `Clear()` clears queued and visible notices without changing the
registered view or its readiness.

The session queue retains the latest 32 occurrences and delivers at most four
every 0.2 seconds. Each has its own increasing `sequence` and cosmetic
`receivedAt` UI time. Overflow retires the oldest queued notice; it does not
alter chat or actual item acquisition. Arrays are synchronized through
`table.setn` for Lua 5.0. Nothing is replayed from before attachment, world leave,
logout or reload. The chosen renderer will own its visible pool, measured text,
animations, lifetime and shared layout registration; those choices remain open.

## Native item metadata

`Resolve(entry)` returns a fresh record, preserving the original message name
and color. It feature-detects `GetItemInfo` and passes only the exact original
`item:...` reference. It never queries by a guessed item name or substitutes a
different item. Successful native data can add `quality`, `equipLoc`, localized
`equipText` through the corresponding native `INVTYPE_*` global, and `icon`.
Missing templates, empty values, getter errors and question-mark fallback icons
remain unknown. Bracket-only announcements supply no item reference and therefore
cannot acquire an icon or slot by this route. The view must omit unavailable
fields rather than inventing them. `Push` may receive partial metadata;
the selected view may call `Resolve` again for an active occurrence at a bounded
cadence if its template becomes available later.

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
update handler; world entry can reacquire an already registered, ready view.

Other HUD parts, compact chat, raw diagnostics, loot rewards and collection
progress keep their existing ownership. No native frame is guessed, no globals
for item acquisition are replaced, and no gameplay data is saved.

## Artwork and verification

The sample cases follow the supplied common-item collected/new notices and the
earlier epic-item notice. Preview icons are representative published WoW icons;
Georgia substitutes for game DEFAULT. The previews are not client captures and
do not establish native metadata, font metrics or rendering.
Exact files, crops, expansion evidence and reuse notices are in
[Loot notification artwork](../third_party/LootNotifications-ARTWORK.md).
`scripts/preview_loot_designs.py` prepares only these static artwork proposals.
Original downloaded files remain separate in a temporary source directory.
Only the new Lua service joins the runtime manifest; gallery/source data do not.

Local tests, syntax checks, formatting tools and addon/game execution remain
unauthorized and were not run. GitHub Actions provides the authorized static
formatting/dead-code/version checks. No runtime functionality or final visual
parity is claimed before design selection and permitted game validation.
