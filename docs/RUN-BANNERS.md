# Run banners

`modules/ui/banners.lua` displays native notices in its own **Banners** frame. It
uses the same resolved DEFAULT face, size 12, OUTLINE and black shadow as chat,
through the shared helpers in `core/fonts.lua`. The supplied translated text is
displayed unchanged except for the requested full guardian-death wording below.
The native `boss` flag selects red text; other notices use
gold. No icon, backdrop, sound or gameplay lookup is added. The Layout caption
uses the existing fourteen-language source/runtime catalogs.

## Placement and lifetime

Three passive pooled labels share an independent UIParent-owned root, centered
in a 420-unit text column. Native wrapping and measured label height determine
the space between rows. They fade in over 0.15 seconds and fade out over 0.6
seconds after 3.5 seconds. UI time controls only their cosmetic lifetime.
Cosmetic painting is limited to 30 Hz; ownership retries run at five Hz.

Select **Banners** through `/sdui` or `/sdui lock` to move, scale or hide this
group independently. The shared Layout editor supplies numeric coordinates,
drafts, Confirm, Cancel, discard and both full resets. Only its confirmed
geometry/visibility is saved under `SurvivorsDragonUiLayout.banners`; there is no
new SavedVariable or persisted message data. Bounds fit the current stack with
a 16-unit empty minimum. Timer font settings affect the timer captions only;
banners retain chat's shared style.

The timer's original edit bounds and the boss group's original default top
offset of 77 units are restored. Banners default to 130 units below the screen
top, beneath the first default boss row. They reserve no space inside either
group and do not rewrite confirmed or draft geometry. Their default top remains
stable as measured text height changes; custom positions retain their shared
Layout center semantics. Move the independent banners if a taller boss stack or
a custom HUD position occupies the same area. Full resets clear notices and
restore these independent defaults.

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

| Native kind   | Notification                      |
| ------------- | --------------------------------- |
| `boss`        | Regular boss approaching          |
| `finalboss`   | Final boss arriving               |
| `bossdown`    | Boss defeated                     |
| `guardian`    | Guardian slain                    |
| `achievement` | Achievement earned                |
| `unlocked`    | Zone opened                       |
| `magnet`      | Magnet appeared or collected      |
| `cache`       | Cache hints and purchase feedback |
| `rune`        | Rune notification                 |

All supplied kinds use the same text path, including future unknown kinds.
Guardian-slain notices also have `boss == true`; the flag is not used to infer
an entity type, spawn, health, reward or encounter state. No message is inferred
from chat, a boss list, a countdown or an item acquisition.

The native message prefix is `AZSBANNER`, with ordered fields
`id=...;kind=...;boss=...;name=...;text=...`. The game's embedded API owns parsing
and dispatch. This addon does not install another raw event producer.

## Ownership and cleanup

Native takeover requires initialized fonts, the registered independent Layout
root, all four public banner/HUD functions and successful callback registration.
Only then is `AZS_SetHudShown("banners", false)` applied and checked through
`AZS_IsHudShown("banners")`. Missing APIs or an unready/faulted view leave native
visibility available. Registration no longer waits for a valid run clock, so
opening notices can arrive before native run snapshots. Hiding the Run timer
does not hide Banners; its own Hide frame choice applies while cosmetic
lifetimes continue normally.

`core/hud.lua` shares the capture/write/observe/release logic with loot notices.
It distinguishes an uncaptured preference from an originally hidden preference,
guards synchronous CVar callbacks and retains later external `hudBanners`
choices for restoration. The last visible external value also wins on release
when native visibility no longer matches this addon's suppression.

World leave, logout and the wrapped real `ReloadUI` unregister
the callback, clear the queue and labels, and restore the captured/latest native
preference before reload saving. New `AZSZONE` messages clear transient notices
without reading native tables before their parser. Both full resets clear them
through their own shared Layout reset callback. Clock release does not release
this independent group. No banner data is saved.

## Legacy raid-boss notices

The large cream notices use a second native display surface. They are not the
custom HUD controlled by `hudBanners`. Read-only extraction from the installed
`Data/patch.MPQ` recovered:

- `Interface\\FrameXML\\ChatFrame.lua`, 73,083 bytes, SHA-256
  `f224ac3ec8805da02a8e1b8f70bb19fe956fc8c2b451a3692afc17c28f715f9d`.
  Its lines 1453–1457 format the received raid-boss emote and call
  `RaidBossEmoteFrame:AddMessage(body, info.r, info.g, info.b, 1.0)`.
- `Interface\\FrameXML\\RaidWarning.xml`, 1,241 bytes, SHA-256
  `9e5cba537a3cc0cf91b447ae30d60efe066abba3285b52f7b518c19094241860`.
  It defines that separate native MessageFrame with `GameFontNormalHuge`.

While the replacement is active, both the regular-chat receipt of
`CHAT_MSG_RAID_BOSS_EMOTE` and a reversible per-frame
`RaidBossEmoteFrame:AddMessage` wrapper send already formatted text into the same
bounded queue. The regular-chat path queues its received text instead of
assuming the legacy wrapper already delivered it. This includes zone openings,
waves, elite arrivals, lair returns and other legacy warnings.
No notice is reconstructed from a zone subtitle, clock, chat history or gameplay
state. Unknown native text stays unchanged. The two exact native templates for
boss entry and guardian death already have official API publications; their
legacy display companions are suppressed rather than shown a second time.
Template matching uses the existing native catalogs in all fourteen languages,
without entity-name lists, fuzzy wording or temporal pairing.

For a received official `kind == "guardian"` publication with a nonempty native
`name`, the addon uses the original full guardian-death template from the same
fourteen-language catalogs: **%s is slain! Its lair yields treasure and its
strength, and the other guardians grow stronger.** Only the received guardian
name fills its placeholder. This replaces the API's shortened **Its hoard and a
level.** wording while preserving its native ID, boss flag, queue order and
lifetime. Missing names or failed formatting retain the supplied API text.
The same template constant identifies the suppressed legacy companion, so the
middle-screen copy stays hidden and the full message appears only once in the
custom Banners group. The native publication is not modified, and no gameplay
event or reward is inferred.

Both paths reuse chat capture's delivery decision in one `banners` scope, with
the originating chat frame as source and a separate counter for each delivery
surface. The matching legacy/chat pair and deliveries across chat frames
collapse, while repeated identical messages on the same frame stay distinct.
The official API stream still uses only its native IDs. Ordinary chat, raw
capture, monster yells and the separate raid-warning frame retain their own
paths.

Takeover hides the legacy MessageFrame and clears its existing messages when
the native `Clear` method is available, without replaying them. Reversible
`Show`/`Hide` wrappers retain the prior or latest external visibility choice
while keeping the native surface hidden. While both visibility methods remain
owned, release clears suppressed native messages before restoring that visibility
choice. It restores only owned methods. A later external wrapper is retained; an old wrapper
in its chain becomes a pass-through after release. A failed redirect releases
takeover and forwards the failed call to the native method.

The reported opening capture contains `AZSZONE` before the raid-boss emote
**The Defias Uprising — survive the onslaught!**, followed by its formatted
`ChatFrame1` receipt. There is no `AZSBANNER` publication for that opening. This
rules out zone cleanup erasing that occurrence and establishes an available
formatted intake, but does not record whether the old legacy method wrapper
ran. The shared intake removes that dependency without rebuilding a message
from zone metadata or raw event placeholders.

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

The original API recovery did not recover the final custom-HUD drawing consumer
or complete event drain. The later legacy FrameXML extraction identifies the
second surface separately. User screenshots establish successful custom rune,
guardian and magnet notices alongside a remaining large native guardian notice;
the bridge and independent layout changes still need in-game confirmation.
Menu-only achievement JSON does not establish Lua callbacks outside an
initialized game client.

The TOC and `packaging/runtime-files.json` include the shared owner and banner
module. Edited sources use the pinned local StyLua and Prettier formatters.
Local tests, standalone syntax checks and addon/game execution remain
unauthorized and were not run. The existing PR GitHub Actions job supplies the
static checks; in-game placement, timing and lifecycle remain unverified.
