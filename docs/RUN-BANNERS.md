# Run banners

`modules/ui/banners.lua` displays native banner events below the run timer. It
uses the same resolved DEFAULT face, size 12, OUTLINE and black shadow as chat,
through the shared helpers in `core/fonts.lua`. The supplied translated text is
displayed unchanged. The native `boss` flag selects red text; other notices use
gold. No icon, backdrop, sound, custom translation or gameplay lookup is added.

## Placement and lifetime

Three passive pooled labels are attached six units below the run pill, centered
in a 420-unit text column. Native wrapping and measured label height determine
the space between rows. They fade in over 0.15 seconds and fade out over 0.6
seconds after 3.5 seconds. UI time controls only their cosmetic lifetime.
Cosmetic painting is limited to 30 Hz; ownership retries run at five Hz.

The labels share the Run timer group's position, scale, Hide frame, drafts,
Confirm, Cancel, discard and reset behavior. The edit region includes the
reserved banner area and expands for taller measured messages. Timer font
settings affect the timer captions only; banners retain chat's shared style.
There is no new layout record or SavedVariable.

The default boss-health group starts below the reserved banner area. Its
confirmed and draft geometry remains independent and is not rewritten. Existing
custom boss positions may need to be moved with Layout. Full resets clear the
banner rows and queue and use the new default spacing.

Rows retain occurrence order. A session queue holds the latest 32 waiting
publications; overflow retires its oldest waiting entry. The most recent 128
native IDs prevent repeat delivery of one publication. Different IDs with the
same text remain separate. The original callback table is never modified.
No history is replayed on initialization, attachment, a new run or world entry.

## Native contract

The installed 0.108.0 Windows executable was inspected statically:

- SHA-256: `dc0040043fff7995a9137d96509c08debd1dbf8b0125a935273d718c66cb698b`.
- Size: 140,203,520 bytes.
- Original embedded Lua source: file offsets `0x71eb0cc` through `0x71edfc8`
  exclusive, SHA-256
  `d97cae2cb64675a2b61c2651db6dd6af30bdd18f416bd6d8ab156f955826abf8`.

The public calls are `AZS_RegisterBannerHandler(handler)` and
`AZS_UnregisterBannerHandler(handler)`, using the same function object.
Registration receives future events only. The native API invokes
`handler({ id, kind, boss, name, text, time })` for shown and hidden banners.
`time` is client receipt time, not run elapsed time. `AZS_BANNERS` stores the
newest 20 publications, oldest first; this addon does not consume that history.

| Native kind   | Notification                       |
| ------------- | ---------------------------------- |
| `boss`        | Regular boss approaching           |
| `finalboss`   | Final boss arriving                |
| `bossdown`    | Boss defeated                      |
| `guardian`    | Guardian slain                     |
| `achievement` | Achievement earned                 |
| `unlocked`    | Zone opened                        |
| `magnet`      | Magnet appeared or collected       |
| `cache`       | Cache hints and purchase feedback  |
| `rune`        | Rune notification                  |

All supplied kinds use the same text path, including future unknown kinds.
Guardian-slain notices also have `boss == true`; the flag is not used to infer
an entity type, spawn, health, reward or encounter state. No message is inferred
from chat, a boss list, a countdown or an item acquisition.

The native message prefix is `AZSBANNER`, with ordered fields
`id=...;kind=...;boss=...;name=...;text=...`. The game's embedded API owns parsing
and dispatch. This addon does not install another raw event producer.

## Ownership and cleanup

Native takeover requires initialized fonts, attachment to the run pill, a ready
custom clock, all four public banner/HUD functions and successful callback
registration. Only then is `AZS_SetHudShown("banners", false)` applied and checked
through `AZS_IsHudShown("banners")`. Missing APIs or an unready/faulted view leave
native visibility available. An intentionally hidden Run timer also hides its
banner children, while their cosmetic lifetimes continue normally.

`core/hud.lua` shares the capture/write/observe/release logic with loot notices.
It distinguishes an uncaptured preference from an originally hidden preference,
guards synchronous CVar callbacks and retains later external `hudBanners`
choices for restoration. The last visible external value also wins on release
when native visibility no longer matches this addon's suppression.

Clock release, world leave, logout and the wrapped real `ReloadUI` unregister
the callback, clear the queue and labels, and restore the captured/latest native
preference before reload saving. New `AZSZONE` messages clear transient notices
without reading native tables before their parser. Both full resets clear them
through the existing timer reset. No banner data is saved.

The native handler list is traversed directly. A rendering failure inside a
callback releases native visibility immediately but defers unregistration to
the controller tick, so it cannot shift another addon's callback during the
current dispatch. A failed view stops accepting messages for the Lua session.

## Recovery evidence and verification

REA 6.5.0 / Ghidra 12.1.4 inspected unmodified native code ranges at their original
virtual addresses. The native publisher `0x1459443e0` assigns one publication ID
and queues native JSON and Lua delivery without a HUD-visibility gate. Lua wire
serialization is at `0x1458e3300`; the native JSON serializer is at
`0x1458e3d30`. The separate HUD synchronizer `0x14009f0e0` reads `hudBanners` and
writes HudParts byte `+4`.

Key retained REA Evidence IDs are
`ev_dc2f075ca63fa6f84b6fc9c8c7f7bab3cf4ee4ec9d15fcb64068473445ec8faa`
(publisher),
`ev_92f5e14d8da16b36d47f51e4b313f336a8cc8a1618903fd1235e30b2645b3c94`
(Lua serializer) and
`ev_2b15f443e79f294b2f7e3b7e4541cee0e513fcb11b9ee68be0278309cf56b891`
(boss constructors). Raw imports omit outside code/data and use Ghidra's generic
compiler profile; original Win64 instructions govern argument interpretation.
These addresses are evidence locations, not runtime hooks or callable APIs.

The final native drawing consumer and complete event drain were not recovered.
Static source and native instructions establish the API contract, not observed
delivery or visual parity. Menu-only achievement JSON does not establish Lua
callbacks outside an initialized game client.

The TOC and `packaging/runtime-files.json` include the shared owner and banner
module. Local tests, syntax checks, formatters and addon/game execution remain
unauthorized and were not run. The existing PR GitHub Actions job supplies the
authorized static checks; in-game placement, timing and lifecycle remain
unverified.
