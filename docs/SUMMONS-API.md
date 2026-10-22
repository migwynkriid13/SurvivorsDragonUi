# Summon API assessment

The owner supplied an updated Azeroth Survivors addon reference on 2026-10-22.
The [complete text](AzerothSurvivors-Addon-API-2026-10-22.txt) is preserved
verbatim. Its date records receipt, not a verified client release version.
The earlier Markdown and 2026-10-15 reference copies remain unchanged.

This gives SurvivorsDragonUi the data needed for a summon tracker across every
class and spec. The supplied contract states no removal of an API we currently
use. This update adds documentation only; it does not display summons or change
the existing pet frame, combat text, settings or runtime package.

## What the new API provides

- `AZS_GetSummons([which])` returns each active summon in arrival order, with
  its run-local summon `id`, creature `entry`, stable `key` and `kind`, localized
  `name`, native `icon`, and permanence or lifetime information. A temporary
  summon has `duration` and run-clock-based `remaining`; a permanent summon has
  `permanent == true` and nil timing. Missing timing alone is not proof of
  permanence.
- `AZS_GetSummonCount([which])` returns the number currently out. Both filtered
  helpers accept a stable key or kind, rather than a translated display name.
  These identifiers are distinct: Pit Lord uses key `pit_lord` and kind
  `pitlord`.
- `AZS_GetSummonGroups()` returns groups by creature in first-arrival order,
  plus a total count. Each group supplies its key, kind, localized name, icon,
  total `count`, permanent and temporary counts, and the earliest temporary
  expiry as `remaining`. That one countdown does not describe every member;
  use the individual list for each summon's lifetime.
- `AZS_PETS` contains the raw rows
  `{ id, entry, key, kind, ends, dur, icon, name }`. `ends` is an absolute run
  second; `dur` is duration. Both are `-1` for permanent summons. Prefer the
  getters for normalized permanence and remaining time.
- `AZSPETS` announces list changes when a summon comes or goes. The reference's
  matching-update-global convention also covers `AZS_PETS_UPDATED`. Expiry
  display should read native `remaining`, rather than expect a fresh list
  packet every second.

Coverage includes Hunter beasts, Druid Treants, Shaman Spirit Wolves, Mage Water
Elementals and Warlock demons, including Legion Gate's lesser demons, Felguard,
Pit Lord, Infernal and Doomguard. The cosmetic Rewards-page companion is
explicitly excluded.

## What we can add

A compact tracker can show the game's own icon and translated name, how many
are active, and when the next temporary member expires. An expanded view could
show each temporary member's own remaining time. Permanent members can retain
their count without an invented expiry. Native icon paths avoid bundled summon
artwork, guessed spell icons or a separate creature catalog.

The supplied reference ties remaining time to `AZS_GetRunTime()`. That preserves
the game's pause and card-choice timing without estimating duration from casts,
talents, class or receipt time. Stable keys support logic across languages while
the supplied names remain suitable for display.

These are possible follow-up features, not behavior implemented by importing
the reference. A future view should use the existing layout and lifecycle
helpers, feature-detect its required getters and stay unavailable on older
builds without affecting the current HUD. Read phase before retained tables,
require a received current summon snapshot, defer event-triggered reads until
native parsing completes, and clear session rows on run/world cleanup. Native
lists must remain read-only, with no saved summon state or independent gameplay
clock. The new reference documents no `pets` or `summons` HUD takeover part.

## Effect on the existing pet frame

[The current pet frame](../modules/unit/mini.lua) styles the native `PetFrame`
and reads the single `pet` unit's health and power. No runtime module currently
uses the new summon getters, table or update prefix.

The summon roster can describe multiple simultaneous creatures that a single
unit token cannot enumerate. It supplies no health, maximum health, power,
target, position or unit token for those creatures. Its IDs are documented as
unique among the player's summons in a run, not as enemy spawn IDs or native
unit GUIDs. There is no documented conversion to `AZS_UNITS`, `AZS_TARGET` or a
unit token.

An additional summon tracker would preserve the native pet frame's information.
Replacing that frame with roster data alone would lose its available health
and power display; the roster cannot reconstruct those values. Importing these
docs does not perform that replacement.

## Effect on Pet damage and SCT icons

[The combat parser](../modules/nameplates/parser.lua) identifies pet hits from
native PET events, or accepts shared periodic/reflected messages with an
explicit source matching `UnitName("pet")`. [The SCT renderer](../modules/nameplates/sct.lua)
uses that identity for the Pet damage filter, duplicate grouping and live
preview. The new roster does not automatically expand that source recognition.

The previously supplied capture showed an Imp Fireball as
`CHAT_MSG_SPELL_SELF_DAMAGE` with `Your Fireball...` wording and no pet source.
Knowing an Imp is active does not prove that it caused a particular Fireball.
The new API supplies no per-hit summon ID, damage amount, spell ID, critical
flag or target, so it cannot reliably classify that event or calculate damage
per summon. Such unattributed SELF damage remains visible when Pet damage is
off. Existing matching, filtering and native meter totals remain unchanged.

An active roster could support investigation of additional explicitly named
combat sources, but name matching still needs evidence of the emitted wording
and collision behavior. The list alone does not authorize ownership guesses or
change the parser's current acceptance rules.

Likewise, a summon icon describes the creature. It does not establish the icon
for that creature's attack or the spell that created it. The existing
[exact-name SCT icon resolver](SCT-ICONS.md) keeps its source priorities and
ambiguity rules; this API adds no verified attack-icon mapping.

## What changes or is lost now

Nothing in the supplied contract requires migration of our existing features.
No API removal or changed signature used by the addon is stated. This is a
documentation-level compatibility assessment, not verification of a new client
binary. Existing pet health/power, combat text and settings continue through
their current paths because this update changes no runtime files.

The new data does not control summons, command attacks, extend lifetimes,
identify individual damage events or include the cosmetic companion. It also
does not change the existing limits around retained out-of-run tables, native
snapshot replay or missing unit GUIDs. A roster count cannot fill those gaps.

The complete reference also consolidates other APIs absent from the original
Markdown copy, including debuffs, healing and boss meters, lairs, run summaries,
stored level-ups, banner callbacks and class-proc fields. Several already have
dedicated integration notes; their presence here is not evidence that they
were all introduced with summons.

No local tests, syntax checks, formatting tools, addon execution or game startup
were run for this update. GitHub Actions provides the authorized static checks.
Summon publication, pause behavior, reload replay and rendering in the packaged
game remain unverified.
