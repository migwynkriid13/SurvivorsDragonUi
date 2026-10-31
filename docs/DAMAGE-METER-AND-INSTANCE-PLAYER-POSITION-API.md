# Native API requests: navigation and damage meter

This document describes the data SurvivorsDragonUi currently receives, the
workarounds that data requires, and the native contracts needed to replace them.
Section 3 fixes the requested version 1 function names, signatures, schemas and
error behavior for implementation. These new functions are to be added by the
game; the existing getters described in section 2 remain compatible.

Start implementation with the [fixed API contract](#3-version-1-implementation-contract).
Sections 1–2 provide context and coverage requirements.

## 1. Live player position in instances

### Current behavior

In the open world, `GetPlayerMapPosition("player")` provides live map coordinates.
The addon can read them every frame, so cache and guardian minimap markers follow
player movement smoothly.

In affected instances, including Scarlet Monastery and Naxxramas, that function
returns `0,0`. The addon falls back to `AZS_RUN.px/py`, received through periodic
`AZSRUN` snapshots, normally on a 0.2-second publication cadence while playing.
Markers jump between those received positions as the player moves.

### Requested API

Implement the fixed version 1 call described in section 3.5:

```lua
position, err = AZS_GetPlayerPosition()
```

On success, `position` is the specified table containing `mapId`, `spaceId`,
`x`, `y`, `z`, `facing` and sample identity. On failure, return `nil, ApiError`.
This getter works inside and outside instances, independently of run packets
and the world-map selection. Zero coordinates and facing are valid values.

### Expected result

The existing addon updater could place cache and guardian minimap markers from
the current player position inside instances, just as it can in the open world.
This would avoid snapshot stepping without interpolation, movement prediction
or more frequent addon packets.

## 2. Complete native damage-meter API

### What we need

The game should publish complete native meter counters together with stable
source and actor identities, its own localized names and its own icons. This
needs to cover damage, healing, boss encounters, every party member, pets,
totems, direct attacks, every periodic effect, talents and items in every game
language. It must also cover sources that are no longer alive, equipped or
visible when the addon asks for the meter.

This explicitly includes icons from the player's actual equipment, learned or
selected run abilities, learned talents, and jewelry. The game should provide
the correct native item/ability variant and its artwork, rather than requiring
the addon to look them up by translated name in a generic icon database.

Adding an icon to the current rows would help, but would not solve the whole
problem. A name-based row cannot reliably distinguish different sources with
the same label. A complete API must retain source identities and attribution
through aggregation. Use a stable native source key: do not assume that a spell
ID uniquely identifies every custom ability, variant or periodic effect. Some
meter sources are not spells at all.

The addon already uses native damage and healing counters. It does not calculate
meter damage from SCT, parse combat events into a second damage ledger, or
estimate which pet caused damage. The workarounds mostly concern
display metadata, identity, publication lifecycle, reset and recent rates.

### Current views and exposed fields

| View         | Current getter        | What the addon receives                                                                                    |
| ------------ | --------------------- | ---------------------------------------------------------------------------------------------------------- |
| Damage Done  | `AZS_GetMeter()`      | Local-player native whole-run source rows, total and DPS.                                                  |
| Healing Done | `AZS_GetHealing()`    | Local-player native whole-run healing source rows, total and HPS; documented healing excludes overhealing. |
| Boss Damage  | `AZS_GetBossMeter()`  | Local-player source rows for the current or last native boss encounter, total and encounter DPS.           |
| Party Damage | `AZS_GetPartyMeter()` | Per-hero party damage totals and rates, without a complete per-hero ability breakdown.                     |

Damage, healing and boss rows contain `name`, `dmg`, `dps`, `share` and `proc`.
The same `dmg`/`dps` fields mean healing/HPS in the healing view. `proc == 1`
marks the native talent/amulet-own-damage distinction; it does not identify a
particular ability, actor, owner, school or periodic effect.

Party rows contain `name`, `class`, `dmg`, `dps`, `share`, `top` and `topdps`.
`top` identifies one leading source by name; it is not a complete breakdown.
The addon currently consumes the hero name/class/totals/rate/share and resolves
portraits separately. It does not invent party spell or healing breakdowns.

The custom meter reads through one five-Hz controller, with displayed rates
limited to one Hz. Its one-to-ten visible rows and scrolling are a viewport,
not a limit on the native source list. It has four distinct periods/behaviors:

- Native whole-run totals and averages for Damage Done and Healing Done.
- Native current/last-encounter totals and averages for Boss Damage.
- Native per-hero totals and rates for Party Damage.
- Addon presentation choices: recent Damage Done DPS over 5–120 native run
  seconds, All, and an independent local X reset across all four views.

### Workarounds we currently maintain

These describe the retained legacy client path. The draft native v1 consumer
bypasses them when the game exposes the contract defined in section 3.

| Area                            | Current approach                                                                                                                                                                            | Why a native contract is needed                                                                                                                                                 |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Row identity                    | Exact translated source name plus the proc flag keys local baselines and recent history.                                                                                                    | Same-name abilities, effects, pets or heroes cannot be distinguished reliably; changing language changes the apparent identity.                                                 |
| Ability icons                   | The meter sends only `name`, healing context and `proc` to the shared SCT icon resolver. Ordinary rows eventually become `CombatIcon({ spell = name })`.                                    | A pet, item or talent name has to pass through a spell-name lookup without authoritative source metadata.                                                                       |
| Spellbook and talents           | Dirty book/talent scans learn name/texture pairs; optional preparation is chunked, with a synchronous completion fallback.                                                                  | Sources outside the current spellbook or learned talents still need metadata. Book-slot APIs are not arbitrary source-ID lookup APIs.                                           |
| Aura metadata                   | Native encounter debuffs and observed target/mouseover auras supply more exact name/texture pairs, including private-tooltip reads.                                                         | A source may never be observed before its target disappears. Observing an aura does not establish who caused historical meter damage.                                           |
| Bundled ability/effect metadata | The addon ships ability, talent and effect name/icon tables alongside a generic spell-icon database.                                                                                        | These tables need maintenance and can miss dynamic or future sources. Native source descriptors should supply the correct metadata directly.                                    |
| DoTs and school collisions      | The generic spell database preserves same-name conflicts. SCT can sometimes refine them with parsed school information.                                                                     | Meter rows provide no school or periodic identity, and the meter does not pass a school to the resolver. SCT event parsing cannot repair missing meter attribution.             |
| Item and jewelry effects        | Generated native jewelry/amulet name/icon tables are followed by exact `GetItemInfo` and equipped-item lookups with throttled retries.                                                      | Historical effects can outlive equipment. The generated general-item catalog is not every possible generated class item or future effect.                                       |
| Pets and summons                | Accepted summon publications teach the shared resolver localized name/portrait pairs, retained after despawn until zone, effective-language or world retirement.                            | Meter rows have no native link to summon IDs or their owner. An unobserved, already-despawned pet cannot teach its historical metadata.                                         |
| Hunter pets                     | The pet view reuses the received summon grouping and explicit Wolf/Raptor family artwork choices before teaching the resolver.                                                              | The meter needs native family/type identity and the actual attack source, independently of the translated pet name or current family choice.                                    |
| Totems                          | The separate official totem feed has ability keys, names, icons and spell IDs; its accepted groups also teach icon metadata.                                                                | Meter rows cannot be joined authoritatively to those keys, an individual caster or a pulse contribution. A live count feed is not a damage ledger.                              |
| Melee                           | Exact English/active-language `Melee` selects the player's current main-hand texture, with a default sword fallback.                                                                        | Current equipment cannot describe every historical weapon, off-hand, pet attack or merged melee producer.                                                                       |
| Generic healing                 | Regeneration, Leech, Healing on Kill, Level Up and Soul Link use five explicit source/icon mappings, matched in the active language only for Healing Done, non-proc rows.                   | The current meter rows do not publish their icons, so the addon maintains these mappings separately. New or changed sources can require another update.                         |
| Languages                       | Generated aliases map exact translated ability/talent names back to canonical candidates; game language is inferred from received zone/class wording because base-client locale can differ. | Colliding translations, external overrides and future wording cannot be made reliable identity keys. The active game language should be explicit.                               |
| Ambiguity and retries           | Most learned tiers retain conflicting name/icon pairs as ambiguous; a bounded final-answer cache and throttled misses avoid repeated scans.                                                 | No lookup chain can recover information that was never published. The spellbook path itself assigns one texture per name, so a later same-name slot can replace an earlier one. |
| Party portraits                 | Unique current player/party names, with compatible class keys, bridge hero rows to native unit portraits.                                                                                   | Equal-name heroes, departed members and roster changes need native actor identity and a supported portrait binding.                                                             |
| Publication readiness           | Getter/table identity, receipt timestamps, local receipt generations and totals synthesize a publication revision; phase/zone/world gates reject retired data.                              | Receipt time is not run identity or an authoritative native revision. Empty, unavailable and not-yet-published data need explicit states.                                       |
| Local X reset                   | Clear the display immediately, then capture per-view counter baselines in the deferred visible reader; subtract later counters and recalculate shares/order.                                | Activity before that capture, or before an unavailable view's first accepted snapshot, is excluded. There is no atomic consumer-owned native reset point.                       |
| Boss transitions                | Counter decreases or disappearing sources are used to recognize fresh encounter counters after a local reset.                                                                               | A new fight whose first observed counters already exceed the previous fight can look like the same encounter. An encounter ID removes that ambiguity.                           |
| Rolling DPS                     | A bounded 604-slot cumulative ring per source/header covers up to 120 seconds; the left window boundary is interpolated between accepted samples.                                           | This is sampled recent history, not an exact native window query. Hiding, gaps, regressions and language changes can retire its coverage.                                       |

These workarounds preserve native totals and use a neutral question mark when
metadata cannot be resolved. A question mark is preferable to assigning an
unrelated spell or pretending to know damage ownership.

Some cache lifetimes also follow different signals: spellbook/item/summon/final
answers track effective language, while learned aura/talent observations clear
through world/logout retirement. Direct metadata keyed by native identity would
remove the meter's dependence on these name/cache interactions.

### Required source and ownership model

Keep these as independent dimensions:

| Dimension      | Example                                           | Required meaning                                                                                                   |
| -------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Owner          | A party hero                                      | The hero credited with the contribution, including owned pets and summons.                                         |
| Actor/caster   | That hero's Hunter pet                            | The actual originating actor, with a stable identity distinct from its owner and other pets.                       |
| Ability/effect | Bite, Claw or a native effect key                 | The actual damage/healing producer, with its own name and icon.                                                    |
| Delivery       | Periodicity plus reflection/application mechanism | How the contribution was applied; independent of actor and trigger. A periodic contribution can also be reflected. |
| Trigger/origin | A talent or item                                  | Native origin when one effect triggers another.                                                                    |

A pet can cast an ability that applies a DoT and triggers a talent. Therefore
`pet`, `ability`, `dot` and `proc` must not be mutually exclusive source types.
Pet portrait artwork and ability artwork must be separate metadata fields.
Periodicity and reflection must also be independent flags/keys, or use explicit
combined native components. Aggregates containing several delivery mechanisms
must report those components or state that they are mixed.

Keep the native proc/meter classification as a separate field, such as
`nativeProc`, so the current blue proc distinction is preserved. Do not derive
that display/accounting classification solely from a trigger or periodic flag.

Require opaque stable `sourceKey`, `actorId`, `ownerId` and ledger `rowId`
values, assigned by the game. Source keys must survive translation, sorting,
equipment changes and UI reload. Actor IDs must distinguish equal-name heroes,
two pets of the same family and reused native spawn slots. IDs can be scoped to
an explicit run/actor lifetime; they must not silently identify a replacement.

Use real native ability/effect keys as the primary source identity. Optional
`spellId`, `itemId`, `talentKey`, `summonKey`, `creatureEntry`, `petFamilyKey`
and `totemKey` describe sources where those values actually exist. Do not invent
spell IDs for custom effects, use a localized name as an ID, or assume one
spell ID uniquely identifies a custom ability and all its pulse variants.

If several producers are grouped into `Pets`, `Talents`, `Other` or a same-name
row, exposing one icon for that group cannot provide the original ability
breakdown. Preserve detailed source attribution when recording damage/healing,
before creating display summaries.

### Coverage: every native producer

The API must cover all supported classes/specs and all native meter-recording
paths, rather than a whitelist of currently recognizable names.

| Source family                    | Required coverage                                                                                                                                                                                                                                  |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Abilities                        | Every active/passive ability, ranks/variants, primary and secondary contributions, triggered and indirect effects, and abilities absent from the current spellbook.                                                                                |
| Periodic effects                 | Every DoT and periodic heal, including stacked/refreshed effects, ground effects, channels and periodic pet/totem attacks. Preserve the real originating actor/owner and ability when ticks continue after death or despawn.                       |
| Hunter pets                      | Every native family/type, permanent and temporary pets, simultaneous same-name pets, family changes, pet melee and every pet ability/DoT. A family portrait must not replace the actual attack identity.                                           |
| Other summons                    | Every class's demons, guardians, minions, clones and other native summons, including expired/dead historical contributors and chained ownership. Publish the native controlling hero without name matching.                                        |
| Totems                           | Every native totem type and its actual damaging/healing effects or pulses, with owner/source keys. Publish individual actor identity when native accounting distinguishes individual totems.                                                       |
| Talents and procs                | Every damage/healing proc, reflected/retaliation effect and chained trigger, with the actual source plus native trigger/origin metadata where available.                                                                                           |
| Items                            | Rings, trinkets, amulets, generated class items, on-use/passive effects and effects continuing after equipment changes. Use the native item/effect icon policy.                                                                                    |
| Melee and basic attacks          | Player/pet melee and other native basic attacks. Publish hand/subtype or weapon identity where native accounting distinguishes them.                                                                                                               |
| Healing and other native credits | Named healing spells, periodic healing, regeneration, leech, healing on kill, level-up healing, Soul Link and every future generic healing producer. Explicitly describe any shield/absorb-consumption credit included in healing.                 |
| Boss encounters                  | The full source breakdown for the native encounter, including owned pet/totem/periodic/item contributions. Publish encounter identity, participating boss identities and whether guardians/elites qualify.                                         |
| Party                            | Stable per-hero totals and complete per-hero source/actor breakdowns for native damage, healing and boss scopes. Current Party Damage exposes much less; party healing/source drill-down would be new API capability, not existing addon behavior. |

Full party breakdowns also need native co-op replication: guests must receive
the authoritative owner/source counters and metadata, not only each hero's
total and leading spell. Exposing a getter over the current reduced party
payload cannot recreate the discarded rows. Define which peer owns accounting
and use that same snapshot's clock for party rates.

Native admitted damage must be counted exactly once. Leaf contributions and
summary/parent rows must be distinguishable. A pet total and its ability rows
are two presentations of the same damage, not independent amounts to add.
Likewise, primary/secondary allocations that partition one admitted hit must
reconcile to that hit rather than duplicate it.

Legitimate generic categories can have native stable keys and metadata. If the
engine lacks the original attribution, report an explicit unknown/mixed bucket
and the limitation. Do not turn missing attribution into a guessed ability,
owner, school or periodic flag.

### Equipment, player abilities, talents and jewelry icons

The source metadata contract must cover these four cases explicitly:

| Source           | Required native metadata                                                                                                                                                                                                                                                |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Equipment        | The actual equipped weapon/item definition and relevant instance/variant, native name and icon, with slot/hand information where applicable. Meter contributions reference the item or attack that produced them.                                                       |
| Player abilities | The abilities the player has learned or selected for the run, including upgrades, ranks, variants, passive effects and triggered components. Return their actual native ability keys, resolved names and icons, including abilities absent from the ordinary spellbook. |
| Jewelry          | Rings, necklaces/amulets, trinkets, generated class jewelry and their damage/healing effects. Return the native item key/name/icon and a stable link to each contributing effect or proc.                                                                               |
| Learned talents  | Every native class/spec/custom talent the player actually has, with its stable talent key, learned rank, resolved native name and icon, and links to its damage/healing effects, procs or modified abilities.                                                           |

Ordinary equipped inventory and the game's run build/pickups are distinct
sources of metadata. One must not be inferred from the other. If the game exposes
the current equipment/build/ability/talent list, it should use the same stable keys as
the meter's source descriptors so the addon can join them directly.

For talents, keep the talent's own icon distinct from the icon of an ability or
effect it triggers or modifies. Learning a talent does not automatically create
a separate damage/healing row: expose its actual native contribution or origin
link, without counting the same modified ability damage again. Learned rank and
build changes should update native metadata while retaining historical talent
contributions and their original source identity after a respec or UI reload.

An item icon and its triggered ability/effect icon can be different. Publish
both where relevant, and explicitly identify the artwork intended for the
native meter row. A jewelry proc should not receive an unrelated same-name
spell icon, and an ability should not lose its own identity because an item
triggered it. This also applies to party members' native source metadata.

Current-loadout metadata complements the complete meter ledger; it must not be
required to recover an old row. After a weapon/jewelry swap, ability/talent change or
UI reload, retain the original source/variant metadata for recorded contributions.
Equipment that has not contributed damage/healing can still have metadata in a
build/inventory API; it must not create a fabricated meter row.

### Metadata and all fourteen languages

For every referenced source and actor, return the exact native display metadata:

- Stable untranslated key and metadata revision.
- Resolved display name in the selected game language; a localization key where
  one exists, without matching the display name back to another catalog.
- A usable native icon path/handle, or explicit missing/pending status. Include
  distinct ability/effect icon and pet/hero portrait metadata as appropriate.
- Relevant stable class, family, summon, totem, item and talent keys. Class/family
  keys must not depend on translated labels.
- A supported actor-to-unit/portrait binding or retained portrait descriptor for
  hero rows, rather than requiring a unique name match to `party1`–`party4`.

Expose the actual selected game language and a language/metadata revision.
The fourteen currently supported catalog codes are `en`, `pl`, `cs`, `de`,
`pt`, `es`, `fr`, `ro`, `tr`, `ru`, `uk`, `zh`, `ja` and `ko`. Future languages
should follow the same contract without an addon source-ID update.

Names should follow the game's own fallback and external translation overrides.
Preserve UTF-8, punctuation, brackets, spaces and numeric-looking names as text.
Use correctly typed Lua tables or a lossless transport; delimiter sanitizing and
automatic text-to-number coercion must not change names or merge identities.
Language changes update labels, not counters, source keys, reset checkpoints or
encounter identity. Two different sources with the same translated label must
remain separate.

Keep source/actor metadata available for the entire retained ledger lifetime,
including after pet death/despawn, equipment changes, party departure or addon
reload. Metadata lookup must not depend on the addon observing a live summon,
target aura, equipped item or open native meter window earlier in the run.

Define the icon policy for historical rows: canonical source artwork versus a
recording-time variant. If a meaningful variant changes identity/artwork, expose
that variant explicitly. Do not silently substitute the current weapon or pet
family for an unrelated historical contributor.

Addon-owned settings, fonts, compact number formatting and custom UI captions
can remain local. Native gameplay names and artwork should come from the game;
an explicit game-language code also lets the addon select its own UI translations
without guessing from zone/class strings.

### Counters, rates, reset and snapshot guarantees

| Contract                | What the game should guarantee                                                                                                                                                                                                                                                                                                     |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Capabilities/version    | Explicit supported metrics, scopes, breakdowns and API/schema version. Unsupported must differ from valid zero activity.                                                                                                                                                                                                           |
| Run identity            | A `runId` that changes for each actual run and survives pause, language changes and a UI reload during that run. Include a counter epoch/reason for real corrections or resets.                                                                                                                                                    |
| Encounter identity      | An `encounterId`, active/completed state, participating bosses and native start/end/elapsed times. Preserve multi-boss encounter semantics and current/last encounter availability.                                                                                                                                                |
| Atomic reads            | Counters, phase, native clock, run/encounter IDs and revision from one authoritative generation. Do not combine a party HUD counter with an unrelated local/host/guest clock.                                                                                                                                                      |
| Readiness               | Explicit ready, ready-empty, not-ready and unsupported/unavailable states. Define the state when no party exists. A freshly created empty Lua table must not be mistaken for an accepted empty snapshot.                                                                                                                           |
| Completeness            | Full source/actor lists, not the native window's visible/top rows. If transport needs pages/chunks, use one snapshot revision and explicit completion so the addon cannot accept half a ledger.                                                                                                                                    |
| Numeric precision       | Return native numeric counters with documented precision. Do not round to integer damage, one-decimal DPS or display percentages before publication. Unknown values remain absent/status-marked, not fabricated zeros.                                                                                                             |
| Damage accounting       | State whether totals are effective health damage, attempted damage or another native credit. Define overkill, mitigation, reflection, shared/chained damage and pet/owner inclusion. Keep display totals consistent with native accounting.                                                                                        |
| Healing accounting      | Preserve effective-healing semantics and document whether credited healing includes shield/absorb consumption such as Soul Link. Expose actual health restoration, overheal or absorbs separately only where recorded; never double count the same credit.                                                                         |
| Aggregation             | Define disjoint leaf contributions versus rollups, source/owner grouping and mixed components. Totals, queried shares and source rankings must agree within documented precision.                                                                                                                                                  |
| Average rates           | Return the native numerator and elapsed denominator for whole-run, encounter and since-checkpoint averages. Define zero-time/warmup, pause, choosing, death and victory behavior.                                                                                                                                                  |
| Rolling rates           | Native on-demand 5–120-second windows and All, using authoritative run time and retained aggregate history. Return actual start/end, elapsed, coverage and resolution. Bucketed/interpolated boundaries must be labelled approximate.                                                                                              |
| X reset                 | Capture an opaque consumer-owned checkpoint atomically across damage, healing, boss and party scopes at the request, rather than waiting for the next visible poll. Query since that checkpoint without clearing gameplay totals, the native window or another addon's session. Bound and release checkpoint resources explicitly. |
| Boss/reset interaction  | A newly created encounter starts fresh independently of an older checkpoint. Offer encounter-average and since-checkpoint-average as explicit different rate scopes. Current SDUI post-X averages use run seconds since Reset in all four views; do not silently replace that behavior with encounter elapsed time.                |
| Revisions/notifications | Separate counter, metadata and clock changes. Notify only after native state is coherently published. Unchanged getter results should be cheap; phase/time may still advance when counters do not.                                                                                                                                 |
| Recovery                | Return complete current state after late initialization, UI reload, reconnect or co-op late join, including historical source metadata. Report explicitly when retained history/checkpoints are no longer available.                                                                                                               |

The current recent-DPS ring discards coverage after hidden periods, gaps over
two native run seconds, regressions and disappearing sources. It also continues
reading Damage Done while another meter tab is visible to maintain history.
Native window queries should remove that requirement: the addon can stay idle
while hidden/off and ask the game's retained aggregates when shown again.

Keep three amounts distinct: `periodAmount` for the full run/encounter,
`sinceCheckpointAmount` for activity after X, and `windowAmount` for the
requested recent interval. Return the corresponding elapsed denominators and
rates separately. Existing SDUI totals, bars, shares and rankings use full-period
amounts before X and since-checkpoint amounts afterwards; recent DPS changes the
rate column, not the amount used to rank the rows. All selects the applicable
whole-period or since-checkpoint average.

After X, clamp the recent window's start to the checkpoint so damage from before
Reset cannot reappear in recent DPS. X during a boss encounter excludes that
fight's earlier contributions. An encounter starting after X includes its full
contributions; a completed encounter entirely before X has zero checkpoint
amount. These amounts remain separate from the chosen average-rate denominator.

The current X baseline is captured later than the click and is keyed by names.
An atomic checkpoint removes both the timing gap and language-change rebaselining.
If a checkpoint is invalid after a new run or reconnect, return an explicit
status; never silently reuse another run's counters.

Optional extra statistics such as hit/crit/tick/cast counts, damage taken,
overhealing and absorb totals should be advertised only if the game records
them. Counts must not be calculated from rounded totals or guessed from
damage size. They are extensions to the current four-view UI, not fields it
already receives.

### Fixed interface

Section 3 is the binding implementation contract. Every successful meter
snapshot contains its complete source and actor descriptors; a separate metadata
read is not required. Current equipment, abilities, learned talents and run
jewelry have a separate complete loadout getter using the same keys.

The meter API uses native aggregates and does not require an addon combat log.
Polling is sufficient; version 1 adds no Lua event, callback subscription or
per-frame meter broadcast. Live position and complete meter accounting remain
separate data requirements.

### What this would remove from the meter

Once the complete contract is available and the addon adopts it, meter rows
could stop relying on translated-name mappings, bundled source/icon
catalogs, spellbook/talent scans, target/mouseover tooltip scans, equipment
searches, observed-summon icon learning, the five special healing mappings and
party-name portrait matching. It would also replace local reset baselines,
boss-counter regression detection, publication identity heuristics and the
sampled recent-DPS ring.

Some of those helpers also serve SCT or other addon views. A meter migration
would remove the meter's dependency on them, not automatically authorize their
deletion from unrelated consumers.

Keep the existing getters compatible while introducing the versioned contract.
The addon should select a supported complete data path for each view and avoid
mixing legacy name-only counters with unrelated new metadata or clocks. Older
clients can retain the current fallback until the required capability exists.

The addon would still own the window, four-view navigation, artwork, pooling,
fonts, row limits, sorting/presentation choices, local settings, Layout and
native HUD visibility handoff. Deterministic grouping/formatting of complete
native data is normal presentation; guessing identity from text is the work
the new API should eliminate.

### Native acceptance checklist

These are requested game-side/API scenarios, not tests run during this audit:

- Compare complete source leaves, rollups and totals with the native ledger for
  every supported class/spec and every meter producer, including all DoTs and
  indirect/zero-spell-ID or suppressed-log paths. Use the game's producer/catalog
  coverage, not an addon-maintained spell-name whitelist.
- Exercise every Hunter family and other summon/totem type; simultaneous
  same-name pets, pet abilities/DoTs, chained summons, despawn before opening
  the meter and delayed ticks after their caster disappears must retain credit.
- Exercise item swaps, generated items, talents, identical names with different
  sources, direct-plus-periodic abilities, multi-school effects and generic
  healing/absorb credits. Verify no parent/child or owner/pet double counting.
- Verify equipped weapon/item icons, selected/upgraded ability icons and every
  jewelry category against the native source. Distinguish an item's icon from
  its triggered ability/effect icon, including historical rows after swaps and
  abilities or run pickups absent from the standard inventory/spellbook.
- Verify learned talent keys, ranks, names and icons for every supported
  class/spec, including passive and proc talents. Preserve native links to
  modified/triggered abilities, avoid duplicate credit, and retain historical
  contributions across talent/build changes in every supported language.
- Run equivalent scenarios in all fourteen languages, then change language
  mid-run and after X. Only labels/art metadata may change; IDs, amounts,
  checkpoint deltas and encounters must remain continuous. Include translation
  collisions, external overrides, UTF-8 and delimiter/numeric-looking names.
- Verify host and guest perspectives, late join, equal-name heroes, roster
  reorder, leave/rejoin and disconnect/reconnect. Party owner totals and complete
  ability/healing/boss breakdowns must use the same authoritative clock/snapshot.
- Test consecutive boss fights with identical sources and larger next-fight
  counters, simultaneous bosses and the native guardian/elite classification.
  Explicit encounter IDs must identify every boundary without counter guesses.
- Test X during active damage/healing, unavailable views, pause, zero elapsed
  time, window changes, hidden/off periods, UI reload and a new run. Verify
  checkpoint capture time, history coverage and explicit expiry/recovery states.
- Reset inside a busy recent-DPS window and verify pre-X contributions never
  return through the rate query. Check period, checkpoint and recent amounts,
  shares/rankings and every denominator independently, including a mid-fight X.
- Confirm a usable first snapshot contains complete native metadata even when
  the addon never observed the live spell, pet, item or target. Verify empty,
  unsupported and not-yet-ready results remain distinguishable.

### Scope and implementation references

This proposal describes the APIs consumed by the addon and the native data
contract requested from the game. The game developer should confirm current
capabilities and any additional accounting or co-op publication work needed.

Current addon behavior is visible in the [meter controller](../modules/ui/meter.lua),
[local reset and rolling rates](../core/meter_rates.lua),
[shared icon resolver](../modules/nameplates/sct.lua),
[pet/totem metadata reader](../modules/unit/pets.lua) and
[game-language selection](../core/localization.lua).

Section 3 defines the exact requested interface; its examples follow that
contract. No game/addon execution or local tests were performed for this
document, and no runtime code was changed.

## 3. Version 1 implementation contract

This section is normative. Implement these exact global function names,
arguments, field names, types, enumerations and failure rules. The earlier
sections explain the requirements; this section fixes their interface.
These are new game APIs to implement, not claims that they already exist.

### 3.1. Common types and calling rules

| Type       | Exact definition                                                                                                                                                            |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Id`       | Nonempty opaque string. IDs, revisions and tokens are never numeric GUIDs, translated names, unit-list indexes or texture object addresses. Compare them for equality only. |
| `Number`   | Finite Lua number. No NaN or infinity. Preserve native precision; do not round counters for display.                                                                        |
| `Integer`  | `Number` with no fractional part, within `0..9007199254740991`, further restricted where specified.                                                                         |
| `Amount`   | Nonnegative `Number` in native damage/healing units.                                                                                                                        |
| `Seconds`  | Nonnegative `Number` in authoritative run seconds, unless explicitly called real seconds.                                                                                   |
| `Text`     | UTF-8 string, preserved exactly, including punctuation and numeric-looking names. Names are nonempty.                                                                       |
| `Array<T>` | Dense one-based Lua table. Empty is `{}`. No holes or extra named fields. Native construction must support the client's normal array-length operations.                     |
| `Map<T>`   | Lua table keyed by `Id`, with values of type `T`.                                                                                                                           |

Required fields must exist. Optional fields are absent (`nil`), never fake zero,
empty-string IDs or the text `"nil"`. Booleans are actual `true`/`false`.
No argument coercion is permitted: `"10"` is not the number `10`.
Enum strings are case-sensitive. IDs and text are never trimmed or normalized.

Request tables are never modified. Unknown request keys, extra positional
arguments and wrong types are errors. A named optional parameter omitted or
explicitly set to `nil` has the same meaning. Return tables are detached from
native mutable state: the game never changes a previously returned result, and
editing it cannot affect gameplay, another caller or a later result.
Request tables must be plain tables without a metatable. Validate/read them
through raw access so Lua metamethods cannot fabricate fields or throw during
validation. Return table fields may be extended in a later minor version;
clients ignore unknown response fields but never unknown enum values silently.

Every function uses exactly two return values:

```lua
result, nil       -- success: result is a table or true, as specified
nil, error       -- failure: error is ApiError
```

Ordinary invalid arguments, unavailable state and resource failures must not
throw a Lua error. A failed call returns no partial result and changes nothing.
The portrait setter writes only its supplied texture on success; checkpoint
creation/release changes only that checkpoint's private resources. None of
these APIs changes gameplay counters, native HUD preferences or another
consumer's statistics.

| Function                                            | Parameters                                                            | Successful result |
| --------------------------------------------------- | --------------------------------------------------------------------- | ----------------- |
| `AZS_GetMeterCapabilities()`                        | None.                                                                 | `Capabilities`    |
| `AZS_GetMeterContext()`                             | None.                                                                 | `Context`         |
| `AZS_GetPlayerPosition()`                           | None.                                                                 | `PlayerPosition`  |
| `AZS_GetMeterSnapshot(query)`                       | One `MeterQuery`.                                                     | `MeterSnapshot`   |
| `AZS_GetMeterLoadout(query)`                        | One `LoadoutQuery`.                                                   | `MeterLoadout`    |
| `AZS_CreateMeterCheckpoint(runId)`                  | Expected current `runId: Id`.                                         | `Checkpoint`      |
| `AZS_ReleaseMeterCheckpoint(checkpointId)`          | Previously issued `checkpointId: Id`.                                 | `true`            |
| `AZS_SetMeterPortrait(texture, runId, portraitKey)` | Native Texture object, current `runId: Id`, issued `portraitKey: Id`. | `true`            |

All eight functions must be present when the version 1 API is advertised.
Existing `AZS_GetMeter`, `AZS_GetHealing`, `AZS_GetBossMeter`,
`AZS_GetPartyMeter` and their legacy fields retain their existing behavior.

### 3.2. Errors and validation order

`ApiError` has these fields:

| Field               | Type              | Required                    | Meaning                                                                                                            |
| ------------------- | ----------------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `code`              | String enum below | Yes                         | Stable untranslated machine-readable code.                                                                         |
| `message`           | Nonempty string   | Yes                         | English developer-facing explanation; callers must not parse it.                                                   |
| `argument`          | String            | No                          | Offending argument/field path, such as `query.windowSeconds`. Present for argument/version errors.                 |
| `retryable`         | Boolean           | Yes                         | Whether the same call can succeed after native state advances without changing arguments or acquiring a new token. |
| `retryAfterSeconds` | `Number > 0`      | If retryable                | Suggested minimum delay in real seconds. Not a gameplay clock.                                                     |
| `reason`            | String enum below | For checkpoint invalidation | Exact invalidation cause.                                                                                          |

| Code                     | Retryable | Delay  | Meaning/action                                                                                                  |
| ------------------------ | --------- | ------ | --------------------------------------------------------------------------------------------------------------- |
| `INVALID_ARGUMENT`       | false     | Absent | Arity, unknown key, wrong type, invalid enum/range or forbidden field combination. Correct the request.         |
| `UNSUPPORTED_VERSION`    | false     | Absent | `query.apiVersion` is an integer other than `1`.                                                                |
| `UNSUPPORTED_QUERY`      | false     | Absent | The advertised implementation cannot supply the requested metric/scope/grouping. Never substitute another view. |
| `NO_WORLD`               | true      | 1      | No loaded gameplay world.                                                                                       |
| `NO_PLAYER`              | true      | 0.2    | World exists, but the local player is not available.                                                            |
| `NO_RUN`                 | true      | 1      | No current or retained current-run meter context.                                                               |
| `RUN_MISMATCH`           | false     | Absent | Supplied run ID differs from the current retained run. Read context and select the new run explicitly.          |
| `NOT_READY`              | true      | 0.2    | Required native counters, names or related descriptors are not yet a complete coherent state.                   |
| `NO_PARTY`               | true      | 1      | This run has no party accounting scope.                                                                         |
| `NO_ENCOUNTER`           | true      | 0.2    | No current or completed boss encounter exists in this run.                                                      |
| `UNKNOWN_OWNER`          | false     | Absent | Owner ID is not a hero belonging to this run.                                                                   |
| `OWNER_NOT_PRESENT`      | true      | 1      | Historical owner exists, but a current loadout is unavailable because that owner is no longer present.          |
| `INVALID_CHECKPOINT`     | false     | Absent | Token was not issued by this API or is malformed.                                                               |
| `CHECKPOINT_EXPIRED`     | false     | Absent | Token was released, its UI session ended, or its world lifetime ended. Acquire a new checkpoint.                |
| `CHECKPOINT_INVALIDATED` | false     | Absent | Issued token belongs to another run, counter epoch or authority. Acquire a new checkpoint.                      |
| `RESOURCE_LIMIT`         | false     | Absent | Active checkpoint quota is full. Release a handle before creating another.                                      |
| `UNKNOWN_PORTRAIT`       | false     | Absent | Key is not an issued retained portrait for the requested run.                                                   |
| `ART_NOT_READY`          | true      | 0.2    | Known portrait is still being prepared.                                                                         |
| `ART_UNAVAILABLE`        | false     | Absent | Native portrait cannot be supplied. Use the addon's neutral artwork.                                            |
| `INTERNAL_ERROR`         | true      | 1      | Native implementation failed. No partial result or texture write is permitted.                                  |

`CHECKPOINT_INVALIDATED.reason` is exactly `"run_changed"`,
`"counter_epoch_changed"` or `"authority_changed"`.

Apply checks in this order: arity and request-field types/ranges; request
version; supported query combination; world/player; current run and expected
run ID; owner/party/encounter selection; checkpoint; publication readiness;
operation. Check request fields in their declaration order below. Unknown keys
are reported after declared-field validation, in bytewise key order. A non-string
request key is `INVALID_ARGUMENT` with `argument = "query"`.
Within the unknown-key stage, reject any non-string key before sorting/reporting
unknown string keys. This does not preempt an earlier declared-field failure.
Owner-dependent feature checks occur immediately after resolving a valid owner,
before publication readiness. They are the exception to the earlier unconditional
feature check; no world/run/owner is guessed just to perform that check.

Capabilities bypass all world/run checks. Position bypasses run checks.
Release bypasses world/run/readiness checks and follows section 3.10.
For meter/context/loadout/checkpoint/portrait calls, the player check requires
the retained local hero identity, not a living unit or usable position. Dead or
completed-run statistics remain readable while that world/run is retained.
Only the position getter requires a current valid native player transform.
Missing optional artwork is handled by descriptor status, not by discarding
otherwise valid meter counters. Recent-history failure is a rate status inside
a successful snapshot, as specified in section 3.12.

### 3.3. `AZS_GetMeterCapabilities()`

Callable at login, outside a run and without a loaded world. Returns:

| Field                      | Type/value                                                                                                                                       |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `apiVersion`               | Integer `1`.                                                                                                                                     |
| `apiMinor`                 | Integer `0`. New optional response fields may be added in later minor versions; meanings/types/enums here must not change.                       |
| `uiSessionId`              | `Id`, changed on every UI initialization/reload.                                                                                                 |
| `languageCode`             | Actual selected game catalog code, available even without a world/run.                                                                           |
| `languageRevision`         | Id changed when language selection or active external caption overrides change.                                                                  |
| `metrics`                  | Array exactly `{ "damage", "healing" }`.                                                                                                         |
| `healingPerspectives`      | Array exactly `{ "received", "performed" }`. Received preserves the current native healing-view meaning.                                         |
| `scopes`                   | Array exactly `{ "self", "party", "owner" }`.                                                                                                    |
| `periods`                  | Array exactly `{ "run", "encounter" }`.                                                                                                          |
| `groupings`                | Array exactly `{ "source", "owner", "actor_source", "detail" }`.                                                                                 |
| `minWindowSeconds`         | Integer `5`.                                                                                                                                     |
| `maxWindowSeconds`         | Integer `120`.                                                                                                                                   |
| `historyResolutionSeconds` | `Number` in `0..0.2`. Zero means exact native time boundaries; otherwise section 3.12's cumulative-sample interpolation applies.                 |
| `historyRetentionSeconds`  | Integer `120`; retain at least this recent native-run interval plus the bracketing samples needed at its boundary.                               |
| `maxCheckpoints`           | Integer `64`, shared by consumers in this UI session; no silent eviction.                                                                        |
| `languageCodes`            | Array `{ "en", "pl", "cs", "de", "pt", "es", "fr", "ro", "tr", "ru", "uk", "zh", "ja", "ko" }`; later minor versions may append supported codes. |
| `features`                 | Table below, all entries actual booleans and all required `true` for a complete version 1 implementation.                                        |

`features` contains exactly these required keys: `liveInstancePosition`,
`completeSourceBreakdowns`, `partySourceBreakdowns`, `partyHealing`,
`performedHealing`,
`nativeSourceIcons`, `currentLoadouts`, `partyLoadouts`, `retainedPortraits`,
`atomicCheckpoints`, `nativeRecentWindows` and `localizedMetadata`.

Every combination of the listed metric/scope/period/grouping values is supported.
A staged implementation must report unavailable features as `false` and return
`UNSUPPORTED_QUERY` for affected calls; it must not claim complete conformance.
Position requires `liveInstancePosition`; loadout requires `currentLoadouts`
and additionally `partyLoadouts` for remote heroes; portrait binding requires
`retainedPortraits`; checkpoint calls require `atomicCheckpoints`.
The exact additional snapshot gates are:

| Condition                                      | Required feature(s)                                                            |
| ---------------------------------------------- | ------------------------------------------------------------------------------ |
| Every snapshot, including owner rollups        | completeSourceBreakdowns, nativeSourceIcons, localizedMetadata.                |
| scope=party or scope=owner                     | partySourceBreakdowns; callers needing only the local hero may use scope=self. |
| metric=healing with scope=party or scope=owner | partyHealing.                                                                  |
| healingPerspective=performed                   | performedHealing.                                                              |
| windowSeconds > 0                              | nativeRecentWindows.                                                           |
| checkpointId supplied                          | atomicCheckpoints.                                                             |

A false required feature is UNSUPPORTED_QUERY, not omitted fields, fake missing
art or a totals-only response. The loadout's remote-owner gate is checked after
owner resolution; its unconditional currentLoadouts gate precedes world checks.
Loadout also unconditionally requires nativeSourceIcons and localizedMetadata.
Context needs no feature gate. The advertised capabilities are constant for a
UI session except append-only language support; they do not depend on which
party member, talent or item happens to be visible.
This constancy applies to feature/version/range support, not the selected
languageCode/languageRevision, which update when the game's language changes.
Version 1 defines no extra metric names. Additional statistics require a
separately specified extension, rather than undocumented query fields.

### 3.4. `AZS_GetMeterContext()` and common snapshot identity

Returns a complete `Context`, or `NO_WORLD`, `NO_PLAYER`, `NO_RUN` or
`NOT_READY` according to section 3.2. A completed current run remains readable
until a new run replaces it or the world is left.

| Context field      | Type/value                                                                                                                  |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| `apiVersion`       | Integer `1`.                                                                                                                |
| `uiSessionId`      | Current `Id`.                                                                                                               |
| `runId`            | `Id` assigned once per actual run; unchanged through pause, language changes and UI reload.                                 |
| `authorityId`      | `Id` of the authoritative accounting generation shared by host/guests. A true authority replacement changes it.             |
| `counterEpoch`     | `Id`, changed on corrections/rebases that invalidate prior counter comparisons.                                             |
| `snapshotId`       | `Id` for this complete committed capture, including its clock and metadata. It is an equality token, not an ordered number. |
| `counterRevision`  | `Id`, changed when any run counter/source roster changes.                                                                   |
| `metadataRevision` | `Id`, changed when any returned source/actor label, artwork or definition metadata changes.                                 |
| `languageCode`     | The actual selected game catalog code, independently of base-client locale.                                                 |
| `languageRevision` | Id for the captured game-language/override state, using the same namespace as capabilities.languageRevision.                |
| `phase`            | `"ready"`, `"playing"`, `"choosing"`, `"paused"`, `"dead"` or `"victory"`.                                                  |
| `asOfRunSeconds`   | `Seconds` captured with these counters; advances only while `phase == "playing"`.                                           |
| `localOwnerId`     | Stable hero `Id`.                                                                                                           |
| `partyState`       | `"solo"`, `"active"` or `"ended"`. Ended means a party existed in this run and its historical scope remains readable.       |
| `partyId`          | `Id` iff partyState is not solo.                                                                                            |
| `encounter`        | `Encounter` iff a current/last encounter exists; absent otherwise.                                                          |

`Encounter` has required `encounterId: Id`, `state: "active" | "completed"`,
`startRunSeconds: Seconds` and `bossActorIds: Array<Id>`; it also has
required `startFenceId: Id`, and `endRunSeconds: Seconds` plus `endFenceId: Id`
iff completed. These fences identify native admission order, not polling order.
This selects the active encounter,
otherwise the most recently completed encounter. Version 1 does not query
older encounter archives. The boss membership follows the game's boss
classification; unrelated guardians/elites must not silently extend it.

Each meter/loadout response embeds its own complete `context: Context`.
Separately read contexts are not a transaction. Callers use the context inside
the returned result, not an earlier context's clock. Host/guest queries return
authoritative counters and their accompanying authoritative time; never combine
received party amounts with an independently sampled local clock.

Clock-only changes can produce a new snapshotId without a counter revision.
Metadata-only changes do not reset counters/checkpoints. Polling is sufficient;
the game may keep its current publication cadence. It must assemble a complete
capture before exposing it to Lua, including after internal chunked delivery.
asOfRunSeconds is nondecreasing within a runId/authorityId/counterEpoch. A native
clock correction/regression must change counterEpoch and invalidate checkpoints
and recent history, or remain NOT_READY until coherent. No successful result
may yield negative elapsed time from a valid checkpoint.

### 3.5. `AZS_GetPlayerPosition()`

Returns `PlayerPosition, nil`, or `nil, ApiError`. No parameters. A loaded
player position is readable outside a run; no phase or packet gate is allowed.

| Field         | Type/value                                                                                                                         |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `apiVersion`  | Integer `1`.                                                                                                                       |
| `mapId`       | Integer `0..4294967295`. Zero is a valid map.                                                                                      |
| `spaceId`     | `Id` identifying the actual map instance and coordinate epoch. Changes when coordinates cease to describe the same world/instance. |
| `sampleId`    | `Id` identifying the current rendered-frame position sample.                                                                       |
| `x`, `y`, `z` | Signed finite `Number`, in yards: X north, Y west, Z up. Same world coordinates as cache/lair `x/y/z`.                             |
| `facing`      | `Number` in `[0, 2*pi)`, zero north/+X, increasing counterclockwise toward west/+Y. Zero is valid.                                 |
| `runId`       | Current `Id` when available, absent outside a run.                                                                                 |

Sample the current position used to center the native minimap for that rendered
frame, including native movement interpolation. Do not return a renamed packet
cache or interpolate the old `AZS_RUN` fields in Lua. Repeated calls in one
valid rendered frame/space return the same sampleId and values; the next frame has a new
sampleId even if stationary. During load/teleport before the new position is
valid, return `NOT_READY`; do not blend between coordinate spaces.
Opening/browsing the world map must not change this result or its selection.
The render sample must be installed before addon frame callbacks. Before the
first valid sample, return NOT_READY rather than a packet-derived substitute.

For a verifiable coordinate-space join, version 1 also adds these required
fields to every published AZS_CHESTS and AZS_LAIRS destination entry, alongside
the existing fields: `runId: Id`, `mapId: Integer 0..4294967295`, and
`spaceId: Id`. Preserve existing getters/fields and empty-list semantics.
The current entries must share the position getter's native coordinate basis;
an addon projects an entry only when all three tags match. After a space/run
transition, retire old entries before accepting new ones. A mismatched tag
means defer/hide that destination, never reuse its old world coordinates.
Failure codes: `UNSUPPORTED_QUERY`, `NO_WORLD`, `NO_PLAYER`, `NOT_READY`,
`INTERNAL_ERROR`, plus common argument errors.

### 3.6. `AZS_GetMeterSnapshot(query)`

`MeterQuery` fields, in validation order:

| Field                | Type        | Required/default                                                 | Exact meaning                                                                                                      |
| -------------------- | ----------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `apiVersion`         | Integer     | Required                                                         | Must be `1`.                                                                                                       |
| `runId`              | `Id`        | Required                                                         | Expected retained current run; never silently switch runs.                                                         |
| `metric`             | String enum | Required                                                         | `"damage"` or `"healing"`.                                                                                         |
| `healingPerspective` | String enum | Optional for healing, default `"received"`; forbidden for damage | `"received"` groups healing by beneficiary; `"performed"` groups it by the actual source's controlling hero.       |
| `scope`              | String enum | Required                                                         | `"self"`, `"party"` or `"owner"`.                                                                                  |
| `ownerId`            | `Id`        | Required iff scope is owner                                      | Forbidden for self/party. Identifies a hero, not a pet or unit token. Its healing role follows healingPerspective. |
| `period`             | String enum | Required                                                         | `"run"` or `"encounter"`; encounter means current/last as defined above.                                           |
| `groupBy`            | String enum | Required                                                         | `"source"`, `"owner"`, `"actor_source"` or `"detail"`.                                                             |
| `windowSeconds`      | Integer     | Required                                                         | `0` for All, otherwise `5..120` inclusive.                                                                         |
| `checkpointId`       | `Id`        | Optional, absent                                                 | Successful checkpoint token from this UI session/run/authority/epoch.                                              |

`self` selects localOwnerId, including contributions credited to that hero's
pets/summons/totems. `owner` selects one known hero, including a departed hero's
retained history. `party` selects the local hero and every hero admitted to this
run's party accounting, retaining departed contributors. It never imports
another run's totals. Before any party exists, return `NO_PARTY`; after a party
ends, retain that run's historical party scope. Late joins require authoritative
complete sync; return `NOT_READY` until it exists, not a partial success.

For healing, the selected heroes are beneficiaries in received mode and source
owners in performed mode. Normalized query includes healingPerspective for
healing, including its received default; it omits that field for damage.
Received and performed views are different perspectives on the same credit;
never add their totals together. Healing from unowned sources contributes to received
views but not to a hero's performed total. If an unresolved source owner could
affect a performed query, return NOT_READY until it is known or explicitly
unowned; do not silently omit potentially matching healing.
Similarly, received queries match known credited beneficiary heroes; unowned
recipients do not belong to a hero's received total, and unresolved potentially
matching recipient ownership is NOT_READY. The beneficiary follows native
healing credit, not a guess that every currently owned pet's health belongs in
its owner's legacy received total. A performed view may include a hero healing
an unowned recipient, preserving that recipient's explicit ownership state.

For period=encounter, damage includes only native effective damage to that
encounter's bossActorIds at credit time, filtered before grouping. Damage to
other enemies during the fight is excluded. Open the encounter before admitting
its first qualifying credit and commit its completion after the final killing
credit. Encounter healing means credits admitted from its start fence through
its completion fence for the selected beneficiaries/performers; it does not
mean healing the bosses. Equal run timestamps are resolved by those fences.

Damage is effective HP damage actually admitted by the game, excluding overkill
and unconsumed blocked/absorbed amounts. Healing is effective HP restoration
plus native healing credit for consumed shields; the exact credit type is
preserved per contribution. Applying a shield without consumption and overheal
are not counted as HP restored. This preserves native shield-consumption credit
without counting it again as a second heal. Other statistics are outside v1.

Return `MeterSnapshot`:

| Field           | Type/value                                                                                                                       |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `apiVersion`    | Integer `1`.                                                                                                                     |
| `status`        | `"ready"` or `"ready_empty"`; never a not-ready partial result.                                                                  |
| `complete`      | Boolean `true`.                                                                                                                  |
| `context`       | This result's `Context`.                                                                                                         |
| `query`         | Detached normalized MeterQuery; healing receives its explicit default healingPerspective, other omitted optionals remain absent. |
| `ownerIds`      | Dense array of selected hero IDs, ordered by native first admission, then bytewise ID.                                           |
| `amountBasis`   | `"period"` without checkpointId, `"checkpoint"` with one.                                                                        |
| `period`        | `Period` below.                                                                                                                  |
| `checkpoint`    | `Checkpoint` iff checkpointId was requested.                                                                                     |
| `totals`        | `Stats` for the complete selected scope.                                                                                         |
| `contributions` | `Array<Contribution>` of disjoint cumulative leaf aggregates. This is not a per-hit log.                                         |
| `rows`          | `Array<MeterRow>` of requested display grouping.                                                                                 |
| `maxRowAmount`  | Maximum row displayAmount, or numeric zero for no rows.                                                                          |
| `sources`       | Complete `Map<SourceDescriptor>`.                                                                                                |
| `actors`        | Complete `Map<ActorDescriptor>`.                                                                                                 |

`Period` has required `kind: "run" | "encounter"`, `startRunSeconds`,
`endRunSeconds` and `elapsedSeconds`, all Seconds. Run start is zero and end is
context.asOfRunSeconds. Encounter start is its native start; end is current
asOfRunSeconds while active and its native end while completed. Encounter
periods also contain the selected `encounter: Encounter`. elapsedSeconds is
exactly end minus start, never negative.

All source/actor IDs used anywhere in this result, including encounter bosses,
owners, parent actors and origin/related sources, resolve in these maps.
Include transitive descriptor references. An unavailable required name or
identity is `NOT_READY`; pending/missing artwork has its own explicit status.
No native window/top-N/row-limit truncation is permitted.

### 3.7. Exact counter, row and rate tables

`Stats` fields:

| Field                   | Type/availability                                                                              |
| ----------------------- | ---------------------------------------------------------------------------------------------- |
| `periodAmount`          | Required Amount over the selected full period.                                                 |
| `sinceCheckpointAmount` | Amount iff a checkpoint was requested.                                                         |
| `windowAmount`          | Amount iff windowSeconds is positive and recent history is available, including during warmup. |
| `displayAmount`         | Required Amount: periodAmount or sinceCheckpointAmount according to amountBasis.               |
| `periodAverage`         | Required ready `Rate`.                                                                         |
| `checkpointAverage`     | Ready Rate iff a checkpoint was requested.                                                     |
| `recentRate`            | Required Rate; not_requested when windowSeconds is zero.                                       |
| `displayRate`           | Required Rate: recentRate for a positive window; otherwise checkpointAverage or periodAverage. |

Every `Contribution` contains all Stats fields plus:

| Field                             | Type/value                                                                                                                                                                                                      |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `rowId`                           | Stable Id for this run/metric/healing perspective/period/encounter and full attribution tuple. Not a rank. Independent of language, revision, checkpoint and window.                                            |
| `ownerId`, `actorId`, `sourceKey` | Required Id values: query's accounting hero, actual originating actor and actual native source/variant. Damage uses the credited source hero; healing uses beneficiary or source hero according to perspective. |
| `sourceOwnerState`                | Required `"known"`, `"unowned"` or `"unknown"`, captured at credit time. Damage is always known.                                                                                                                |
| `sourceOwnerId`                   | Id iff sourceOwnerState is known; damage equals ownerId. Never infer it from current actor ownership.                                                                                                           |
| `recipientActorId`                | Required Id for healing: actual healed/shielded actor. Absent for damage; damage does not require a per-enemy row expansion.                                                                                    |
| `recipientOwnerState`             | Required `"known"`, `"unowned"` or `"unknown"` for healing; absent for damage.                                                                                                                                  |
| `recipientOwnerId`                | Beneficiary hero Id iff recipientOwnerState is known; absent otherwise.                                                                                                                                         |
| `nativeProc`                      | Required Boolean preserving the native proc classification.                                                                                                                                                     |
| `periodicity`                     | `"periodic"`, `"non_periodic"` or `"unknown"`.                                                                                                                                                                  |
| `reflection`                      | `"reflected"`, `"not_reflected"` or `"unknown"`; independent of periodicity.                                                                                                                                    |
| `schoolState`                     | `"known"`, `"unknown"` or `"not_applicable"`.                                                                                                                                                                   |
| `schoolMask`                      | Integer `1..127` iff schoolState is known: physical=1, holy=2, fire=4, nature=8, frost=16, shadow=32, arcane=64; combine known schools by bitwise union.                                                        |
| `creditKind`                      | `"health_damage"` for damage; `"health_restored"` or `"absorb_consumed"` for healing.                                                                                                                           |
| `originSourceKeys`                | Required Array<Id>, empty if there is no recorded triggering item/talent/source. Bytewise sorted, unique.                                                                                                       |
| `tieOrder`                        | Required Integer, stable native first-credit order.                                                                                                                                                             |
| `share`                           | Number `0..1`: displayAmount / totals.displayAmount, or zero when total is zero.                                                                                                                                |

Keep distinct leaves for different actor/owner/source, nativeProc, periodicity,
reflection, school, creditKind or origin sets. Source metadata and actor
ownership at read time must not rewrite a previously credited contribution.
Healing also keeps different source-owner states/IDs and recipient actors/owner states/IDs
in separate leaves; ownerId follows the requested perspective. Rollup grouping
uses that accounting ownerId consistently. Every referenced recipient/source
owner resolves in the same actor map.
Keep leaves with positive periodAmount even when their checkpoint/window amount
is zero; do not create zero-activity leaves from loadout entries.

`MeterRow` contains all Stats fields, `rowId: Id`, `ownerId: Id`,
`memberIds: Array<Id>`, `tieOrder: Integer`, `rank: Integer >= 1`,
`share: Number in 0..1`, and `procClassification: "proc" | "non_proc" | "mixed"`.
Membership references contributions in the same response. Optional fields are
fixed by grouping, not inferred from names:

| groupBy        | Group identity and extra fields                                                                                        |
| -------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `detail`       | One contribution; rowId equals its rowId, memberIds contains that one ID; include all Contribution attribution fields. |
| `actor_source` | `(ownerId, actorId, sourceKey, nativeProc)`; include actorId, sourceKey and nativeProc.                                |
| `source`       | `(ownerId, sourceKey, nativeProc)`; include sourceKey and nativeProc; actorId absent.                                  |
| `owner`        | One row per ownerId; actorId, sourceKey and nativeProc absent.                                                         |

Group amounts sum their disjoint members. No other attribution fields are
invented on a rollup; inspect its member contributions for mixed components.
procClassification uses members with positive displayAmount. Non-owner groups
are proc or non_proc; owner groups can be mixed. Groups have stable IDs for
their tuple/period, even when new members appear. tieOrder is the minimum
member tieOrder. memberIds are ordered by tieOrder then bytewise rowId.
All grouped row IDs are also namespaced by runId, metric, healing perspective,
period/encounter and groupBy, not just by the grouping tuple. They remain
independent of scope filtering, sorting, language, checkpoint and recent window.

Only rows with positive displayAmount appear. Sort rows by displayAmount
descending, tieOrder ascending, then bytewise rowId ascending. Assign ranks
1 through the resulting row count. Shares always use the selected total,
never the recent-window numerator. Contributions are separately ordered by
tieOrder then rowId. Do not sum totals + rows + contributions: they represent
the same credit at different aggregation levels.

`status == "ready_empty"` iff rows is empty. It can still have positive
periodAmount and contribution history after a checkpoint cleared displayAmount.
totals.displayAmount and maxRowAmount are zero in that case. A genuinely empty
period has empty contributions, empty rows and numeric zero periodAmount.

`Rate` is a tagged table. Required `status` is exactly `"ready"`,
`"warming_up"`, `"unavailable"` or `"not_requested"`:

| Status          | Required additional fields                                                                                                                                                                                        |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ready`         | `amount: Amount`, `startRunSeconds`, `endRunSeconds`, `elapsedSeconds`, `denominatorSeconds: Number > 0`, `value: Amount`, `resolutionSeconds: Number in 0..0.2`, `approximate: Boolean`.                         |
| `warming_up`    | Same fields as ready except value is absent; elapsedSeconds is less than 1.                                                                                                                                       |
| `unavailable`   | startRunSeconds, endRunSeconds, elapsedSeconds and `reason`: `"history_gap"`, `"history_not_retained"` or `"authority_changed"`; amount, denominatorSeconds, value, resolutionSeconds and approximate are absent. |
| `not_requested` | No other fields.                                                                                                                                                                                                  |

All Rate time fields are Seconds. Section 3.12 fixes their arithmetic.
Unavailable is never represented as numeric zero or a silently shorter window.

### 3.8. Exact metadata descriptors

`SourceDescriptor` required fields:

| Field               | Type/value                                                                                                                                           |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sourceKey`         | Id, equal to its dictionary key. Stable native definition plus contributing rank/art/effect variant for this run.                                    |
| `kind`              | `"ability"`, `"effect"`, `"talent"`, `"item"`, `"basic_attack"`, `"system"` or `"generic"`. Pets and DoTs are not mutually exclusive source kinds.   |
| `attribution`       | `"known"`, `"unknown"` or `"mixed"`. A legitimate generic category can be known; missing original attribution is never concealed by a generic label. |
| `name`              | Exact native Text.                                                                                                                                   |
| `nameLanguageCode`  | Text: actual catalog code used for the label, or `"und"` for a language-independent/literal name. English fallback is `"en"`.                        |
| `icon`              | `Icon` below: canonical artwork for this recorded source variant and intended meter row.                                                             |
| `spellIds`          | Array of actual positive Integer spell IDs; empty for non-spell sources. No invented ID for custom effects.                                          |
| `originSourceKeys`  | Array<Id> of definition-level origin relationships, empty when none. Actual contribution origins are recorded on the contribution.                   |
| `relatedSourceKeys` | Array<Id> for native associated abilities/effects/items/talents, empty when none.                                                                    |

The only optional source fields in v1 are `localizationKey: Text`,
`abilityKey: Id`, `talentKey: Id`, `itemKey: Id`, `itemId: Integer > 0`,
`itemInstanceKey: Id`, `variantKey: Id` and `rank: Integer`. Supply them only where native definitions
have that value. A changed contributing rank/variant/art identity gets a new
sourceKey; old descriptors remain available for old rows. Language changes
change labels/revisions, not source keys. The source's icon must not become the
player's newly equipped item icon for an unrelated old contribution.
If native accounting distinguishes two copies of one item, sourceKey must also
distinguish those contributing instances and itemInstanceKey is required; use
the same itemInstanceKey namespace as the loadout. Do not force a split where
the native accounting intentionally treats copies as one definition.

`Icon` has required `status: "ready" | "pending" | "missing"`:

- ready: required `path: Text`, a native texture path usable by Texture:SetTexture.
- pending: required `retryAfterSeconds: Number > 0`; path absent.
- missing: required `reason: "not_applicable" | "not_available"`; path absent.

No other Icon fields are defined. Pending-to-ready changes metadataRevision.
Unknown artwork is explicit; do not return a question-mark path as a successful
authoritative icon. The addon decides its neutral fallback.

`ActorDescriptor` required fields are `actorId: Id` (matching its map key),
`kind: "hero" | "pet" | "summon" | "totem" | "enemy" | "system" | "unknown"`,
`name: Text`, `nameLanguageCode: Text`, `state: "present" | "departed" | "despawned"`,
and `portrait: Portrait`. Hero proper names are preserved without translation.
nameLanguageCode follows the source rule above, with `"und"` for hero proper
names; und is not a selectable game catalog. context.languageCode always remains
the actual selected catalog code. A nameLanguageCode must be in languageCodes
or be und. Hero classKey is required and exactly one of
`"warrior"`, `"paladin"`, `"hunter"`, `"rogue"`, `"priest"`, `"shaman"`,
`"mage"`, `"warlock"`, `"druid"`; it is absent for other actor kinds. Adding a
new hero class requires a specified compatible extension. Allowed additional optional fields are
`parentActorId: Id`, `currentOwnerId: Id`, `creatureEntry: Integer > 0`,
`petFamilyKey: Id`, `summonKey: Id` and `totemKey: Id`.
Actor IDs distinguish incarnations and are not reused in the run. currentOwnerId
describes current native ownership; the row's ownerId preserves historical credit.

`Portrait` has required `portraitKey: Id` and
`status: "ready" | "pending" | "missing"`:

- ready: the key identifies an immutable retained native image descriptor.
- pending: required `retryAfterSeconds: Number > 0`; the issued key can become ready.
- missing: required `reason: "not_applicable" | "not_available"`; the issued key explicitly has no usable image.

Use section 3.11 to bind it; no live unit token or name matching is necessary.
Portrait keys remain valid for the retained run, including UI reload and departed
or despawned actors. A changed appearance gets a new key; old ready images remain
bindable until the run is retired. Pending keys follow their preparation status;
permanently missing keys return ART_UNAVAILABLE. Neither descriptors nor getters allocate Lua
frames/models or automatically change an addon's texture.

Every referenced parent, owner, origin and related descriptor must be in the
same result. Arrays of source keys are unique and bytewise sorted. Descriptor
graphs may contain cycles; consumers use keys rather than recursive expansion.
Current loadout and recorded contribution descriptors use the same namespace.
Descriptor closure applies to MeterSnapshot and MeterLoadout. Context alone
contains identity references without a descriptor map.

### 3.9. `AZS_GetMeterLoadout(query)`

`LoadoutQuery`, in validation order:

| Field        | Type    | Required/default                                                    |
| ------------ | ------- | ------------------------------------------------------------------- |
| `apiVersion` | Integer | Required, must be `1`.                                              |
| `runId`      | Id      | Required, expected retained current run.                            |
| `ownerId`    | Id      | Optional; omitted means context.localOwnerId. Must identify a hero. |

Returns the current native loadout for that present hero, independently of
whether its items/abilities/talents have contributed to the meter. A departed
hero remains queryable in historical meter snapshots, but its current loadout
returns OWNER_NOT_PRESENT. A remote present hero whose loadout has not arrived
returns NOT_READY. All active party heroes must have native loadout support
for complete v1 conformance; do not infer it from their damage rows.

`MeterLoadout` required fields: `apiVersion = 1`, `complete = true`,
`context: Context`, resolved `ownerId: Id`, `loadoutRevision: Id`,
`sources: Map<SourceDescriptor>`, `actors: Map<ActorDescriptor>`, and the four
dense arrays below. No array is a damage counter. This is one atomic loadout
capture; a separately requested meter snapshot has its own context/revision.

| Array        | Exact entry fields                                                                                                                                                                                                                                                                                 |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `equipment`  | `slotId: Integer 0..19`, `supported: Boolean`, `occupied: Boolean`, `effectSourceKeys: Array<Id>`; if occupied, required `itemInstanceKey: Id`, `sourceKey: Id` and optional `itemLink: Text`. Empty/unsupported slots omit itemInstanceKey/sourceKey/itemLink and have an empty effectSourceKeys. |
| `abilities`  | Required `sourceKey: Id`, `learned: Boolean`, `selected: Boolean`, `passive: Boolean`, `effectSourceKeys: Array<Id>`; optional `rank: Integer`, `slotId: Integer >= 1`. At least learned or selected is true.                                                                                      |
| `talents`    | Required `sourceKey: Id`, `rank: Integer >= 1`, `effectSourceKeys: Array<Id>`, `modifiedSourceKeys: Array<Id>`; optional `treeKey: Id`, `specKey: Id`. Only actually learned talents appear.                                                                                                       |
| `runJewelry` | Required `itemInstanceKey: Id`, `sourceKey: Id`, `category: "ring"                                                                                                                                                                                                                                 | "amulet" | "trinket" | "other"`, `effectSourceKeys: Array<Id>`; optional `slotId: Integer >= 1`. |

equipment has exactly 20 entries ordered by slotId, with array index slotId+1.
Slot IDs are: 0 ammo, 1 head, 2 neck, 3 shoulder, 4 shirt, 5 chest, 6 waist,
7 legs, 8 feet, 9 wrist, 10 hands, 11 finger1, 12 finger2, 13 trinket1,
14 trinket2, 15 back, 16 mainhand, 17 offhand, 18 ranged, 19 tabard.
Unsupported slots have supported=false and occupied=false. Supported empty
slots have supported=true and occupied=false. Do not invent equipped items.

Other arrays use native slot order when present, then bytewise sourceKey;
unslotted entries follow slotted entries. Talents sort by treeKey (absent sorts
last), then sourceKey. Run jewelry uses itemInstanceKey as the final tie-break.
Identical jewelry definitions can have distinct native
itemInstanceKeys. Standard inventory and run jewelry remain separate lists.
Every listed/reference key resolves in the result's descriptor maps, including
origin effects, the requested owner, transitive parent/owner descriptors and
boss IDs referenced by context.encounter. Historical metadata from a meter
snapshot must never be replaced with this current loadout's different variant.

### 3.10. Exact checkpoint creation and release

```lua
checkpoint, err = AZS_CreateMeterCheckpoint(runId)
released, err = AZS_ReleaseMeterCheckpoint(checkpointId)
```

Create requires the expected current runId and a coherent authoritative
accounting state. It captures all damage/healing/party/encounter scopes in one
operation, even if an addon is displaying only one. Success is `Checkpoint`:

| Field                                                 | Type/value                                       |
| ----------------------------------------------------- | ------------------------------------------------ |
| `checkpointId`                                        | Issued Id used in snapshot requests.             |
| `runId`, `uiSessionId`, `authorityId`, `counterEpoch` | Captured Id values.                              |
| `atRunSeconds`                                        | Authoritative Seconds at the successful capture. |
| `fenceId`                                             | Opaque Id for the native admission-order fence.  |

The fence, not only a timestamp, distinguishes credits admitted before and
after X at the same run second. Contributions admitted at or before the fence
are excluded from since-checkpoint amounts; later credits are included, even
if their run timestamp is equal. A newly appearing source/actor/hero has a zero
baseline; its first read must not discard its post-checkpoint contributions.

Create returns NOT_READY without allocating a token if complete authority is
not available. Capture occurs at the successful native call, not a later meter
poll. A caller that receives an error must not pretend it captured a baseline.
Counters, language selection and all other consumers remain untouched.

Tokens have no time-based expiry during their valid UI/run/authority/epoch.
Language, loadout, tab, hide/show and pause changes preserve them. UI reload or
world exit expires them and releases their quota. A new run, counter correction
or authority change invalidates them with the exact reason above and releases
quota; the game must never silently rebase an old token. A full UI reload does
not reset the native run, but starts a new checkpoint session.

Validate a queried token in this exact order after common request/run selection:
issued-token authenticity, UI-session/world lifetime, token run, authority,
counter epoch, then active/released state. Failed authenticity is INVALID_CHECKPOINT;
ended UI/world lifetime is CHECKPOINT_EXPIRED; the next three mismatches are
CHECKPOINT_INVALIDATED with run_changed, authority_changed or counter_epoch_changed
respectively; an otherwise matching released token is CHECKPOINT_EXPIRED.
This order resolves overlapping changes without retaining old token-state lists.
The earlier common RUN_MISMATCH still wins if query.runId itself is stale.

Token issuance must be recognizable using bounded authenticated token data or
an equivalent bounded native mechanism. Keep at most the 64 active resources;
do not accumulate a tombstone for every token ever released or every UI reload.
A token from another game process is not issued by this process and is invalid.

At most 64 active tokens exist per UI session. At the limit, return RESOURCE_LIMIT
without evicting any token. Consumers must release tokens when replacing X,
disabling their session or cleaning up. Release of a validly issued token
returns true even if already released, expired or invalidated; it is idempotent
and requires no world/run. An unissued/forged token returns INVALID_CHECKPOINT.
Querying a released token in an otherwise matching lifetime returns
CHECKPOINT_EXPIRED, never a new baseline. If a snapshot publication precedes a
valid checkpoint's native fence/time, return NOT_READY until a capture at or
after that fence is available; do not produce negative time or older counters.

### 3.11. `AZS_SetMeterPortrait(texture, runId, portraitKey)`

texture must be an actual native Texture object, not its global name, a frame,
FontString or a table that merely has similarly named methods. runId is the
expected current retained run. portraitKey is an issued key from a returned
ActorDescriptor. Only the caller-supplied texture is modified on success.

Return true after binding the retained native 2D portrait image. Preserve the
texture's parent, anchors, dimensions, layer, alpha, tint and input ownership;
also preserve its UV coordinates and blend mode.
Preserve any native circular-portrait mask already established through
SetPortraitToTexture. The same setter must support ordinary UV-clipped Texture
regions, allowing the existing circular-strip compatibility renderer to bind
the retained image without changing its crops or allocating a new model/frame.
the addon still controls masking/rims. No frame/model is created. On any error,
the original image and all texture properties remain unchanged. Rebinding the
same key to an already matching texture is successful without repeated native
image work. A failed/foreign key never falls back to another actor or live unit.

In addition to common errors, use UNKNOWN_PORTRAIT for an unissued key,
ART_NOT_READY for a known pending image and ART_UNAVAILABLE when native artwork
is permanently unavailable. Language changes alone do not invalidate a portrait.

### 3.12. Exact periods, averages and recent windows

Let A be context.asOfRunSeconds, S the selected period start, E its end, C the
checkpoint's atRunSeconds when supplied, and W query.windowSeconds. Every
numerator is taken from this snapshot's disjoint contributions and admission
fence; no addon UI/wall clock or SCT data enters a rate.

- periodAmount counts all selected native credits in that run/encounter.
- sinceCheckpointAmount counts only those credits admitted after the checkpoint
  fence. This naturally gives zero for an encounter entirely before X, excludes
  the earlier part of a fight reset mid-encounter, and includes a fight begun
  after X without another baseline.
- periodAverage uses start=S, end=E, elapsed=E-S, denominator=max(elapsed,1),
  value=periodAmount/denominator. It is ready, including zero elapsed time.
- checkpointAverage uses start=C, end=A, elapsed=A-C,
  denominator=max(elapsed,1), value=sinceCheckpointAmount/denominator for every
  view. For a completed encounter its numerator freezes while run time since X
  can continue; do not substitute encounter elapsed time.
- For W>0, recent start R=max(S,A-W,C if supplied), end=A, elapsed=A-R. Count
  only selected-period credits within that time interval and, when requested,
  after the checkpoint fence. Credits at R are included; credits after A or the
  snapshot capture fence are excluded. A completed encounter can decay to zero
  as its credits leave the recent window. The window is not clipped to its end.
- A recent rate with elapsed<1 has warming_up status, known windowAmount and
  denominator=max(elapsed,1), but no value. Otherwise value=windowAmount/elapsed
  and denominator=elapsed. Valid zero activity after warmup is numeric zero.
- For W=0, recentRate is only `{ status = "not_requested" }` and windowAmount is
  absent. displayRate selects checkpointAverage if present, else periodAverage.

For exact native boundaries, resolutionSeconds=0 and approximate=false. If the
implementation retains cumulative time samples instead, capabilities advertises
their maximum spacing H in `(0,0.2]`. Evaluate an interior boundary by linear
interpolation of its surrounding cumulative samples, using the value just before
credits at an inclusive start boundary and all admitted credits at end A. Both
the returned resolutionSeconds=H and approximate=true are mandatory whenever
a boundary needs interpolation. Recent group/header amounts must sum the same
leaf estimates. Full-period and checkpoint amounts remain native exact counters;
they are never approximated from the recent history.

More precisely, subtract the cumulative amount strictly before R, not the
cumulative amount through R. At a stored time knot, the native history must
retain its left-limit and through-knot aggregates so a credit exactly at R is
included. At R=C use the exact checkpoint fence baseline instead, excluding
before-X credits even when they share C's timestamp. For an interior sampled
boundary, interpolate between the earlier knot's through value and the later
knot's left-limit value, marking the result approximate as above.

History for a newly appearing leaf is known zero before its first admitted
credit, rather than unavailable merely because it was not yet in a sample.
Clamp an approximate leaf windowAmount to [0, displayAmount] and derive every
group/header window amount by summing those leaf estimates.

At a checkpoint boundary, store the exact native baseline/fence and never
interpolate through pre-X amounts. Native recent samples are collected by the
game independently of whether any addon is enabled, visible or initialized.
Run-start warmup or a recent checkpoint legitimately shortens the requested
window. A missing chunk, unavailable retained history or authority discontinuity
does not: return recentRate.status=unavailable with the matching reason, omit
windowAmount and displayRate.value, and retain valid totals/metadata. Use that
status consistently for the selected scope's header, contributions and rows;
do not silently display incomplete per-source rates as a complete total.

No recent-history failure invalidates an otherwise ready full-period snapshot.
No checkpoint failure falls back to pre-reset totals. A corrected counter epoch
must invalidate its old checkpoints and old recent history explicitly.

### 3.13. Exact calls for the four current tabs

These requests use context returned by a successful GetMeterContext call.
The checkpointId field is omitted before X; after X use checkpoint.checkpointId.
Use windowSeconds=0 for Healing Done, Boss Damage and Party Damage to preserve
their current average-rate behavior.

```lua
if type(AZS_GetMeterCapabilities) ~= "function" then
    -- This client has no version 1 API; use the documented legacy path.
    return
end
local capabilities, err = AZS_GetMeterCapabilities()
if not capabilities or capabilities.apiVersion ~= 1 then return end

local context, err = AZS_GetMeterContext()
if not context then
    -- Handle err.code; do not reuse another run's rows.
    return
end

local damage, err = AZS_GetMeterSnapshot({
    apiVersion = 1, runId = context.runId,
    metric = "damage", scope = "self", period = "run",
    groupBy = "source", windowSeconds = 10,
})

local healing, err = AZS_GetMeterSnapshot({
    apiVersion = 1, runId = context.runId,
    metric = "healing", scope = "self", period = "run",
    groupBy = "source", windowSeconds = 0,
})

local boss, err = AZS_GetMeterSnapshot({
    apiVersion = 1, runId = context.runId,
    metric = "damage", scope = "self", period = "encounter",
    groupBy = "source", windowSeconds = 0,
})

local party, err = AZS_GetMeterSnapshot({
    apiVersion = 1, runId = context.runId,
    metric = "damage", scope = "party", period = "run",
    groupBy = "owner", windowSeconds = 0,
})
```

Each call's error must be checked separately in production. No successful
tab result implies another tab is ready, and four sequential calls are not a
single cross-view capture. The checkpoint operation is the atomic reset fence.

For a party hero's real ability/pet breakdown, request scope=owner with its
ownerId and groupBy=actor_source or detail. For party healing use metric=healing
and scope=party; no guessed spell ownership is required.

For performed healing rather than the legacy received view, the exact request is:

```lua
local performed, err = AZS_GetMeterSnapshot({
    apiVersion = 1, runId = context.runId,
    metric = "healing", healingPerspective = "performed",
    scope = "self", period = "run", groupBy = "source", windowSeconds = 0,
})
```

```lua
local checkpoint, err = AZS_CreateMeterCheckpoint(context.runId)
if not checkpoint then return end

local afterReset, err = AZS_GetMeterSnapshot({
    apiVersion = 1, runId = context.runId,
    metric = "damage", scope = "self", period = "run",
    groupBy = "source", windowSeconds = 10,
    checkpointId = checkpoint.checkpointId,
})
-- Keep checkpoint for this local session; do not save it to disk.

local loadout, err = AZS_GetMeterLoadout({
    apiVersion = 1, runId = context.runId,
})

local position, err = AZS_GetPlayerPosition()
if position then
    -- Use position.x/y only within position.spaceId/mapId.
else
    -- Hide/defer the affected projection according to err.code.
end

-- When replacing/ending this statistics session:
local released, err = AZS_ReleaseMeterCheckpoint(checkpoint.checkpointId)
```

Portrait binding uses the retained image, even when the hero has departed.
Here texture is an existing addon-owned native Texture object:

```lua
if party and party.rows[1] then
    local row = party.rows[1]
    local portrait = party.actors[row.ownerId].portrait
    if portrait.status == "ready" then
        local bound, bindErr = AZS_SetMeterPortrait(
            texture, party.context.runId, portrait.portraitKey
        )
        if not bound then
            -- Keep the existing image; handle bindErr.code.
        end
    end
end
```

Apply errors to the affected view/session explicitly:

- INVALID_ARGUMENT, UNSUPPORTED_VERSION and UNSUPPORTED_QUERY require a caller
  fix or a supported fallback; repeating the same call does not help.
- RUN_MISMATCH means discard old-run rows and fetch context again. Do not simply
  replace the request's runId while retaining its old checkpoint.
- CHECKPOINT_EXPIRED/INVALIDATED means stop using that token, release it
  idempotently and request a new reset point only as the chosen session policy.
  Do not display whole-run totals as though they were post-X totals.
- NO_PARTY and NO_ENCOUNTER are known scope absence, not ready-empty counters.
  Keep those views unavailable until their native context changes.
- For retryable errors, defer through the existing consumer controller for at
  least retryAfterSeconds. Do not busy-loop, invent rows or keep another run's
  stale values. Use descriptor/rate statuses for artwork/history limitations.

### 3.14. Required conformance cases

In addition to section 2's full source/language scenarios, the implementation
must cover these exact boundary cases:

- Malformed fields, unknown keys, numeric strings, NaN/infinity, extra arguments
  and unsupported versions return the specified errors without native writes.
- Valid empty, post-X empty, no party, no encounter, unreceived data and missing
  art produce their different specified results; none is an invented zero feed.
- A before-X and after-X credit at the same run timestamp are separated by the
  native fence. New actors/sources/party heroes do not lose their first delta.
- A credit exactly at a recent window's start is included; subtracting a
  through-knot value must not lose it. A late actor has known zero history
  before its first credit, and clock regression changes the counter epoch.
- Shares, order, maxima and every rate reconcile across detail/source/owner
  grouping without counting leaf rows and summaries twice.
- When hero A heals hero B, A/received excludes it, A/performed includes it,
  and B/received includes it. Either party perspective counts it once when
  both heroes are in scope; received and performed totals are never added.
  A performed heal to an unowned actor remains representable without a fake
  recipient hero ID, and unknown potentially matching ownership blocks readiness.
- A 10-second query near run start, just after X, after a history gap and after
  a completed encounter follows the exact window/warmup/unavailable rules.
- Token limit, replacement, double release, released-token query, reload,
  authority change and correction epochs have the fixed cleanup/error behavior.
- Detached returned tables cannot change game state or another result. Failed
  portrait binding preserves the old image and all target texture properties.
- Frame samples remain live inside instances, use the same map coordinate
  space as navigation destinations, and do not jump because a world-map sheet
  or periodic run packet changed. Space changes never blend old coordinates.
