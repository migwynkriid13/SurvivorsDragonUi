# DPS meter

## Bar colors

In `/sdui` → **Damage meter**, **Bar colors** sits below **Enable damage meter**
and above the **Ability color** and **Proc color** fields. Select **Default** or **Custom**.
Default distinguishes the kind of damage before applying spell-school colors:

| Damage category                    | Color                     |
| ---------------------------------- | ------------------------- |
| Periodic damage / damage over time | Green                     |
| Melee / basic attacks              | Silver                    |
| Talent damage                      | Violet                    |
| Item effects                       | Amber                     |
| Other procs                        | Blue                      |
| Other abilities                    | Their damage-school color |

Periodic damage takes priority when the game identifies all of a row's damage
as periodic. The other categories use native source metadata and proc flags.
For example, periodic poison damage is green even when its supplied school is
Physical. No poison names, icon colors or current equipment are used to guess.
Talent-colored rows use a direct talent descriptor or the existing validated
actual-talent presentation; an ability merely related to a talent does not
become talent damage.

Remaining abilities use these received schools:

| School   | Color      |
| -------- | ---------- |
| Physical | Yellow     |
| Holy     | Light gold |
| Fire     | Orange     |
| Nature   | Green      |
| Frost    | Cyan       |
| Shadow   | Violet     |
| Arcane   | Pink       |

Known hybrid schools blend their native mask's school colors. Unknown,
unavailable or conflicting types retain class-color fallback for ordinary
abilities. Mixed families retain only categories shared by all constituents;
a mixed ability/talent family keeps normal ability presentation unless all of
its damage is periodic. Legacy builds without source/category metadata retain
the existing class/blue-proc fallback. Names and icons never establish a school.

Custom enables separate **Ability color** and **Proc color** controls. Click a
swatch to use the game's color picker, or enter a six-digit RGB hex value such
as `#FF8800`. The hex fields also work when the native picker is unavailable.
Party rows keep their class colors. The existing textured bar artwork is used
with either palette.

Valid colors preview immediately. Enter or leaving the field finishes its text
edit; Escape restores its color from before typing. Cancel in the native picker
restores the color from before opening it. The settings window saves only with
Confirm; its Cancel/discard paths and profiles include the palette. Returning to
Default retains the custom choices for later. Missing/invalid saved preferences
and both full resets select Default; custom defaults are gold `CCA147` and blue
`4094FF`.

The three scalar preferences live in the existing display table. RGB strings
normalize to six uppercase hex digits, accepting an optional leading `#`;
malformed values fall back when loading and are ignored while editing. The
native picker accepts finite RGB channels only, disables opacity editing and
uses owned callbacks with initialization guards. Its owned session temporarily
borrows the settings strata and a higher frame level, restoring its captured
native layer on release. Retirement closes/restores only
the owned session, preserving a foreign callback handoff. No global picker
script is replaced, and missing native functions leave hex input usable.

The renderer caches the active palette and decodes changed custom colors once
through the display listener. Visible rows include its revision in their color
inputs and write only changed final RGB values. Default-mode edits to retained
custom choices do not invalidate presentation. Both Performance Mode states use
the same instant presentation; hidden/off meters defer painting, and existing
show/world/row retirement paths reuse the pool. Counters, native rates, proc
classification, reset checkpoints and attribution are unchanged. The CI-only
editor/native/legacy cases were authored without local execution; native picker
availability and live appearance remain unverified.

Native v1 school colors join each display row's received `memberIds` to its
same-snapshot contributions through the existing validated owner/caster/source/
proc boundary. Every positive member must have `schoolState = "known"` and agree
on one finite integer `schoolMask` in `1..127`. Missing, malformed, unjoined or
conflicting members leave the row's school unknown. Zero-display historical
members cannot supply or block a post-Reset school. Rank/item/talent families
and optional pet summaries retain their original grouping and get a school only
when every constituent row agrees; mixed rows keep the previous fallback.
Actual multi-bit masks are distinct from conflicts between different members.

The adapter retains the received display source kind and one all-periodic flag
beside the school scalar. That flag uses the same exact member join: every
positive contribution must have `creditKind = "health_damage"` and
`periodicity = "periodic"`. Missing/malformed periodicity, other credit kinds,
unjoined members and direct/periodic mixtures leave it unset. Zero-display
history does not vote. Item-family classification uses only the existing
validated item family, without another origin lookup.

The adapter copies these scalar color inputs during its existing
member pass, without retaining new leaf tables or duplicating the contribution
index. School/periodicity-only changes do not invalidate attribution fingerprints, rate
identities, checkpoints, captions or artwork. Family sums refresh their school
inputs without regrouping. The visible viewport copies those scalars through its
existing sampling pass, and row color caches include them only for Default.
Five category colors, seven base colors and at most 120 lazily resolved hybrid colors form one bounded
renderer palette; RGB resolution and writes happen only when relevant inputs
change. There is no new setting, API getter, gameplay region or updater for
automatic colors. CI-only cases cover exact types across identical captions,
same-school melee/periodic/talent/item/proc distinctions, hybrids, malformed/unknown
data, member/family agreement, Reset,
rate-identity preservation, hidden reuse and Custom precedence.

## Native version 1 data path

Clients implementing the [version 1 contract](DAMAGE-METER-AND-INSTANCE-PLAYER-POSITION-API.md#3-version-1-implementation-contract)
use `core/meter_api.lua` for Damage Done, Healing Done, Boss Damage and Party Damage. The meter reads complete
native snapshots and their authoritative source/hero descriptors. Names and
icons come directly from those descriptors, including equipment, jewelry,
learned talents, pet/totem attacks and periodic effects in every native language.
Unrelated native sources retain their separate rows even when their names match.
Recognized ability ranks use a stable display-group identity for rate samples.

The shared meter controller reads native and legacy data once per second during
regular updates. Totals, shares, bars, attribution and displayed rates use that
same cadence. Input, settings, scrolling, Reset and showing the meter prime the
existing reader for the next frame, keeping user feedback immediate without
another idle updater.

Damage Done requests the selected native recent window on the regular
one-second pass. Extra triggered reads within that second may use complete
native snapshots with `windowSeconds = 0` while the viewport's native rates
remain current. These counter reads do not replace recent DPS with the All average. Newly
revealed or replaced row identities, Reset and native context retirement obtain
a fresh recent capture immediately through the existing reader. Only visible
rows retain sampled native rates; unavailable history stays unavailable.
Selecting All uses native averages without requesting recent history. Healing Done
keeps native received-healing semantics; Boss Damage requests the current/last
encounter; Party Damage requests owner totals and retained hero portraits.
The v1 source buffers are bounded to these four views. The meter does not call its
legacy icon resolver, match party names to live units, observe a second damage
tab, keep a local rolling ring or subtract local reset baselines on this path.
Current-loadout reads are unnecessary for these rows because each snapshot
includes complete historical source metadata.

The reset button captures a native checkpoint synchronously. A failed capture preserves the
previous session and its visible values. Successful replacement releases the
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

The reduced history-query cadence still reads complete official snapshots;
it does not omit the native ledger or establish a measured FPS improvement.

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

The view is constructed on first enable, including preview. Before that, no
meter frames, rows, data adapters or native subscriptions are created. Later
disable/enable cycles retain the existing pooled view and cleanup behavior.

Click its heading to cycle through Damage Done, Healing Done, Boss Damage and Party Damage;
views still waiting for their first usable native publication are skipped.
Right-click goes backwards. The gold header shows **Total** and **DPS** (or **HPS**
for healing), replacing the view name and the former footer text. Hover over the
header to see the current view. The small gold **refresh button** resets statistics in every
view; it never closes the meter. When totals are shown, missing values display `--`.
The whole meter hides while level-up or jewelry upgrade cards are open and
returns afterward. This temporary hide preserves statistics, reset checkpoints
and recent DPS samples. It follows the existing one-second reader and respects
the Layout Hide frame choice.
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

Hold **Shift** over a native v1 row to show **Native IDs** in its tooltip.
Without Shift, the tooltip shows its usual name, damage, DPS, average and share.
Pressing or releasing Shift while the pointer stays over the row updates the
section through the existing controller, without another combat-data read.
If the Shift getter is unavailable, diagnostics stay hidden. The technical field
names stay as the API spells them: `rowId`, `sourceKey`, `ownerId`, `actorId`,
`nativeProc`, `kind`, `attribution` and `rank`, plus supplied ability, talent,
variant and item IDs. Accepted positive members supply actual
`originSourceKey` details; zero-display history supplies none. Missing fields
show `--` or are omitted. These are received native identities, never the
private display token or an ID guessed from a name.

This helps compare two equally named rows that still have separate DPS. A
combined row can include several native source records. The tooltip shows at
most three records and three actual origins per record, within 24 diagnostic
lines; `...` marks omitted details. It makes no additional native read. Text is
prepared only on a Shift-held hover and reused while identities and metadata
stay unchanged. Ordinary hovers never request the diagnostic descriptor.
Both Performance Mode states share this static behavior. Legacy meters keep
their existing statistics tooltip because they do not supply these IDs.

**Party Damage** lists heroes during co-op, with each hero's class color and
native unit portrait inside the same gold ring. It uses the game's player
totals and DPS; the **DPS window** setting applies to Damage Done. The row/icon
options and scrolling also apply to party rows. Older clients without the
party getter skip that view.

**Damage Done** shows rolling DPS over the last **10 run seconds** by default.
Under **DPS window**, use the minus/plus buttons for **5–120 seconds**, in
five-second steps. Below five, **All** selects the whole-run average. Hover over
the header or a source to see its whole-run average alongside recent DPS.
The **reset button** starts a new session for all four views. It clears totals, source rows, shares,
rankings, scroll position and displayed/recent rates together. Existing effects
or pets remain in game; their later damage or healing counts as new activity.
The reset is session-only and independent of Confirm. Legacy baselines are
captured by the next visible reader pass; v1 captures its four-view checkpoint
synchronously. There is no
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
not remeasure or repeat the settled layout helpers. Each visible numeric label
still checks its actual font so an unannounced native font change can invalidate
the layout; rows share one root-scale sample. Width, scale, icon options, font
choices and changed captions also invalidate the relevant layout. Missing or
invalid metrics retry through the existing visible reader
with conservative space until ready. Row retirement clears the metric; hidden,
off and numbers-off views skip measurement. Both Performance Mode states use
the same instant reflow, without a new region, asset, event or updater. CI-only
production-meter cases cover the layout and font lifecycle; no local tests or
addon/game execution were run, and native glyph fit remains unverified.

## Exact ability/talent key pairs

Native v1 Damage Done and Boss Damage combine an ability and talent when their
received keys match exactly as `<class>.<abilityKey>_talent`. For example,
`rogue.blade_flurry_talent` pairs with `blade_flurry`. The class prefix must be
one of the nine recognized native classes; spelling and case remain exact.
There is no per-ability allowlist. Talents without the exact suffix, partial
matches, similar names and matching icons never establish a pair.

A static read of the installed executable's 355 talent definitions and 114
ability definitions found these three suffix matches:

| Native talent key           | Native ability key | Received talent / ability names |
| --------------------------- | ------------------ | ------------------------------- |
| `rogue.blade_flurry_talent` | `blade_flurry`     | Blade Flurry / Blade Flurry     |
| `priest.holy_nova_talent`   | `holy_nova`        | Radiance / Holy Nova            |
| `priest.holy_fire_talent`   | `holy_fire`        | Purifying Flame / Holy Fire     |

The native game records these effects separately. Combining their presentation
is an addon choice, not proof that their gameplay effects are identical. The
row adds same-snapshot native amounts and supplied recent/average rates;
an unavailable input rate remains unavailable. Native IDs keeps the original
ability/talent source IDs, row IDs, proc flags and actual origins.

Only known non-proc ability records and known proc talent records participate.
Both need positive integer ranks and the same received owner, actual caster
and variant/item components. An optional ability/talent component must agree
with the same exact pair. Different class prefixes for one ability stem make
the family ambiguous, even across different talent ranks, and retain the raw
rows. Item families and optional pet summaries keep their existing precedence.
Ordinary skill grouping across repeated native summon definitions stays unchanged;
a mixed skill/talent family with conflicting actual casters retains its raw rows.
Queries without an actual caster, Healing Done, Party and the legacy path
retain their established behavior.

The highest positive ability rank supplies the received name and artwork;
the highest positive talent rank supplies them while no ability contributes.
Zero-display history after Reset cannot choose the caption. Kind/proc/rank
slots preserve same-rank source ambiguity instead of silently merging it. A
mixed family uses the normal ability presentation; Default still prefers an
agreed native damage school, and Custom uses its ability color. Raw proc flags
remain visible in Native IDs.

The existing family pool handles sums, sorting, checkpoints and retirement.
Caption priority and exact talent identity are cached with changed source
metadata, so counter-only updates keep the existing display/rate identities.
Both Performance Mode states are instant, with hidden/off deferral and no new
control, region or updater. CI-only cases are authored without local execution;
actual in-game presentation remains unverified.

Catalog provenance: executable SHA-256
`eb5fd1c1b96e6180fcf5f3d685d90a61471af28d22e5f060c02b7b7663fbf79e`.
The class index starts at file offset `0x71460f8`: nine 200-byte records,
three 64-byte trees each, with native pointer/count slices of 176-byte talent
records. Keys and names are at +64/+80. The ability table is the same pinned
114-record table used by [SCT spell data](SCT-SPELL-DATA.md). REA/Ghidra 12.1.4
also read the bounded original region `0x7128538..0x7146800`, SHA-256
`d88ffec25297aa1d0052c0e4e9b9489b8f0f315ae1ac1eb6029005cfe60bb4d6`;
its suffix search returned these three candidates and its complete 1,800-byte
index read retained all class/tree descriptors. This is static catalog evidence,
not game execution or a claim about every talent's damage attribution.
REA evidence: suffix search
`ev_e35af9eaa5af4954515ed1e77c20dbe9e30cacd2ed1550c25adc5b80ba9d429a`;
index read
`ev_394146680745e93c61e4fb6c71be5afb34a92a9dfe629e406b93b71b26791696`.

## Ability ranks

Damage Done, Healing Done and Boss Damage combine recognized ranks of one
ability into one displayed row. The row adds their native amounts and rates,
recomputes its share against the native total, and sorts by the combined amount
with native order as the tie-breaker. Native counters, detailed source records,
header totals and checkpoints remain unchanged. Party Damage keeps its existing
grouping.

On v1, grouping requires an ability descriptor with a valid native `abilityKey`
and skill rank. Owner, proc, variant, item-instance, talent and item identities
stay distinct. A family with conflicting same-rank sources stays separate, as
do sources without the required identity and generic or unbound effect sources.
Names alone never establish a v1 family. The highest contributing skill rank
provides the native caption and artwork, including pending or missing artwork;
the private display identity survives later upgrades and language changes.
Any member with an unavailable rate leaves that combined rate unavailable.

Legacy getters expose only names and proc flags as source identity. Their exact
name/proc duplicates combine before reset baselines and rolling-rate sampling;
the addon never strips rank text or guesses a relationship between other names.
Copies are pooled and publication-cached, with rate-only refreshes using the
existing cadence. Both Performance Mode states use the same instant result.
CI-only cases cover nine ranks, later upgrades, resets, rates, metadata changes
and distinct sources; no local tests or game execution were run.

## Talent ranks

Damage Done, Healing Done and Boss Damage also combine recognized ranks of one
native talent. A direct talent source requires known attribution, a valid
`talentKey` and rank. The highest contributing rank supplies its received name
and artwork. Later upgrades retain one display identity and add their native
amounts and rates, like ability ranks.

Known ability procs already named from one validated actual talent origin group
under that talent across triggering abilities and optional ability ranks.
For example, the received `ability:fire_nova` without a rank and
`ability:fire_nova:r1` can share Flametongue Weapon rank 3. Rockbiter and
Stormstrike procs with the same actual Windfury Weapon origin share its row too.
The highest contributing talent rank supplies the caption and artwork. The
addon never assigns a missing ability rank or derives ownership from names,
definition relationships or loadouts. Every positive member of each native row
must still agree on one exact valid actual origin.

Ambiguity checks retain the triggering ability, its supplied rank or explicit
absence, and talent rank. Conflicting native sources in one such slot, or
different actual origin IDs at the same talent rank, keep the whole family
separate. Item-bound rank families retain their existing component identity
and highest-item-rank presentation, with talent rank as its tie-breaker.

Different owners, recorded casters, proc flags, explicit variants,
item identities and talent identities stay separate. Missing or invalid talent
metadata and conflicting sources at the same rank stay separate as well;
names and source-key text never establish a family. No native record, amount,
rate, checkpoint or origin is rewritten. Existing pooled rows, metadata caches,
one-second rates, pet summaries and both Performance Mode states keep their
shared lifecycle. CI-only cases cover direct and actual-origin ranks, upgrades,
ambiguity, art readiness, rates, resets and hidden work. No local tests or game
execution were performed. The reported tooltips establish these source/origin
shapes; the complete native snapshot and the patched live appearance remain
unverified.

## Item ranks

The v1 meter also combines recognized ranks of one item, including item-bound
abilities and effects. An explicit native `itemKey` establishes the family;
rank-specific item IDs may differ. Matching item damage from the player, pets,
summons and totems combines under the item's native caption without a caster
suffix, including when **Combine pet damage** is enabled. Separate copies,
accounting owners, proc flags, variants, talents and effect components remain
separate. The highest contributing item rank supplies the native row caption
and artwork. Amounts, rates, shares,
Reset checkpoints and both Performance Mode states use the existing rank-summary
path without changing native counters.

Direct item rows require their own item key and rank. Item-bound abilities and
effects also require a stable native ability or effect-component key. They can
use their own explicit item/rank metadata, or each positive member's single
recorded item origin joined from the same snapshot. Actual item origins supply
the item rank independently of an ability's skill rank. Definition-level links,
names, current equipment and item IDs alone never establish a family. Missing,
conflicting or multiple origins and ambiguous same-rank sources stay separate;
zero-display members do not supply post-Reset attribution.

The existing bounded **Native IDs** hover retains the original source and caster
IDs. Summing the display rows does not rewrite the native records or add item
damage to a pet summary a second time. Ambiguous families retain their separate
native rows and caster captions.

CI-only fixtures cover these explicit contracts, including multiple item keys,
player/pet/totem casters, repeated summons, pet grouping, native amount/rate sums,
Reset, missing rates, ambiguity, caster diagnostics and hidden/off reuse in both
Performance Mode states. No live Eye of Hakkar snapshot was available, so
grouping its published ranks still depends on the game
supplying that identity. No local tests or game execution were performed.

## Pet damage

On clients with the native v1 meter API, Damage Done and Boss Damage show the
received caster name beside each pet, summon or totem spell, such as
`Shadowbolt (Imp)`. When the received ability and caster display names match
exactly, omit the repeated suffix: `Searing Totem` stays `Searing Totem`.
This changes only the caption; player and pet damage keep their recorded
identities even when the visible names match. Player spells keep their own rows. The meter uses recorded
actor identities, including contributors that have despawned, rather than
matching names or observing the current pet.

Under `/sdui` → **Damage meter**, enable **Combine pet damage** to show each
pet's spells together under its native name and portrait. This choice defaults
off and shares preview, Confirm, Cancel, profiles and full resets. Where the
native actor supplies a summon or totem key, the same kind belonging to the same
accounting owner shares a row across incarnations. Without that key, individual
actor identities stay separate. Names and broad pet-family labels never merge
actors. The same identity rule keeps the default spell rows compact without
combining player and pet casts. Recognized item damage uses the shared item row
described above rather than a caster spell row or pet summary.

Pet summaries add their disjoint native amounts and rates, retaining the
selected native window and checkpoint. A missing member rate keeps the combined
rate unavailable. Summaries follow **Bar colors**: Default uses an agreed known
school, with the proc/class fallback otherwise; Custom uses the proc color for
all-proc summaries and the ability color for mixed summaries. They do not change native counters,
header totals or Reset. Healing Done, Party Damage and the legacy meter path
keep their existing grouping. Both Performance Mode states show the same
instant result; hidden/off work remains deferred. CI-only mocks cover native
caster labels, summaries, later incarnations, preview/discard, profiles, resets
and unchanged reuse. No local tests or game execution were performed.

## Talent proc captions

On the native v1 path, a proc can show its triggering talent's received name
and icon. For example, an ordinary cast remains `Pyroblast`, while a separately
recorded proc with an explicit Hot Streak origin shows `Hot Streak`. The same
rule applies to Chastise or any other native talent caption; the addon has no
spell-to-talent name table and does not infer a talent from the player's class,
current build, spell name or bar color.

Every positive displayed contribution in the row must identify the same single
actual talent origin in that snapshot. Definition-level associations do not
establish that attribution. Missing, mixed, multiple or invalid origins keep
the received source caption and artwork. Zero-display history does not supply
post-Reset attribution. Native proc classification remains unchanged. Default
colors use the received damage school regardless of the talent caption, and
Custom retains its separate ability/proc colors.

This changes presentation only. Native source records and IDs, counters, rates
and checkpoint fences remain intact. Display families retain distinct accepted
talent identities, with explicit rank normalization as described above. Pending or missing talent
art uses the shared neutral icon; native metadata revisions refresh names and
artwork through the existing pooled presentation. Both Performance Mode states
use the same instant result and hidden/off work stays deferred. CI-only mocks
cover these boundaries; no local tests or game execution were performed, and
actual Rockbiter, Hot Streak and Chastise payloads remain unverified.

## Native data

The meter reuses prepared source names and groups as counters change, and only
copies and samples the rows currently visible. Scrolling retains the complete
rankings and initializes each newly revealed row's rate. Regular totals and
displayed DPS/HPS update once per second. Both Performance Mode
states share this behavior. The native API still supplies the complete ledger;
these source changes do not establish a measured late-run FPS improvement.

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

Before a local reset, damage/healing totals cover the whole run. Grouped source
shares use those native totals. Boss Damage covers the native current/last boss fight. Healing and
Boss Damage retain supplied native rates until a local reset. The game's own
meter-window Reset does not reset the API totals; there is no official setter
for clearing these counters.

`NewMeterSession` therefore captures exact name/proc counter baselines for all
four views through their existing getters, once in the deferred visible refresh
after the reset button is clicked. Subsequent rows contain only positive counter deltas.
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
one-Hz controller, continuing Damage Done sampling while another meter view is
visible. A gap over two run seconds discards the recent window; showing after
ordinary Layout/UI hiding starts a new observation window. Clock/total/source-counter regression or
a disappearing source retires recent history. New runs, world cleanup, language
changes, full resets, disabling and the reset button clear it too. All skips recent history
and uses the native run average before a reset, or the session average afterwards.
No recent samples or reset baselines are collected while hidden/off.

The window lives in the existing normalized display table as `meterDpsWindow`:
default ten, zero for All, otherwise a finite rounded/clamped integer `5..120`.
Missing or invalid values and both full resets use ten. Named profiles copy the
same normalized setting, with no new SavedVariable. Reset baselines/history are
never saved or included in profiles.

Header and row DPS/HPS, average tooltips, totals, shares and bars use one-Hz
regular updates. Input primes the reader for the next frame. New sources obtain their current
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
`playing`, `choosing`, `paused`, `dead` and `victory` remain valid data phases.
During `choosing`, the root is actually hidden before snapshot/row work; the
existing native HUD suppression stays acquired. Its OnHide handler retains
recent samples only for this temporary choice hide, and OnShow rejects an
attempt to reveal it until a fresh phase read leaves `choosing`. Session and
native checkpoint ownership are unchanged. Other valid phases display normally.
Each native snapshot must have finite nonnegative totals, rates, row amounts
and shares, with shares at most one. Source names remain native; before Reset,
source order remains native too.
Rows are copied for display; native tables are never modified.

Initially a nonempty valid getter result can recover a view whose packet arrived
before addon initialization. Empty lists require their `AZSMETER`, `AZSHEAL` or
`AZSBOSSDMG` publication. A new zone, world leave or ready phase retires the
previous data and requires new publications before accepting that view again.
Packet handlers record receipt only: getters are read after parsing by the
shared one-second controller, with input-triggered refreshes on the next frame.
Paused data has no artificial expiry. Missing native
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
retirement gates. Readiness, native HUD ownership, displayed rates and the
one-Hz regular reader are shared. The reset button baselines this fourth view along with
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
through the meter's existing one-Hz refresh, with no new event or updater.

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
view, language, Shift state or effective scale changes; a tooltip taken or hidden by another
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
coalesces regular data reads at one Hz; user actions prime that same reader for
the next frame. Rows skip full layout, metric, static-icon, fraction and color work
when their corresponding inputs are unchanged. Final displayed captions drive
text layout; bar fractions still react to both the row amount and leading amount.
Names, including recorded caster captions, update independently.
Successful static native icons skip rebinding at the same path and scale, while
failed artwork and font assignments remain retryable. Native portrait-image
checks, legacy icon-resolver checks and Party class-color validation continue
through the regular reader. Pool retirement clears the settled presentation
state, and hovered tooltips retain their existing ownership checks. Bar values,
colors, successful icon bindings and label text also skip unchanged writes.
If the shared SCT resolver is unavailable,
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
