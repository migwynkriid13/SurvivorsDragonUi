# Shared SCT icon metadata

Custom SCT resolves icons through one exact-name path for every class. Native combat messages already identify effects such as `Deadly Poison`, but passive damage can be absent from the player's spellbook and active `AZSSPELLS` list. Encounter debuff snapshots cover bosses and guardians; ordinary enemies can die without their auras ever being observed through a target or mouseover token. The game's custom talent screen also uses its own catalog, separate from standard `GetTalentInfo`.

## Lookup order

1. A valid native player spellbook texture.
2. An actually observed native aura texture, from a received phase-gated official `AZS_DEBUFFS` snapshot or a current target/mouseover debuff.
3. The generated complete native ability and custom talent catalogs, plus the reviewed fixed native damage effects.
4. Exact native general-jewelry/amulet metadata in the active language, including English source captions.
5. A learned standard native talent's texture.
6. An unambiguous generated spell-database texture for the client's locale. When the name alone conflicts, refine only this tier with the combat message's parsed damage school.
7. Exact native item-info / equipped-item metadata for otherwise unresolved names, with shared cached successes and throttled retries.
8. The shared question mark when no usable mapping exists.

All keys are exact native names. There are no spell-specific or class-specific conditions in the resolver. Live spellbook and observed aura metadata retain priority over the generated catalog. Question-mark textures are rejected as successful lookups. Conflicting icons within a source tier are stored as `false`, which retains the fallback instead of borrowing an arbitrary icon from a weaker source. The database tier alone can narrow its own conflicting rows by the actual canonical damage school. A conflict that remains within that school still returns the fallback; this refinement never overrides ambiguity in a stronger native source. Actual aura and learned talent observations use separate caches, so different talent artwork cannot veto an observed debuff.

The generated file covers all 355 current custom talent records across nine classes and 27 trees, all 113 native ability records, and six reviewed fixed-effect sites. The talent table supplies 346 names (345 resolved and one ambiguous); the ability table supplies 113 resolved names; the fixed-effect table supplies five resolved names. Together they cover 454 distinct names in one native game lookup tier. A conflict in any table, or different native icons for the same exact name across tables, remains a conflict in that tier. The supplied spell database contains 22,357 rows and 11,001 named English icon groups: 9,930 resolve to one icon and 1,071 are ambiguous. Other locale slots were empty in these packaged inputs and remain empty in the output; live native sources still match their own localized names. The generated school index contains 1,460 name/school pairs for names that are ambiguous across the full database: 504 resolve to one icon and 956 remain ambiguous. Every matching row participates; there is no ability or class whitelist. This coverage does not establish a complete list of every effect reachable through variable or indirect native calls.

## Runtime behavior

The meter calls this same resolver through `sct.GetSourceIcon`; it has no
separate item/spell scan or learned-item registry. Generated general-item data,
live native item lookup, ambiguity handling and the unknown-icon constant are
shared by both consumers. Item cache misses remain retryable without a new
event or updater. The native record join and eight-repository research are in
[SOURCE-ICONS.md](SOURCE-ICONS.md). The meter alone wraps the resolved image in
its existing circular gold rim; SCT keeps its own icon renderer and visibility.

The optional Healing Done context of `sct.GetSourceIcon(name, healing, proc)`
also recognizes the exact native Regeneration, Leech, Healing on Kill, Level Up
and Soul Link records when their proc flag is off. Their icons come from reviewed
native producer instructions, with all fourteen exact captions cached by the
active language; see [DAMAGE-METER.md](DAMAGE-METER.md#native-healing-icons).
This class-independent healing-category context is applied before the common
`CombatIcon` lookup. Named healing spells, item sources and damage/boss views
otherwise share the same resolver and ambiguity handling. No class-specific
branch or guessed healing spell icon is added.

The selected Czech game catalog adds exact-name candidates in `localization/data.lua` through its optional `spellNames` field. `scripts/generate_localization.py` derives them from official `ability.*.name` entries and literal native keys matching the verified custom-talent names in `SpellIconCatalog.game`. It does not reverse-map arbitrary catalog values: an armor-set caption such as English `Wrath` has a different Czech grammatical form from the actual ability. The generator reads the existing generated icon module as text metadata, never as Lua code, and leaves the pinned icon tables unchanged.

For Czech only, generated lookups combine the direct name with every exact canonical English candidate. Missing mappings remain missing; a conflicting native icon or differing icon choices remain ambiguous within that source tier. Database candidates use the English source tables and refine only with the actual parsed damage school. Refinement requires exactly one participating canonical English name: the existing per-school tables cover English name-wide ambiguities, so a merged group of different English names retains ambiguity rather than dropping incomplete candidates. Spellbook, observed aura and learned native-talent caches still use the original emitted names and retain their existing priority. The selected game language is read at lookup time, so aliases do not depend on a stale base-client locale. No hit names, grouping, schools or ownership are rewritten, and no new scan, setting, SavedVariable, spell ID or texture is introduced. The generated name candidates establish display metadata only; actual Czech combat-name publication and icon rendering remain unverified in-game.

`modules/nameplates/icons.lua` contains generated name/path tables with 842 deduplicated texture paths. It loads once before SCT; hits use direct table lookups. The addon does not open an executable, archive or database at runtime and requires no companion or client patch. No raw binary, DBC, bitmap, description text or tool dependency is shipped in the runtime package.

Existing live icon observations remain demand-driven by unresolved hits, dirty events and one global 0.35-second scan limit. Target/mouseover observations inspect at most 16 debuffs per token through a private hidden tooltip, independently of the visible tooltip and encounter renderer. A same-UI-time addon message does not suppress all metadata sources. Learned observations clear on world leave/logout; the generated tables describe fixed display metadata, with no gameplay state or SavedVariables. Icons already animating are not retroactively changed when a later observation supplies metadata.

The catalog never establishes a learned talent, aura application, damage school, source ownership, enemy identity or timer. Native message parsing and existing SCT hit behavior retain those responsibilities.

## Source provenance

The native game catalogs were read from the owner's packaged `AzerothSurvivors.exe`, SHA-256 `96e24dcd0e53fc13a6fdef5826aa46f77a29aa1aad4abd585adf04e94b2756d3`, size 139,779,584 bytes. The native class table begins at zero-based file offset 115721904. Its nine 200-byte class records each own three 64-byte tree descriptors; the descriptors select their complete arrays of 120-byte nodes through stored pointer/count slices. Each node's key, display name and icon basename come from UTF-8 pointer/length fields at node offsets 32, 48 and 64. This build's node layout differs from the older extractor's 104-byte records; the executable hash guard and all offsets were updated together.

The complete 113-record native ability array occupies file offsets `[112808376, 112821936)`, with 120-byte records. Its key, display name and icon basename come from stored pointer/length fields at record offsets 0, 16 and 32. Extraction walks every ability and every selected talent node; it does not select reported spell keys or infer associations from neighboring text. Only exact display names and texture paths enter the generated runtime table.

The fixed-effect selection comes from reviewing all 34 direct calls to the pinned native damage function at virtual address `0x145931b50`. Six sites supply an immediate spell ID in `r9d`; the remaining sites use ability fields or live values. The extractor pins those six producer/call pairs, reads the immediate operands, checks their native call destination and joins each ID to its exact `Spell.dbc`/`SpellIcon.dbc` row. This selects IDs 1122 (Inferno), 467 (Thorns, two sites), 15237 (Holy Nova), 6353 (Soul Fire) and 740 (Tranquility). It is the complete fixed-ID subset of those reviewed direct calls, not a scan of arbitrary integers or a list of reported spell names. Only the resulting exact names and icons enter the separate `effects` runtime table; IDs and code addresses remain developer metadata.

The winning `Data/patch.MPQ` supplies these DBC inputs; no higher packaged patch supplied an override:

- `DBFilesClient\Spell.dbc`, SHA-256 `913d01c0376d88310ed4a44ea1115f30fd8be15af64ce304f4f17b6bc51cf15b`.
- `DBFilesClient\SpellIcon.dbc`, SHA-256 `938e8c333fe914938994fc331c04655d7eb5719bc2d1b29eaf5fad4239abdfdc`.

The generator reads the 173-field spell records' native name slots 120–127 and icon ID at field 117, joining that ID to the two-field icon table. It compares texture names case-insensitively with normalized separators/extensions, preserves a native path for display and rejects placeholder icons. All rows participate; same-name spells with different icons remain ambiguous rather than selecting a rank, class or NPC variant. For name-wide database ambiguities only, the generator additionally groups all rows by the native `School` index in field 1: Physical, Holy, Fire, Nature, Frost, Shadow and Arcane at indices 0 through 6. The runtime selects `schools[locale][school][name]` using the parser's canonical damage school, without guessing a school from an icon or effect name. Invalid native school indices supply no refinement. The native game tier is stronger than the generic spell database because it describes this game's actual ability and talent artwork.

## Regeneration

Read the winning DBC files from the packaged archive chain with an MPQ data reader, without loading the game. Extract both complete native game catalogs from the pinned executable, then author the shared Lua data:

```sh
python3 scripts/extract_talent_icons.py \
  --exe /path/to/AzerothSurvivors.exe \
  --spell-dbc /path/to/Spell.dbc \
  --spell-icon-dbc /path/to/SpellIcon.dbc \
  --output /tmp/game-talents.json

python3 scripts/generate_spell_icons.py \
  --spell-dbc /path/to/Spell.dbc \
  --spell-icon-dbc /path/to/SpellIcon.dbc \
  --game-catalog /tmp/game-talents.json \
  --output modules/nameplates/icons.lua
```

With a complete extracted native JSON (including its joined fixed-effect records), retain the existing generated DBC tables and their indices:

```sh
python3 scripts/generate_spell_icons.py \
  --game-catalog /tmp/game-talents.json \
  --refresh-game-only \
  --output modules/nameplates/icons.lua
```

This mode reads only the generated path pool's JSON-compatible string literals, appends missing paths and replaces the native talent, ability and fixed-effect tables and their source hashes. It never loads or evaluates Lua. Existing spell-database and school tables stay untouched. Keeping `game` talent names separate from `abilities` and `effects` also preserves the Czech generator's restriction on literal aliases to verified talent keys; official ability-name keys remain independent. Fixed effects add no unverified translated aliases. Full generation from the DBC inputs remains supported by the first command.

The executable extractor is pinned to the identified binary; a different build requires fresh source/data analysis before its offsets can be used. The generated header records the input hashes. Only the generated Lua module belongs to the runtime manifest; tools and this documentation stay on GitHub.

This change used supplied combat logs and read-only source/data inspection. Data extraction and catalog authoring do not execute addon or game code. No local tests, formatting/static/syntax checks, addon execution or game startups were run. GitHub Actions provides the authorized static checks; actual in-game appearance remains unverified.

## Reported Thorns ambiguity — 2026-10-17

The supplied raw log contains 90 explicitly named Nature-damage Thorns hits. The native database has 24 rows named `Thorns` across three schools and three icons, so the original name-only lookup correctly remained ambiguous. All 14 Nature rows share `Interface\\Icons\\Spell_Nature_Thorns`; the generated school refinement therefore resolves those logged hits without a Thorns-specific condition. Physical rows still conflict, while the Arcane rows retain their own native icon. The owner's screenshot confirms Thorns is an active damage-meter entry, but meter totals alone do not identify unnamed damage events.

## Reported Imp damage question marks — 2026-10-20

The supplied `message.txt` contains 103 named Fireball damage events, with Fire explicitly present in their combat text. Fireball is ambiguous in both the full spell database and its Fire subset, and is absent from the player's active `AZSSPELLS` list in that capture. The older talent-only native catalog had no Fireball entry, leaving the question-mark fallback.

The native ability record at file offset 112816296 pairs key `fireball`, exact display name `Fireball` and icon `Spell_Fire_FlameBolt`. Adding the complete ability array to the existing native game tier resolves that emitted name through the shared lookup, without a Warlock, Imp, Fireball or spell-ID branch. Native spellbook and observed-aura metadata keep their existing higher priority. Damage parsing, ownership, amounts, matching and grouping are unchanged. Inferno required the additional native effect trace below. No submitted report or raw binary is shipped, and no local checks or game execution were run.

## Start-of-round Inferno and archive inspection — 2026-10-20

The new supplied round-start capture's first damage event is `Your Inferno hits Kobold Vermin for 461 Fire damage.` It precedes the first playing snapshot at `t=0.03`. The earlier capture also contains six named Fire-damage Inferno events. The full database has seven Inferno rows across three schools and three distinct icons; its two Fire rows disagree, so the original fallback was deliberate.

The pinned executable sets `r9d` to spell 1122 at `0x1458ea8fe` and calls the shared damage function at `0x1458ea904`. The same native path sets the summon source temporarily while applying the impact. Spell 1122's exact database row pairs `Inferno` with `Interface\\Icons\\Spell_Shadow_SummonInfernal`. Including all six reviewed fixed-ID sites supplies this mapping through the shared conflict-preserving native tier, with no Inferno conditional or inferred damage ownership. The native Fire school remains as emitted even though this generic database row lists Shadow; the icon lookup never rewrites the hit.

Read-only inspection of the packaged `patch-8.MPQ` through `patch.MPQ` hash/block tables found 840 of the 842 generated texture paths. The two absent paths are `Interface\\Icons\\Ability_Temp` (nine old/test database rows) and `Interface\\Icons\\INV_Food_Egg_02` (four Food Idle rows). Neither supplies a damage name in the submitted captures. The Inferno texture is present in `patch.MPQ`; this report therefore identified a missing name mapping, rather than an absent Inferno bitmap. Archive membership does not establish runtime rendering.

The executable also pairs summon names with their own icons, including Imp, Voidwalker, Felguard, Infernal, Pit Lord, Succubus, Doomguard and Felhunter. These summon records do not establish an icon for every named damage effect, so they were not inserted into the spell-name catalog. The existing Ferocity talent-name collision remains ambiguous. This inspection does not claim all possible future question marks are eliminated.
