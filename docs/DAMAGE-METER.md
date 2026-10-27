# DPS meter

The meter uses the original Details! **The War Within** header, progress-bar and
background artwork in a native SurvivorsDragonUi window. Details and its skin
addon do not need to be installed.

The custom meter is **off by default**. Turn on **Enable damage meter** under
`/sdui` → **Damage meter**, then Confirm. The switch previews live and follows
the shared Cancel/discard/profile paths; both full resets turn it off. Turning
it off hides and clears the custom view and restores the native HUD preference
captured by the replacement. It does not force the game's own meter setting off.

Click its heading to cycle through Damage Done, Healing Done and Boss Damage;
right-click goes backwards. The gold header shows **Total** and **DPS** (or **HPS**
for healing), replacing the view name and the former footer text. Hover over the
header to see the current view. Missing data displays `--` for both values.
Under `/sdui` → **Damage meter**, set **Abilities shown** from **1 to 10**;
the default is **6**. The number previews immediately and saves with Confirm.
Cancel, world/logout/reload discard, profiles and both resets use the shared
display lifecycle. Only views with a native getter are offered. Scroll
over the window for more sources. The settings use two columns. Rows show the
native source name, DPS/HPS and gold-ringed icon by default; ability totals,
percentages and ranks start off. **Ability damage**, **Ability DPS** and **Ability
percentage** control those three row values independently. **Ability icons**
and **Ability ranks** control the gold-ringed icons and list numbers. **Header
total** and **Header DPS** control the summary; turning both off shows the current
view name. Both header fields start on. All seven options use the same preview, Confirm,
Cancel, profile and reset behavior. Healing uses healing totals and HPS.
Hover still provides the full name and numbers when row values are hidden.
Move, scale or hide **DPS meter** through `/sdui` → **Layout**, then Confirm.
Geometry and hiding also work
with named profiles, Cancel, `/sdui lock` and both full resets.

The default scale remains **0.8**. The base width is **320** UI units, reduced
from 400 by 20%, without changing row height, icon sizes or fonts. Its bottom-right
corner sits at the screen's bottom-right corner with no offset. Shared layout
registration captures this scale before applying saved geometry. These defaults
apply to unset geometry and both full resets; existing confirmed/draft positions
and scales keep using the shared layout rules. The default corner stays fixed
when the ability count changes, without an updater or geometry migration.

## Native data

`meterEnabled` is a normalized boolean in the existing display table. Missing
or invalid values use false, including older configurations without the key.
While disabled, there are no meter/phase reads, drawing or idle OnUpdate. The
meter unsubscribes from `CHAT_MSG_ADDON` and stops tracking meter publications.
Turning it off clears copied rows, rate samples, header numbers, row text and
fills, hover data and receipt flags. Re-enabling retires the prior snapshot and
requires a fresh selected publication before accepting native data; it never
reads missed publications or keeps a private off-period history.

If restoring a captured native preference temporarily fails, only that cleanup
retries through the existing controller; it stops once released. `CVAR_UPDATE`
is observed only while enabled or completing that HUD restore. World/logout/
reload lifecycle cleanup remains registered, without collecting meter data.
Enabling schedules reads through the existing controller, without a private
gameplay clock, new event or extra updater. The saved enabled choice changes
only with Confirm.

The meter has no combat-event intake, damage log or gameplay SavedVariable.
The game's native run totals continue independently and can include time when
this replacement was off. The separately enabled `/copy` diagnostic logger can
capture general native addon messages; the meter neither enables nor controls
that opt-in logger.

The owner-supplied [2026-10-22 API reference](AzerothSurvivors-Addon-API-2026-10-22.txt)
defines `AZS_GetMeter()`, `AZS_GetHealing()` and `AZS_GetBossMeter()`. Each returns
`lines, total, rate`; rows supply `name`, `dmg`, `dps`, `share` and `proc`.

Damage and healing cover the whole run. Their rates are the game's averages over
its pause-aware run clock. Boss Damage covers the native current/last boss fight.
The renderer does not divide damage by UI time, estimate hits from combat text,
implement rolling DPS, subtract local reset baselines or fabricate fight segments.
The native meter window's Reset does not reset these API totals.

The header and source-row DPS/HPS values, including row tooltips, sample the
native rates once per second. Totals, shares, bars and interaction retain their
existing five-Hz refresh. A newly seen source displays its first native rate
immediately; sampled row rates follow the exact source name and native proc flag
rather than a pooled row or list position. UI time controls this display cadence
only and never calculates DPS. View changes, invalid data, world cleanup and
resets clear the samples; a regressing native total refreshes them immediately
so an earlier boss fight's rates are not reused after its total resets.

The phase is read before any retained meter data. `ready` clears the view;
`playing`, `choosing`, `paused`, `dead` and `victory` can display valid data.
Each selected snapshot must have finite nonnegative totals, rates, row amounts
and shares, with shares at most one. Source order and names remain native.
Rows are copied for display; native tables are never modified.

Initially a nonempty valid getter result can recover a view whose packet arrived
before addon initialization. Empty lists require their `AZSMETER`, `AZSHEAL` or
`AZSBOSSDMG` publication. A new zone, world leave or ready phase retires the
previous data and requires new publications before accepting that view again.
Packet handlers record receipt only: getters are read after parsing in OnUpdate,
at most five times a second. Paused data has no artificial expiry. Missing native
replay after reload can leave an empty view waiting; no resync API is invented.

The displayed sources belong to the local player's native meter. This is not a
party leaderboard or a port of Details' combat parser. Proc rows keep the native
blue distinction; other rows use the shared player-class palette. Icons use SCT's
existing exact-name metadata resolver independently of SCT's display mode or
filters. Ambiguous/missing icons are omitted. Source icons are circular and use
the existing gold jewelry ring, matching the reference skin's round presentation.
The skin's retail class/spec portraits would misidentify per-source rows and are
not imported.

The ring reuses the pet frames' prepared 72-by-72 region at `(576, 56)` through
`(648, 128)` in `media/tex/jewelry/Frame.blp`, with its original gold color and
alpha. A 31-unit rim surrounds the 26-unit source icon at its existing center;
row spacing, bars, text, hit areas and saved geometry remain unchanged. The
native `SetPortraitToTexture` path binds a named circular texture once per icon.
Clients without a usable native binding fall back to pooled horizontal strips
inside a circular boundary, rebuilding their geometry only when effective scale
changes. A failed native path is remembered until the icon/retirement changes;
failed fallback assignments remain retryable. Retired/cleared rows remove both
paths. No square corner covers, new texture, setting or updater is added. The
existing jewelry renderer and its fourteen-strip sampling remain unchanged.

The native **Melee** source uses the equipped main-hand icon from
`GetInventoryItemTexture("player", 16)`, sharing SCT's auto-attack icon helper.
Unavailable, empty, invalid or question-mark results use the native default
`Interface\\Icons\\INV_Sword_04` sword. Only the exact English label or the
active language's official `Melee` caption matches. Equipment changes are read
through the meter's existing five-Hz refresh, with no new event or updater.

SCT and the meter share one source-icon resolver and live item cache. The
native general-jewelry catalog now covers item-triggered damage/healing such as
**The Eye of Hakkar**, using the actual native item icon. Other unresolved
names can use exact native item-info/inventory metadata with throttled retries.
Unavailable or ambiguous sources show a question mark inside the same gold
ring, keeping a consistent icon column. Hidden/off meters and disabled icons
skip these lookups. No new bitmap or updater is added; see
[SOURCE-ICONS.md](SOURCE-ICONS.md) for source research and coverage limits.

## Native healing icons

The official meter's icons are internal to the client. In the inspected build,
`AZS_GetHealing()` returns `AZS_HEALING` through `AZS_MeterTotals`, and the native
`AZSHEAL` parser supplies only `name`, `dmg`, `dps`, `share` and `proc`. It does
not expose the icon field carried by the game's original healing records.
SDUI therefore reuses the exact native record pairs below through the shared
source-icon resolver, without scraping window rows or guessing from spell names.

| Native healing source | Native icon basename         | Name instruction | Icon instruction |
| --------------------- | ---------------------------- | ---------------- | ---------------- |
| Regeneration          | `Spell_Nature_Rejuvenation`  | `0x145b772ba`    | `0x145b7730c`    |
| Leech                 | `Spell_Shadow_LifeDrain02`   | `0x145b7c92c`    | `0x145b7c963`    |
| Healing on Kill       | `Spell_Shadow_DeathPact`     | `0x145bc12b9`    | `0x145bc12f7`    |
| Level Up              | `Spell_Holy_HolyBolt`        | `0x145b8ef63`    | `0x145b8efdf`    |
| Soul Link             | `Spell_Shadow_GatherShadows` | `0x145b79c8e`    | `0x145b79cc2`    |

These records have the native proc flag off. Match their published names without
checking the player's class; apply the pairs only in Healing Done for non-proc rows.
This also prevents the
generic database's unrelated Level Up icon from replacing the official burst.
Named healing abilities and proc rows retain the complete shared spellbook,
observed-aura, native ability/talent/effect and database lookup for every class;
unresolved or ambiguous extra sources use the shared neutral question mark
rather than borrowing an arbitrary icon. The new exact item metadata is shared
with damage, boss damage and combat text; healing category matching stays scoped
to the native non-proc records.

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

Use its `records` to author the bounded `healingSourceIcons` table in SCT and
its `captions` for the selected native/UI catalogs. Native-caption aliases are
cached once per effective language, with conflicts retained. Icon binding still
uses the existing pooled circular renderer and gold rim, without another asset,
scan, updater, setting or SavedVariable. Disabling the meter or Ability icons
skips these lookups. The built-in client textures remain Blizzard artwork and
are referenced by path only; no bitmap, DBC or executable enters the payload.
Live appearance and cross-class behavior remain unverified.

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

## Ownership and lifecycle

The common HUD owner captures `meter` / `hudMeter` only after the renderer,
layout registration and a selected snapshot are usable. Invalid or missing data,
render failures, world leave, logout and the wrapped ReloadUI release suppression
and restore the captured/latest external preference, including an originally
hidden meter. Its native minimap button belongs to that same HUD preference.
The custom heading remains available when another view has no snapshot. While
waiting for a native publication, the body status is empty and hidden; no waiting
caption or replacement message is shown. The publication gates still reject
retired and initially empty data. Unavailable-data and valid-empty messages keep
their existing behavior. Hiding the Layout group intentionally hides the
replacement while its valid native takeover remains active.

Layout-hidden meter groups retain phase retirement and native ownership. They
validate selected-view data only after a native publication, without copying
view rows or sampling displayed rates. Showing reads current native data again.
They skip cosmetic row formatting, icon lookup/binding, tooltip repaint and bar work.
Requested root visibility changes only on transitions. Repeated unavailable
reads do not keep clearing an already-cleared view. Visible rows cache formatted
values, and a hovered tooltip rebuilds only when its source, displayed numbers,
view, language or effective scale changes; a tooltip taken or hidden by another
native owner is not reclaimed by the periodic update.

The `meterRows` integer belongs to the existing `SurvivorsDragonUiDisplay`
table. Its normalizer clamps finite values to `1..10` and rounds to an integer;
missing/invalid values and both resets use six. Profile snapshots copy the
normalized count with the other display choices, without a new SavedVariable.
Only the visible row limit changes: native source order, complete totals, rates
and the overflow scroll list remain intact.

The seven `meterShowDamage`, `meterShowDps`, `meterShowPercentage`,
`meterShowIcons`, `meterShowRanks`, `meterShowTotal` and `meterShowTotalDps`
booleans extend that same display table and its normalization/profile paths;
missing or invalid values and both resets use false for damage, percentage and
ranks, and true for DPS, icons and both header fields. Existing saved boolean
choices are retained. They change presentation
only. Source snapshots, full tooltip values, native totals/order and one-Hz
rate samples are retained regardless of which fields are visible.

Rows reserve space only for enabled value columns and reclaim the icon gutter
when icons are off, without changing the outer width, row height or saved
geometry. Columns use the narrower shared base width and existing row anchors. Geometry
changes only when the effective icon/column options change. Turning icons off
immediately clears pooled icon bindings and hides icons/rims, skips
resolver/native/fallback binding work and preserves the lazy pools for later reuse. Row formatting caches
track enabled values and an options revision; hidden values do not trigger
formatting. The header similarly caches its visible values, view, language and
options revision. Unrelated display previews skip meter work. No updater or
artwork is added, and all captions/hints have fourteen-language source/runtime
entries.

One seeded row establishes font/artwork readiness. The row pool grows only when
additional visible sources need it, up to the selected limit. Lowering the count
immediately retires surplus rows and clamps scrolling; their pooled widgets are
reused later. The frame/edit bounds follow the selected height only when the
count changes. Shared `refreshDefault` placement keeps the default bottom/right
edge stable and preserves confirmed or draft custom positions/scales. No idle
updater or repeated geometry work is added.

The pooled rows show a scrollable source list. Header mode and scroll
offset are session-only; resets select Damage Done and the first page. One controller
coalesces data reads at five Hz. Bar values, colors, successful icon bindings and
label text skip unchanged writes. If the shared SCT resolver is unavailable,
the meter uses the same neutral unknown icon without changing native totals.
Shared layout storage contains only confirmed geometry and visibility; no meter
data or new SavedVariable is saved. All captions have source/runtime entries in
the fourteen supported languages. The mandatory drawing policy, historical
tradeoffs and the normal/compatibility region budgets are in
[PERFORMANCE.md](PERFORMANCE.md).

## Artwork and verification

Pinned source, license, exact pixel preparation and runtime membership are in
[DetailsTWW-ARTWORK.md](../third_party/DetailsTWW-ARTWORK.md). Only the three
prepared BLPs and the original MIT notice enter the runtime payload; TGA
preparation inputs remain outside it. No Details, Ace3, retail mixin, external
font or new addon dependency is loaded.

Local work is limited to source inspection, artwork preparation and pinned
formatting under the repository workflow. No local tests, standalone syntax or
validation checks, addon execution or game execution were run. Existing GitHub
Actions supplies static checks; live appearance, scrolling, native replay and
preference restoration remain unverified in the packaged client.
