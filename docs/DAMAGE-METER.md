# DPS meter

## Native version 1 data path

Clients implementing the [version 1 contract](DAMAGE-METER-AND-INSTANCE-PLAYER-POSITION-API.md#3-version-1-implementation-contract)
use `core/meter_api.lua` for Damage Done, Healing Done, Boss Damage and Party Damage. The meter reads complete
native snapshots and their authoritative source/hero descriptors. Names and
icons come directly from those descriptors, including equipment, jewelry,
learned talents, pet/totem attacks and periodic effects in every native language.
Native row IDs identify rate samples even when several rows share a name.

Damage Done requests the selected native recent window, or All. Healing Done
keeps native received-healing semantics; Boss Damage requests the current/last
encounter; Party Damage requests owner totals and retained hero portraits.
The v1 source buffers are bounded to these four views. The meter does not call its
legacy icon resolver, match party names to live units, observe a second damage
tab, keep a local rolling ring or subtract local reset baselines on this path.
Current-loadout reads are unnecessary for these rows because each snapshot
includes complete historical source metadata.

For these four views, X captures a native checkpoint synchronously. A failed
capture preserves both the native checkpoint and the separate Damage Taken reset
session. Successful replacement releases the
old handle; failed release retries through the existing controller without
collecting data while disabled. Invalidated checkpoints block pre-reset replay
until a new Reset or the normal session/world retirement. Language changes
update captions without replacing the checkpoint. New runs clear the previous
session; epoch/authority/encounter changes invalidate displayed rate samples.

Pending/missing artwork uses the shared neutral image. Retained portraits use
the existing circular renderer, native circle when available and the same
pooled strip fallback otherwise. Failed bindings observe native retry delays;
permanent failures wait for a changed identity or normal pool retirement.
Both Performance Mode states retain the same instant native information.

The existing getter/metadata/rate path below remains for clients without the
v1 capability endpoint. Once that endpoint is present, typed errors or missing
native data never borrow legacy counters. Local work is source review and
pinned formatting; mocked lifecycle scenarios remain CI-only and no game was
launched to verify this future native boundary.

The meter uses the original Details! **The War Within** header, progress-bar and
background artwork in a native SurvivorsDragonUi window. Details and its skin
addon do not need to be installed.

Each bar has a two-unit black outline to separate its rounded rail from busy
backgrounds. It reuses the existing background image beneath the original
artwork and follows the bar's width, icon gutter and Layout scale.

The custom meter is **off by default**. Turn on **Enable damage meter** under
`/sdui` → **Damage meter**, then Confirm. The switch previews live and follows
the shared Cancel/discard/profile paths; both full resets turn it off. Turning
it off hides and clears the custom view and restores the native HUD preference
captured by the replacement. It does not force the game's own meter setting off.

Click its heading to cycle through Damage Done, Healing Done, Boss Damage,
Party Damage and Damage Taken;
views still waiting for their first usable native publication are skipped.
Right-click goes backwards. The gold header shows **Total** and **DPS** (or **HPS**
for healing), replacing the view name and the former footer text. Hover over the
header to see the current view. The small gold **X** resets statistics in every
view; it never closes the meter. When totals are shown, missing values display `--`.
Under `/sdui` → **Damage meter**, set **Abilities shown** from **1 to 10**;
the default is **6**. The number previews immediately and saves with Confirm.
Cancel, world/logout/reload discard, profiles and both resets use the shared
display lifecycle. Views without their required native data remain gated. Scroll
over the window for more sources. The settings use two columns. Rows show the
native source name, DPS/HPS and gold-ringed icon by default; ability totals,
percentages and ranks start off. **Ability damage**, **Ability DPS** and **Ability
percentage** control those three row values independently. **Ability icons**
and **Ability ranks** control the gold-ringed icons and list numbers. **Header
total** and **Header DPS** control the summary; turning both off shows the current
view name. Both header fields start on. All seven options use the same preview, Confirm,
Cancel, profile and reset behavior. Healing uses healing totals and HPS.
Hover still provides the full name and numbers when row values are hidden.

**Party Damage** lists heroes during co-op, with each hero's class color and
native unit portrait inside the same gold ring. It uses the game's player
totals and DPS; the **DPS window** setting applies to Damage Done. The row/icon
options and scrolling also apply to party rows. Older clients without the
party getter skip that view.

**Damage Done** shows rolling DPS over the last **10 run seconds** by default.
Under **DPS window**, use the minus/plus buttons for **5–120 seconds**, in
five-second steps. Below five, **All** selects the whole-run average. Hover over
the header or a source to see its whole-run average alongside recent DPS.
The **X** starts a new session for all five views. It clears totals, source rows, shares,
rankings, scroll position and displayed/recent rates together. Existing effects
or pets remain in game; their later damage or healing counts as new activity.
The reset is session-only and independent of Confirm. Legacy baselines are
captured by the next visible reader pass; v1 captures its four-view checkpoint
synchronously and leaves Damage Taken to that deferred legacy pass. This is not
one atomic five-view checkpoint. There is no
separate Reset DPS settings button. After resetting, **All** and the average DPS
tooltips use only damage since the reset. The window choice retains the shared
preview, Confirm, Cancel, profile and full-reset paths.

Use the left/right side handles on **DPS meter** in Layout to change its width without scaling rows or icons. Top/bottom handles change **Abilities shown**, using the same 1–10 limit as the settings control. Corner handles retain proportional scaling. Under Damage meter, **Name font size** changes source/hero names independently; **Number font size** changes row values and header/status text. Both range from **8 to 18**, default **11**. All changes preview and use Confirm, Cancel, profiles, discard and resets.

Ability names and row values use the resolved native DEFAULT font with OUTLINE,
matching guardian/chat text, and the shared chat shadow: black at `(1, -1)`.
The outline stays applied when changing font size, loading profiles or resetting.
The gold header retains its original styling.

The default scale remains **0.8** and width **240** UI units, with side-width limits **120–960**. Its bottom-right corner sits at the screen's bottom-right corner with no offset. Shared layout registration captures this scale before applying saved geometry. Defaults apply to unset geometry and both full resets; confirmed/draft positions and scales retain the shared rules. The default corner stays fixed when the ability count changes. Active side dragging holds the opposite edge fixed.

Width now lives beside scale and position in the existing Layout record. The obsolete `meterWidth` display field and slider are removed. `meterFontSize` and `meterNameFontSize` are finite, clamped/rounded display integers. Older saves/profiles missing a valid name size inherit their normalized `meterFontSize`, preserving the selected appearance; full resets use eleven for both. Both settings participate in named profiles and the existing save/discard lifecycle. No new SavedVariable or geometry migration is needed. Hidden/off views accept required root geometry but defer presentation, and resizing never starts native collection while the meter is off.

Row height, circular icons and gold rims remain 32, 26 and 31 units. Header
text retains its original size offsets above the selected number font. The
numeric label uses its actual native text width, rounded up with one unit of
glyph clearance and a five-unit name gap. Names receive all remaining space,
with at least 48 units reserved at the narrowest widths. Disabled numeric fields
leave no reserved column. This replaces the old fixed 58 units per field, which
truncated names early even when short numbers left unused space. Very large
text with all numeric fields can still clip; full native names and values stay
available on hover. Text sizes and row
widths update only on effective changes; failed font-size changes stay retryable.
Hidden/off views defer row/header presentation until visible; the shared editor
still receives required root-width changes.
The readiness row and lazy rows start with positive label widths even at 120;
column reflow then applies the measured name-space reservation. Defaults apply
to missing/invalid values and resets, preserving explicit saved width choices.

Each pooled row retains only its latest successful numeric text metric, keyed
by the rendered caption, actual font face/size/flags, owning-row effective scale
and relevant width. Raw counter changes that keep the same compact caption do
not remeasure. Missing/invalid metrics retry through the existing visible reader
with conservative space until ready. Row retirement clears the metric; hidden,
off and numbers-off views skip measurement. Both Performance Mode states use
the same instant reflow, without a new region, asset, event or updater. CI-only
production-meter cases cover the layout and font lifecycle; no local tests or
addon/game execution were run, and native glyph fit remains unverified.

## Damage Taken

Damage Taken is the fifth view. It reads the official legacy `AZS_TAKEN` rows
(`source`, `dmg`) and `AZS_RUN.taken`, including when the other four views use
v1. The current v1 contract has no incoming-damage metric; this view does not
invent one or fall back to outgoing damage.

The six known source keys are categories: `boss melee`, `boss spell`, `elite`,
`mob melee`, `mob spell` and `area`. Their captions are Boss melee, Boss spells,
Elites, Enemy melee, Enemy spells and Ground effects. Unknown native category
names retain their received text. These rows do not identify an attacker or
spell. A native total above the source sum contributes one **Unattributed
damage** row for the remainder, without guessing its cause. The title and seven
category captions have all fourteen UI translations.

Rates use `amount / max(native run seconds, 1)`, or native seconds since the
legacy Reset baseline. Pausing leaves those seconds unchanged. Damage Taken
uses the existing neutral icon inside the same circle/rim and never asks the
spell/item source resolver for category artwork. Amounts, shares and rows use
the existing pool, five-Hz visible reader and one-Hz rate presentation.

The shared legacy session baselines all five views on its next visible pass.
With v1 active, a successful native checkpoint capture also requests the separate
Damage Taken baseline; capture failure retains both previous sessions. Hidden
after a click defers that legacy capture until visible. World/run retirement,
disabling and full resets clear it through the existing lifecycle. No baseline
or gameplay data is saved.

Hidden/off meters skip Damage Taken normalization. Both Performance Mode states
show the same instant values. The fifth view adds no frame, region, asset,
event, updater, setting or SavedVariable. CI-only coverage is authored; no local
tests, standalone validation or addon/game execution were run.

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

Before a local reset, damage/healing totals and native shares/order cover the
whole run. Boss Damage covers the native current/last boss fight. Healing and
Boss Damage retain supplied native rates until a local reset. The game's own
meter-window Reset does not reset the API totals; there is no official setter
for clearing these counters.

`NewMeterSession` therefore captures exact name/proc counter baselines for all
five views through their existing data adapters, once in the deferred visible refresh
after the X is clicked. Subsequent rows contain only positive counter deltas.
Their sum becomes the displayed total; shares and descending rankings use those
deltas, with native order as the tie-breaker. Proc identity, source names and
native tables are never changed. Post-reset averages, including healing and boss
rates, divide these deltas by `max(native run seconds since Reset, 1)`.
Unavailable clocks leave rates unavailable. Missing/unpublished views stay gated
and baseline their first accepted snapshot, so switching views cannot restore old
values. No getter is called directly from the click handler.

A new native boss-fight counter population is already fresh and uses zero
baselines. Damage/healing regressions conservatively rebase the affected view.
Language changes rebase a reset session; hiding and view changes retain its
baselines. World/run retirement, disabling and full resets discard session data.
No baseline, damage record or reset session is saved or included in profiles.

Damage Done uses complete cumulative `AZS_GetMeter()` snapshots and published
`AZS_RUN.t` run seconds. Its rolling header and per-source rate are
`(damage now - damage at window start) / observed run seconds`, interpolating the
left boundary between accepted samples. The denominator grows from the first
observed sample up to the chosen window. Less than one observed run second shows
`--`; missing clock data also leaves recent DPS unavailable. Pausing does not
advance the window. UI `GetTime()` controls only display cadence, never the rate
denominator. No SCT hits, combat events, wall-clock combat time or inferred fight
segments enter the calculation.

`core/meter_rates.lua` keeps bounded, session-only cumulative samples for the
header and exact source-name/proc identities. Observation uses the existing
five-Hz controller, continuing Damage Done sampling while another meter view is
visible. A gap over two run seconds discards the recent window; showing after
hiding starts a new observation window. Clock/total/source-counter regression or
a disappearing source retires recent history. New runs, world cleanup, language
changes, full resets, disabling and the X clear it too. All skips recent history
and uses the native run average before a reset, or the session average afterwards.
No recent samples or reset baselines are collected while hidden/off.

The window lives in the existing normalized display table as `meterDpsWindow`:
default ten, zero for All, otherwise a finite rounded/clamped integer `5..120`.
Missing or invalid values and both full resets use ten. Named profiles copy the
same normalized setting, with no new SavedVariable. Reset baselines/history are
never saved or included in profiles.

Header and row DPS/HPS plus average tooltips are presented at one Hz; totals,
shares, bars and input retain five-Hz updates. New sources obtain their current
rate immediately when a sufficient window exists. Rate samples follow exact
name/proc identity, independently of row pooling, scrolling or native sorting.
View changes and invalid data clear presentation samples; rate-history retirement
and regressing native totals refresh them immediately. Changing the window
refreshes rates through the existing controller, without resetting damage totals.

The behavior follows the referenced
[AZSSpellMeter window modes](https://github.com/kex0/AZSSpellMeter/blob/efabc6cd4e85ac9d0b6dd5ba62a37b5cc8dd6f64/AZSSpellMeter.lua#L574-L657)
and [KeijinUI's recent-DPS display](https://github.com/KeijinDE/KeijinUI_modern-as-ui/blob/v4.3.2/KeijinUI/Statistics.lua#L416-L442).
Their runtime code is not imported; native data ownership and the addon lifecycle
remain local to this implementation.

The phase is read before any retained meter data. `ready` clears the view;
`playing`, `choosing`, `paused`, `dead` and `victory` can display valid data.
Each native snapshot must have finite nonnegative totals, rates, row amounts
and shares, with shares at most one. Source names remain native; before Reset,
source order remains native too.
Rows are copied for display; native tables are never modified.

Initially a nonempty valid getter result can recover a view whose packet arrived
before addon initialization. Empty lists require their `AZSMETER`, `AZSHEAL` or
`AZSBOSSDMG` publication. A new zone, world leave or ready phase retires the
previous data and requires new publications before accepting that view again.
Packet handlers record receipt only: getters are read after parsing in OnUpdate,
at most five times a second. Paused data has no artificial expiry. Missing native
replay after reload can leave an empty view waiting; no resync API is invented.

Damage, healing and boss sources belong to the local player's native meter.
Party Damage shows the game's per-hero counters instead. This is not a port of
Details' combat parser. Proc rows keep the native
blue distinction; other ability rows use the shared player-class palette. Ability icons use SCT's
existing exact-name metadata resolver independently of SCT's display mode or
filters. Ambiguous/missing icons use the shared neutral question mark. Source icons are circular and use
the existing gold jewelry ring, matching the reference skin's round presentation.
The skin's retail class/spec portraits would misidentify per-source rows and are
not imported.

### Party data and portraits

`AZS_GetPartyMeter()` supplies `{ name, class, dmg, dps, share, top, topdps }`
rows and the summed party total/rate. Only the published name, class, damage,
rate and share are consumed; no spell breakdown or attribution is invented.
The existing controller handles `AZSPARTY` receipts and defers its getter until
after native parsing, with the same phase, empty-publication and world/zone
retirement gates. Readiness, native HUD ownership, one-Hz displayed rates and
the five-Hz visible reader are shared. X baselines this fourth view along with
the other three; its post-reset rates use native seconds since Reset. Class
metadata survives session deltas, including metadata-only changes.

While visible with icons enabled, one fixed five-unit pass reads `player` and
`party1`–`party4`. An exact, unique current `UnitName` match, with compatible
native class keys when available, permits `SetPortraitTexture` on the row's
existing named texture. This is the native unit-portrait path used by party
frames, independent of whether those frames are shown. The current native
frame's portrait image is a change token, not a source of damage ownership.
Reordering or replacing party units rebinds the matched portrait; ambiguous,
missing or unsupported units use the shared neutral icon. No hero name is sent
to the spell/item icon resolver.

Successful portraits skip repeat binding until their unit/name/source image
or actual assigned texture changes. Failed native bindings stay memoized until
that identity/image changes or the row retires. The neutral icon retains its
existing native-circle/strip fallback and retry rules. Icons off, hidden/off
meters and retired rows perform no portrait lookup/binding; retirement clears
the bounded unit metadata. No portrait model, frame, region, asset, event,
updater or SavedVariable is added. The source API was read from the installed
client as recorded in [API-NOTES.md](API-NOTES.md); live co-op appearance and
input remain unverified. The lifecycle fixture is CI-only.

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
The existing visible reader resolves header navigation and skips unpublished
views whose body would be blank, in the chosen forward or reverse order. A valid
received empty snapshot remains selectable with **No meter entries yet.**, and
explicit unavailable-data errors retain their message. Initial selection can
also advance to a ready view. If every view is waiting, selection stays stable
and the existing header names the current view; totals return when data arrives.
The waiting body remains hidden, without another caption or invented values.

Getter calls stay out of click handlers. Pending navigation waits while hidden;
disabling or retiring the meter clears it. Candidate scans are bounded by the four views and reuse the
existing phase/publication validation; retired and initially empty data never
become available merely to fill a page. Hiding the Layout group intentionally
hides the replacement while its valid native takeover remains active.

Rapid clicks retain their first direction and subsequent net steps through one
deferred resolution, including reverse clicks and an initially waiting view.
Other views are probed for navigation or a new readiness/publication/visibility
change, rather than every settled poll. Selection, Reset baselines, rolling
damage observation and presentation reuse each native result within a reader
pass. Four reusable result records release their source/value references after
the pass, including failed refreshes. Candidates retain only view indices; no
view history or gameplay persistence is added. Normal and Performance Mode use
the same selection and static waiting header.

Layout-hidden meter groups retain phase retirement and native ownership. They
validate selected-view data only after a native publication, without copying
view rows or sampling displayed rates. Hiding clears recent cumulative samples;
showing reads current native data and warms the rolling window again.
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
Only the visible row limit changes: complete selected-session totals, source
rankings and the overflow scroll list remain intact.

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
