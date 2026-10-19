# Shared SCT icon metadata

Custom SCT resolves icons through one exact-name path for every class. Native combat messages already identify effects such as `Deadly Poison`, but passive damage can be absent from the player's spellbook and active `AZSSPELLS` list. Encounter debuff snapshots cover bosses and guardians; ordinary enemies can die without their auras ever being observed through a target or mouseover token. The game's custom talent screen also uses its own catalog, separate from standard `GetTalentInfo`.

## Lookup order

1. A valid native player spellbook texture.
2. An actually observed native aura texture, from a received phase-gated official `AZS_DEBUFFS` snapshot or a current target/mouseover debuff.
3. The generated complete native custom talent icon catalog.
4. A learned standard native talent's texture.
5. An unambiguous generated spell-database texture for the client's locale. When the name alone conflicts, refine only this tier with the combat message's parsed damage school.
6. The existing question mark when no usable mapping exists.

All keys are exact native names. There are no spell-specific or class-specific conditions in the resolver. Live spellbook and observed aura metadata retain priority over the generated catalog. Question-mark textures are rejected as successful lookups. Conflicting icons within a source tier are stored as `false`, which retains the fallback instead of borrowing an arbitrary icon from a weaker source. The database tier alone can narrow its own conflicting rows by the actual canonical damage school. A conflict that remains within that school still returns the fallback; this refinement never overrides ambiguity in a stronger native source. Actual aura and learned talent observations use separate caches, so different talent artwork cannot veto an observed debuff.

The generated file covers all 354 custom talent records across nine classes and 27 trees. Those records supply 345 distinct names: 344 resolve to one icon, and one remains ambiguous. The supplied spell database contains 22,357 rows and 11,001 named English icon groups: 9,930 resolve to one icon and 1,071 are ambiguous. Other locale slots were empty in these packaged inputs and remain empty in the output; live native sources still match their own localized names. The generated school index contains 1,460 name/school pairs for names that are ambiguous across the full database: 504 resolve to one icon and 956 remain ambiguous. Every matching row participates; there is no ability or class whitelist. This is shared coverage from complete source catalogs, not a claim that every possible future effect or locale is resolvable.

## Runtime behavior

The selected Czech game catalog adds exact-name candidates in `localization/data.lua` through its optional `spellNames` field. `scripts/generate_localization.py` derives them from official `ability.*.name` entries and literal native keys matching the verified custom-talent names in `SpellIconCatalog.game`. It does not reverse-map arbitrary catalog values: an armor-set caption such as English `Wrath` has a different Czech grammatical form from the actual ability. The generator reads the existing generated icon module as text metadata, never as Lua code, and leaves the pinned icon tables unchanged.

For Czech only, generated lookups combine the direct name with every exact canonical English candidate. Missing mappings remain missing; a conflicting native icon or differing icon choices remain ambiguous within that source tier. Database candidates use the English source tables and refine only with the actual parsed damage school. Refinement requires exactly one participating canonical English name: the existing per-school tables cover English name-wide ambiguities, so a merged group of different English names retains ambiguity rather than dropping incomplete candidates. Spellbook, observed aura and learned native-talent caches still use the original emitted names and retain their existing priority. The selected game language is read at lookup time, so aliases do not depend on a stale base-client locale. No hit names, grouping, schools or ownership are rewritten, and no new scan, setting, SavedVariable, spell ID or texture is introduced. The generated name candidates establish display metadata only; actual Czech combat-name publication and icon rendering remain unverified in-game.

`modules/nameplates/icons.lua` contains generated name/path tables with 841 deduplicated texture paths, 668,345 bytes of Lua source. It loads once before SCT; hits use direct table lookups. The addon does not open an executable, archive or database at runtime and requires no companion or client patch. No raw binary, DBC, bitmap, description text or tool dependency is shipped in the runtime package.

Existing live icon observations remain demand-driven by unresolved hits, dirty events and one global 0.35-second scan limit. Target/mouseover observations inspect at most 16 debuffs per token through a private hidden tooltip, independently of the visible tooltip and encounter renderer. A same-UI-time addon message does not suppress all metadata sources. Learned observations clear on world leave/logout; the generated tables describe fixed display metadata, with no gameplay state or SavedVariables. Icons already animating are not retroactively changed when a later observation supplies metadata.

The catalog never establishes a learned talent, aura application, damage school, source ownership, enemy identity or timer. Native message parsing and existing SCT hit behavior retain those responsibilities.

## Source provenance

The custom catalog was read from the owner's packaged `AzerothSurvivors.exe`, SHA-256 `7264d50b82a1ecc2b5f0fcf2f29669c2acaa8bb87c058e17898a47a12984ff30`. The native class table begins at zero-based file offset 109907016. Its nine 200-byte class records each own three 64-byte tree descriptors; the descriptors select their complete arrays of 104-byte nodes through stored pointer/count slices. Each node's key, display name and icon basename come from its actual UTF-8 pointer/length fields. Extraction walks every record and does not select spell keys or infer associations from adjacent text.

The winning `Data/patch.MPQ` supplies these DBC inputs; no higher packaged patch supplied an override:

- `DBFilesClient\Spell.dbc`, SHA-256 `913d01c0376d88310ed4a44ea1115f30fd8be15af64ce304f4f17b6bc51cf15b`.
- `DBFilesClient\SpellIcon.dbc`, SHA-256 `938e8c333fe914938994fc331c04655d7eb5719bc2d1b29eaf5fad4239abdfdc`.

The generator reads the 173-field spell records' native name slots 120–127 and icon ID at field 117, joining that ID to the two-field icon table. It compares texture names case-insensitively with normalized separators/extensions, preserves a native path for display and rejects placeholder icons. All rows participate; same-name spells with different icons remain ambiguous rather than selecting a rank, class or NPC variant. For name-wide database ambiguities only, the generator additionally groups all rows by the native `School` index in field 1: Physical, Holy, Fire, Nature, Frost, Shadow and Arcane at indices 0 through 6. The runtime selects `schools[locale][school][name]` using the parser's canonical damage school, without guessing a school from an icon or effect name. Invalid native school indices supply no refinement. The custom catalog is a separate stronger source because it describes this game's actual talent presentation.

## Regeneration

Read the winning DBC files from the packaged archive chain with an MPQ data reader, without loading the game. Extract the complete custom catalog from the pinned executable, then author the shared Lua data:

```sh
python3 scripts/extract_talent_icons.py \
  --exe /path/to/AzerothSurvivors.exe \
  --output /tmp/game-talents.json

python3 scripts/generate_spell_icons.py \
  --spell-dbc /path/to/Spell.dbc \
  --spell-icon-dbc /path/to/SpellIcon.dbc \
  --game-catalog /tmp/game-talents.json \
  --output modules/nameplates/icons.lua
```

The executable extractor is pinned to the identified binary; a different build requires fresh source/data analysis before its offsets can be used. The generated header records the input hashes. Only the generated Lua module belongs to the runtime manifest; tools and this documentation stay on GitHub.

This change used supplied combat logs and read-only source/data inspection. Data extraction and catalog authoring do not execute addon or game code. No local tests, formatting/static/syntax checks, addon execution or game startups were run. GitHub Actions provides the authorized static checks; actual in-game appearance remains unverified.

## Reported Thorns ambiguity — 2026-10-17

The supplied raw log contains 90 explicitly named Nature-damage Thorns hits. The native database has 24 rows named `Thorns` across three schools and three icons, so the original name-only lookup correctly remained ambiguous. All 14 Nature rows share `Interface\\Icons\\Spell_Nature_Thorns`; the generated school refinement therefore resolves those logged hits without a Thorns-specific condition. Physical rows still conflict, while the Arcane rows retain their own native icon. The owner's screenshot confirms Thorns is an active damage-meter entry, but meter totals alone do not identify unnamed damage events.
