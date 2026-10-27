# Shared source icons

SCT and the meter use one resolver in `modules/nameplates/sct.lua`. Floating
combat text calls `CombatIcon`; the meter's `sct.GetSourceIcon` entry point adds
its exact healing-category/Melee context and calls that same resolver. The
meter owns circular drawing and gold rims, with no second item/spell scanner.

The reported **The Eye of Hakkar** was missing because its damage is named after
an item. The spell/talent/database lookup had no item-name tier, and the meter
hid the rim whenever that resolver returned no icon. The installed native
record supplies `INV_Jewelry_Necklace_22`; no icon is inferred from “Eye.”

## Public-source audit — 2026-10-27

The request contains eight unique repositories; AZSSpellMeter appears twice.
All eight were read at the commits below, with complete, non-truncated trees.
Their meter scope varies. The useful shared idea is exact native inventory/item
metadata plus cached lookups; no public-addon implementation was copied.

| Repository and inspected source                                                                                                                    | Meter and icon approach                                                                                                                                                                                                                                                              |
| -------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [AzerothSurvivorUI](https://github.com/NicholasIzosimov/AzerothSurvivorUI/blob/47234462ce522ef50ce3f763e1362d7b547d0146/SurvivorUI/Meter.lua#L580) | Damage/healing/taken meter; spellbook/action/talent icons and worn-item textures. Misses retry. Its item prefix heuristics are not adopted.                                                                                                                                          |
| [PhantomUI](https://github.com/Phantom2796/PhantomUI/blob/0b3c0d990e1349044ae165e49affe6e805fc81c3/PhantomUI/meter/Meter.lua#L829)                 | Embedded meter; generated localized icons, learned spell/talent/inventory metadata and summon icons. Prefix/rank guesses and proc remapping are not adopted.                                                                                                                         |
| [nfUI](https://github.com/nfmous/nfui_AZSRV/blob/061a696c1ed62aa4263df49d4baa9643b4364f5b/nfUI/HUD/DPSMeter.lua)                                   | Native damage/DPS panel with text and bars; no per-source icon resolver to reuse.                                                                                                                                                                                                    |
| [AZSSpellMeter](https://github.com/kex0/AZSSpellMeter/blob/efabc6cd4e85ac9d0b6dd5ba62a37b5cc8dd6f64/AZSSpellMeter.lua#L1004)                       | Dedicated damage/healing/boss/taken meter; generated spell data, item fallbacks, `GetItemInfo`, inventory/bag scans and saved learned icons. Only the native lookup/cache idea is used; no saved learned registry, bag/chat scans, proc reassignment or DPS calculation is imported. |
| [BordoUI](https://github.com/threenox/BordoUI/blob/7770f9f84ae3a043e4102e9b2969f4dc684879d9/StatsTable.lua#L355)                                   | Attack/DPS statistics use spellbook caches and a fixed icon map. Its Hakkar map uses `INV_Misc_Eye_01`, unlike the installed native record, so it is not used as authority.                                                                                                          |
| [BlackwellUI](https://github.com/Blackwellcode/BlackwellUI/blob/3f9f7461b81f39162ebdd8dc12561cd99a24629f/Core.lua#L933)                            | Damage/healing/boss meter delegates to shared ability lookup, with equipped-weapon textures, item metadata and generated spell tables.                                                                                                                                               |
| [survivor-ui](https://github.com/morderous/survivor-ui/blob/685124dad0217fd200cd7bfe5a86cdd26d9fb72e/SurvivorUI/Meter.lua#L655)                    | Damage/healing/boss/party views share action, spellbook, talent and equipped-item lookup with cached misses. Prefix matching, inferred spell keys and borrowed proc icons are not adopted.                                                                                           |
| [KeijinUI](https://github.com/KeijinDE/KeijinUI_modern-as-ui/blob/493c2f41122fa42c47d996346faabfbbe890a1bd/KeijinUI/Core.lua#L146)                 | Meter/statistics use one spellbook/item/generated-data resolver. Item successes last for the session; unknown names can request a throttled gear scan.                                                                                                                               |

The public sources disagree on some fixed art. For example, Hakkar is a
necklace in AZSSpellMeter/PhantomUI/BlackwellUI and an eye in BordoUI. The
installed client data resolves that difference. The official
[Codex](https://azerothsurvivors.app/codex/) is an additional visual
reference, not the source of runtime texture guesses.

## Native metadata

`modules/nameplates/source_icons.lua` supplies the shared unknown icon and exact
localized general-item name/path tables. Its input is the installed EXE with
SHA-256 `80ac3217660a02020b3e09f1ce93bfaa6ba89abd9a9d62405b9f70114fd6d46c`.
This is a new independently inspected input; older spell/healing/loot catalog
fingerprints retain their own provenance and are not silently relabeled.

The native ring/trinket array has **23** records, 72 bytes each, beginning at
file offset `0x72be930` (VA `0x1472bfb30`). The shared-amulet array has **16**
records, 80 bytes each, beginning at `0x72bfb90` (VA `0x1472c0d90`). Each begins
with three pointer/length slices at offsets 0, 16 and 32: native key, English
name and icon basename. Only these display fields are extracted.

Hakkar's shared-amulet record is at file offset `0x72bfe10` / VA `0x1472c1010`:
`eye_of_hakkar`, `The Eye of Hakkar`, `INV_Jewelry_Necklace_22`. The native
`amulet.eye_of_hakkar` caption and the complete table's `jewel.*` / `amulet.*`
captions supply the fourteen languages. English exact names are retained beside
each active-language set. Conflicting names within a catalog become `false`.

`scripts/generate_source_item_icons.py` uses the existing PE/catalog reader from
loot preparation with an explicit, hash-bound input. Its original default hash
and existing loot generation behavior remain unchanged. It reads records and
embedded JSON as data, without running native instructions or addon Lua. No
runtime executable/database access, item IDs, numeric gameplay fields or bitmap
payload is introduced.

```sh
python3 scripts/generate_source_item_icons.py \
  --client /path/to/AzerothSurvivors.exe \
  --output modules/nameplates/source_icons.lua \
  --metadata /tmp/source-item-icons.json
```

## Lookup, retries and cleanup

The existing spellbook and observed-aura priority stays intact. Exact generated
general-item metadata follows the native ability/talent/effect tier, before the
weaker learned-talent/database tiers. Only an otherwise unresolved source tries
`GetItemInfo` and native equipped-item links/textures. An item-info result must
return the exact requested name; inventory names come from full native links.
No substring/prefix match, class guess, rank stripping or proc-to-spell remapping
is added. Existing school refinement remains limited to its original DBC tier.

The live item path accepts native icon paths/basenames, rejects placeholders
and distinguishes item-info's ninth/tenth return forms from equipment-slot
strings. Successes use the existing `LearnSpellTexture` ambiguity helper,
including path/extension normalization. Misses retry at most once per second
per source; equipment scans share one one-second limit across both consumers.
Successful item metadata can outlive unequipping during the same world session.
World/logout and effective-language changes clear the shared live item cache.

Unknown or ambiguous sources use the shared question mark. Meter rows draw it
inside their existing gold rings; disabled icons still hide the complete icon
and rim. Both renderers cache successful bindings, retain their native-circle /
strip fallback behavior, and add no regions or artwork for item resolution.

There is no new updater, event subscription, saved learned-icon registry,
combat history, bag scan or chat interception. A hidden/off meter never calls
the resolver. SCT can independently use the same unsaved display metadata
through its existing combat flow; that is not off-period meter collection.
The 39-record static tier covers general jewelry/amulets, not every generated
class-amulet name or future effect. Other exact native metadata can fill those
gaps; genuinely unavailable sources keep the neutral fallback and remain
retryable.

## Verification boundary

Public/native source inspection, data preparation, manual diffs and pinned
StyLua/Prettier formatting only. No tests, standalone validation, addon/game
execution or FPS measurements were run. Native binding, live item-info cache
availability and final appearance remain unverified in-game. Blizzard retains
ownership of the referenced native artwork; no public addon code or icon bitmap
was imported.
