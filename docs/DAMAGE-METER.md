# DPS meter

The custom meter uses the original Details! **The War Within** header, bars and
background artwork in a native SurvivorsDragonUi window. Details and its skin
addon do not need to be installed.

## Required native API

All four views require the [native version 1 API](DAMAGE-METER-AND-INSTANCE-PLAYER-POSITION-API.md#3-version-1-implementation-contract).
`core/meter_api.lua` is the only meter data boundary. Missing, incomplete,
unsupported or unreadable API data leaves the custom meter unavailable and
leaves or restores the game's native meter preference. There is no older-client
meter fallback. Navigation and language compatibility remain independent.

The meter does not read the old `AZS_GetMeter`, `AZS_GetHealing`,
`AZS_GetBossMeter` or `AZS_GetPartyMeter` counters, their packet tables or receipt
stamps. It keeps no local cumulative ring, recent-DPS model or reset baseline.
SCT combat intake, name/icon resolution, equipment scans and live party-unit
matching do not supply meter data.

Native snapshots provide stable row/source/owner IDs, complete source descriptors,
class metadata, totals, shares, order, rates and average rates. Names and artwork
come from those descriptors, including equipment, jewelry, learned talents,
pet/totem attacks and periodic effects in each native language. Identical names
remain separate when their native IDs differ. Current-loadout reads are not
needed to recover historical source metadata.

Damage Done requests the selected recent window or All. Healing Done retains
the native received-healing semantics. Boss Damage requests the current/last
native encounter. Party Damage requests native owner totals and retained hero
portraits. The selected snapshot supplies every displayed counter and rate;
Lua time controls only the existing presentation cadence.

## Everyday controls and saved choices

The meter is **off by default**. Enable **Enable damage meter** under `/sdui` →
**Damage meter**, then Confirm. Preview, Cancel, world/logout/reload discard,
profiles and both full resets keep the shared display lifecycle. Missing or
invalid `meterEnabled` is false; both full resets turn it off. Turning it off
clears the custom view and releases its native HUD ownership.

Click the heading to cycle Damage Done, Healing Done, Boss Damage and Party
Damage; right-click goes backwards. Deferred navigation skips views still
waiting for usable native data. Valid empty snapshots and explicit unavailable
states retain their own presentation. The gold header normally shows Total and
DPS, or HPS for healing; hovering identifies the selected view. Missing numeric
values use `--`.

**Abilities shown** controls the scrollable viewport from 1 to 10 rows, default 6. Complete native totals and rankings do not depend on the visible row count.
Scroll over the window to see more sources. The existing visibility options
control ability totals, DPS/HPS, percentages, icons, ranks and both header
fields independently. Ability DPS, icons and both header fields default on;
ability totals, percentages and ranks default off. Turning both header fields
off shows the view name. Hidden numeric fields reserve no column; disabled
icons hide the icon and rim and skip all binding work. Hover retains full native
names and values.

**DPS window** defaults to ten native run seconds. The minus/plus controls select
5–120 seconds in five-second steps, with All below five. `meterDpsWindow` remains
ten by default, zero for All, or a finite rounded/clamped value in `5..120`.
The native API calculates recent and whole-run/since-Reset rates. Missing native
history stays unavailable; the addon does not reconstruct it. The window choice
previews and uses the existing Confirm/discard/profile/reset paths.

The small gold **X** captures one native checkpoint for every view. It is a
session reset, independent of Confirm, and never changes gameplay effects or
the game's counters. Capture is synchronous and atomic: failure preserves the
previous session and visible values. Successful replacement releases the old
checkpoint, clears displayed rows/rates/scroll state and requests native
post-checkpoint values. No getter-based local baseline is captured. Invalidated
checkpoints block pre-reset replay until another Reset or normal session
retirement. Language changes retain the checkpoint; world/run retirement,
disabling and full resets release it. Failed releases retry through the existing
controller without collecting meter data while disabled.

All existing setting defaults, saved display keys and profile fields remain.
No native counters, row history, checkpoints, portraits or gameplay state are
saved or included in profiles.

## Layout, text and artwork

The **DPS meter** Layout group retains move, scale, hide, Confirm/Cancel/discard,
profiles and both resets. Left/right handles change width; top/bottom handles
change the same 1–10 row choice; corners scale proportionally. Default scale is
0.8, width 240 UI units, anchored flush to UIParent's bottom-right. Width limits
remain 120–960. Root geometry can update for editing while hidden/off without
starting meter data collection.

**Name font size** and **Number font size** remain independent 8–18 display
integers, default 11. Missing older name-size preferences inherit the normalized
number size. Names and values follow the shared Layout face, outline and shadow;
font-size changes compare the effective flags and retain failed-binding retries.
The header retains its gold color and existing size offsets.

Rows remain 32 units high, with 26-unit icons and 31-unit gold rims. Numeric text
uses its actual glyph width, rounded up with one unit of clearance and a
five-unit gap; names receive the remainder with a 48-unit minimum. Disabled
values leave no empty columns. Latest successful measurements are keyed by
caption, actual font face/size/flags, owning-frame scale and available width.
Missing metrics retry while visible; hidden/off/disabled-number views skip
measurement. Row retirement clears presentation caches.

Source artwork binds the exact native descriptor icon. Party rows use
`AZS_SetMeterPortrait` with native run/portrait IDs, without looking up current
units or matching names. Missing/pending artwork uses the shared neutral image.
The shared circular renderer prefers a usable native circle and retains its
lazy physical-pixel strip fallback. This drawing fallback is also needed by pet
icons; it does not read old meter data. Permanent failures wait for identity
change or retirement, while typed transient failures respect native retry delays.
Pool retirement clears native and strip-backed images without adding a frame,
model, asset, setting or worker.

## Ownership and lifecycle

The common HUD owner captures `meter` / `hudMeter` only after API, renderer,
Layout registration and selected snapshot readiness are established. Invalid or
missing API/data, render failure, world leave, logout and wrapped ReloadUI
release suppression and restore the captured/latest external preference,
including an originally hidden native meter.

The existing five-Hz reader owns visible native snapshots and deferred view
selection. At most four reusable per-pass results coalesce selection and
presentation; native result references are released after the pass, including
failures. Clicks retain navigation intent without reading snapshots. X alone
uses the synchronous native checkpoint action. Native context and explicit
run/authority/epoch/encounter IDs retire stale data; packet receipt heuristics
are absent.

Displayed DPS/HPS and tooltip rates retain one-Hz presentation. Their values are
native results keyed by stable row IDs, rather than names, roster slots or
locally observed counter changes. Changed native metadata and language refresh
captions/artwork without changing ownership or counters. Layout-hidden views
read context only for phase/session retirement and required ownership/cleanup;
they never fetch row snapshots, including initially hidden or newly dirty views.
They skip formatting, text measurement, icon binding, bars and tooltip repaint.
Previously acquired valid native HUD suppression remains while Layout-hidden;
unavailable context releases it. Showing reads fresh native snapshots.
Off detaches collection; only pending native HUD/checkpoint cleanup may keep
the controller running until settled. Both Performance Mode states share the
same instant information and artwork.

The native API owns damage accounting, recent windows, ordering, source identity
and reset semantics. There is no combat-event intake, damage log, private rate
clock, gameplay SavedVariable, extra event or extra updater. Independently opted-in
`/copy` diagnostics remain outside the meter's ownership.

## Artwork and verification

The meter retains the pinned Details skin pixels and original MIT notice in
[DetailsTWW-ARTWORK.md](../third_party/DetailsTWW-ARTWORK.md). Gold icon rims reuse
the prepared pet-rim crop in `media/tex/jewelry/Frame.blp`; header X states reuse
`character/Close.blp`. Full-resolution TGA inputs remain authoring assets, while
only the prepared lossless BLP artwork ships. Region and strip cost bounds are
recorded in [PERFORMANCE.md](PERFORMANCE.md#meter-drawing-audit--2026-10-26).

CI-only mocks cover the real v1 adapter, meter UI, retained portraits, native
rate windows/checkpoints and cleanup/visibility lifecycles. Legacy endpoint
boundaries fail if called. Source review and pinned formatting are the local
checks; no local tests, standalone validation or addon/game execution were run.
Mocked behavior does not prove the future game's API delivery, rendering or FPS.

## Historical compatibility research

Earlier releases consumed the 2026-10-22 getter/packet API, calculated bounded
rolling rates and post-reset deltas locally, resolved icons from source names
and matched party names to current units. That data compatibility code is
removed. The owner-supplied [API reference](AzerothSurvivors-Addon-API-2026-10-22.txt)
and the [version 1 design analysis](DAMAGE-METER-AND-INSTANCE-PLAYER-POSITION-API.md)
remain useful evidence of why complete native identities, metadata and native
checkpoints are required. They do not describe a fallback still shipped by the
meter. Public-addon research in [SOURCE-ICONS.md](SOURCE-ICONS.md) retains its
historical scope; current SCT metadata remains independent.

## Historical healing-icon provenance

This section records the retired name-based meter investigation. None of these
name/icon mappings supplies the current meter; version 1 descriptors are its
only metadata source. The extractor remains a data-only research tool outside
the runtime payload.

The older official meter's icons were internal to the client. In the inspected build,
`AZS_GetHealing()` returns `AZS_HEALING` through `AZS_MeterTotals`, and the native
`AZSHEAL` parser supplies only `name`, `dmg`, `dps`, `share` and `proc`. It does
not expose the icon field carried by the game's original healing records.
Earlier SDUI therefore reused the exact native record pairs below through its
former meter name bridge, without scraping window rows. Current v1 snapshots
supply their own descriptors instead.

| Native healing source | Native icon basename         | Name instruction | Icon instruction |
| --------------------- | ---------------------------- | ---------------- | ---------------- |
| Regeneration          | `Spell_Nature_Rejuvenation`  | `0x145b772ba`    | `0x145b7730c`    |
| Leech                 | `Spell_Shadow_LifeDrain02`   | `0x145b7c92c`    | `0x145b7c963`    |
| Healing on Kill       | `Spell_Shadow_DeathPact`     | `0x145bc12b9`    | `0x145bc12f7`    |
| Level Up              | `Spell_Holy_HolyBolt`        | `0x145b8ef63`    | `0x145b8efdf`    |
| Soul Link             | `Spell_Shadow_GatherShadows` | `0x145b79c8e`    | `0x145b79cc2`    |

These records had the native proc flag off. The former compatibility resolver
matched their exact English/active-language captions for non-proc healing rows.
That resolver, its special healing table and the meter's SCT lookup are removed.

The source executable is SHA-256
`291c281bd0a4255fdb3d04b2e442121e2df144f388f16de086b430e875aaad08`.
`scripts/extract_meter_healing_icons.py` reads the five actual producer
instructions, encoded string lengths and record-consumer calls from that pinned
file, plus the five exact captions in all fourteen embedded language catalogs.
It rejects other builds before interpreting offsets. The original healing
record consumer is `0x145bf4d30`; Healing on Kill first passes its record through
`0x145b7c8a0`, whose default source is Leech. The other listed producers feed the
shared meter record consumer directly. This is static data
evidence, without executing the client or addon.

```sh
python3 scripts/extract_meter_healing_icons.py \
  --client /path/to/AzerothSurvivors.exe \
  --output /path/to/healing-icons.json
```

The output preserves producer instructions and reviewed captions for research.
It is not an input to current meter rendering or a reason to restore the retired
compatibility path. Native texture paths remain Blizzard artwork; no executable,
DBC or extracted bitmap enters the payload.

The user requested a cross-check against AzerothSurvivorsRE. Its
`docs/analysis/run-meters-0.105.0.md` describes the internal icon-bearing ledger,
name/proc row identity and retention of the first admitted icon.
`docs/analysis/player-totem-passives-0.97.2.md` records the generic Leech fallback;
`crates/azeroth-survivors-re/src/run_effects/healing.rs` identifies Regeneration,
Leech and Soul Link, and `gameplay/mechanics.rs` records the Level Up pair. Those
references led to the additional Soul Link producer above, independently checked
in the installed executable. The retained `0.120.0/embedded-api.lua` evidence
also still exports the same five healing fields without an icon.
Historical reconstruction notes guide the search; the installed client's pinned
instructions establish these actual pairs. Arbitrary future/ambiguous row icons
cannot be recovered exactly from names alone when the native ledger's first
icon is not published through the API.
