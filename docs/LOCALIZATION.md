# Languages

SurvivorsDragonUi includes English, Polish, Czech (**Čeština**), German, Brazilian Portuguese, Spanish, French, Romanian, Turkish, Russian, Ukrainian, Simplified Chinese, Japanese and Korean. `core/localization.lua` supplies the shared text functions; `localization/data.lua` contains the generated runtime text. Both load before the editor and HUD modules.

## Following the game

The initial fallback is the native `GetLocale()` value, with aliases for the supported language codes, including `csCZ` → `cs`. This alone does not establish the language selected by the game's fourteen-language picker: the inspected [base-client implementation](https://github.com/samwhosung/benilla/blob/main/crates/benilla-ui/src/script/client.rs) reads the older client locale table.

The authoritative addon-visible evidence is the game's localized text published in the official `AZS_ZONE` snapshot. For each candidate catalog, compare the exact `zname` and `zsub` associated with the stable `zone` key and `cname` associated with the stable `class` key. Select the unique highest-scoring catalog. Shared proper names alone can tie; a tie or unfamiliar wording retains the existing fallback rather than choosing a language arbitrarily. The normal localized zone subtitle distinguishes the catalogs without deriving anything from an enemy or item name.

Read the native phase before retained snapshots. Accept only `ready`, `playing`, `choosing`, `paused`, `dead` and `victory`. World entry and `AZSZONE` schedule a deferred read, allowing the native parser to finish regardless of handler order. Pending reads retry at most five times a second until the phase and zone snapshot are available, then stop. World leave/logout cancel pending work. An active-world language change is reflected when the game republishes its zone metadata; there is no invented language getter or client patch.

Language is session-only. No setting, command, profile, SavedVariable, client preference write or gameplay snapshot is added. Existing confirmed geometry, visibility, display booleans, timer font choices and combat-text mode retain their normal lifecycle.

## Display text

The meter's **Font size** and its hint remain translated in all fourteen source/runtime UI catalogs. **Show grid**, its hint and the revised Layout drag instructions also have all fourteen translations. The removed meter/tracker width sliders' three captions are absent from both source and runtime UI catalogs. Native catalogs, spell aliases, effects and the older full-catalog fingerprint are unchanged by these editor-caption updates.

The custom run-timer and boss-bar enable captions and their native-display
hints have source TSV and runtime UI entries in all fourteen languages. Only
these four caption entries were added; native catalogs, effects and aliases
are unchanged. Existing measured controls size the boss page and timer master
switch, with two hint lines reserved above the timer styling controls.

The **Guardians in boss bar** caption and its boss-only hint have source TSV and
runtime UI entries in all fourteen languages. Only these new caption entries
were generated; the reviewed native catalogs, effects and aliases are unchanged.
The existing HUD editor measures their widths and includes the added row in its
scrolling content.

The shared editor/button factories bind only addon-owned captions. Changing the language refreshes existing bound captions, including layout handles and pending editor status text, without recreating controls or discarding drafts. Dynamic HUD/tooltips read the shared translations when they update.

The two waypoint mirror captions and their shared arrow/icon hint have source TSV
entries and runtime UI entries in all fourteen languages. The HUD editor measures
them through its existing shared label/description sizing and scrolls the paired
guidance/mirror rows. Only these new caption entries were generated; reviewed
native catalogs, effects and aliases remain unchanged.

Coverage includes the four editor tabs and their controls, numeric-layout hints and status, run label, counter and encounter hints, waypoint titles/map-pin hints/distance units, menu buttons, chat scrolling/copy captions, combat-text feedback/miss captions, cooldown unit abbreviations and the frame inspector's explanatory text. Font family names, addon/game names, slash-command tokens, API identifiers, native unit/item/spell names, raw captured messages/events and bootstrap error diagnostics remain verbatim.

Editor controls measure native glyph widths across all fourteen translations before choosing shared widths. The dialog stays within the available viewport width. Jewelry retains natural-width measurement, its 272-unit wrapping column and the native wrapped-height measurement; no character-count width estimates or UTF-8 byte slicing are introduced. The frame inspector truncates previews only at complete UTF-8 character boundaries. Copy's hint area reserves two lines.

Ordinary captions use the game's `DEFAULT` font. When the translated run prefix contains non-ASCII glyphs, run/sample rendering also uses `DEFAULT` for the game's glyph support; the saved font selection is retained. Other run prefixes keep the user's selected face. Returning to a language with an ASCII run prefix reapplies that selection.

## Jewelry effects

All 69 existing effect templates have fourteen localized input/output pairs. English compact output retains the established wording. Other languages reuse the game's compact modifier captions where available; reviewed compact translations cover the DoT-cap, revival and special-effect templates. The reference English pairs remain listed in [JEWELRY-EFFECTS.md](JEWELRY-EFFECTS.md).

The formatter lazily compiles complete literal templates per language, with typed numeric fields and bounded subject fields. Subjects can begin with accented, Cyrillic or Asian characters; ASCII sentence separators, newlines, colons, percent signs and full-width sentence/colon separators are excluded. Numeric text is copied without rounding or converting decimal separators. Native singular/plural variants, additional targets, units, conditions, durations, range, proc chances, half-health revives and explicit numeric caps remain part of the output.

Both native cap spellings represented by ` (max)` and `{mods} (max)` are supported in each language, including full-width parentheses and different Chinese cap words. The exact recognized cap suffix and localized per-second proc ceiling are retained after rewriting. Latin or CJK final periods and wrapped ASCII whitespace are tolerated. Unknown wording, unsupported values or conflicting cross-language matches keep the original description. The selected language is tried first; a description received before language metadata may use another complete template only when the resulting fallback is unambiguous. Matching a tooltip never changes the UI language.

Inventory reading remains effects-only, using the native localized trigger globals with existing English fallbacks. It still handles five equipped slots, both attachment modes and existing refresh/cleanup. No item lookup, sample values or alternate equipment feed is introduced.

## Chat

Existing learned/skill and level formats still prefer native GlobalStrings and preserve their arguments. Selected native system-announcement patterns, talent-progress templates, self-loot prefixes and collection markers additionally use the game's translated catalogs. Output captions use the selected language. Item hyperlinks, quality colors, native amounts, supplied class names and collection-status wording/colors are preserved. Player conversation bodies, native item/ability names and raw diagnostic capture retain their original text. Player say prefixes use the native localized format to display a clickable, unbracketed `Name: message`.

The requested **A stampede charges through!**, **A wall of foes closes in!** and **A pack hunts you!** notices are hidden only from regular chat using their exact native wording in all fourteen languages. Raw capture and the custom banner retain each notice. Their three native-key rows and runtime UI/native entries were extracted from the installed executable on 2026-10-22, SHA-256 `e069bf3152f8d8f7160d66388907fc181c733bd170aa150d3b7ff7adf251e048`, using the reviewed English/Polish/Czech-through-Korean catalog order. Other catalog entries, effects and aliases remain unchanged.

The composite damage/maximum-health/regeneration notice also matches the selected native template through named fields. Czech places a space before the percent sign and uses its own sentence wording, so the previous English-only regular expression could not recognize it. The existing gain formatting removes at most one incoming plus before adding the styled plus, retaining the exact integer or decimal text. The English compatibility fallback and the existing level/stat coalescing remain. The extracted JSON does not contain learned/skill or level-announcement GlobalStrings; their existing native-format path stays in place without invented Czech inputs.

## Czech source and integration

The installed client inspected on 2026-10-20 contains fourteen complete JSON dictionaries, each with 2,636 keys. Its Czech dictionary starts at zero-based file offset `113211537` (`0x6bf7891`), immediately after native `csČeština` label bytes. The original Czech JSON has SHA-256 `ef2f716889ff757c688e105c9fcacd88c8de69630f886a383147ae20049c5e77`. Examples of its exact language evidence include `Válečník`, `Kněz`, `Elwynnský les` and `Povstání Defias`; runtime detection compares the relevant stable class/zone keys, never an unrestricted text or byte guess.

All addon UI captions have Czech source entries, with native `@key` references where the game supplies an exact caption. The 24 compact-effect override rows also include Czech; the remaining effect outputs reuse the native compact modifier captions. The native Czech cap markers are ` (max.)` and `{mods} (max.)`, and its rate suffix is `, nejvýš {n}krát za sekundu`. They are copied with the templates rather than translated from English at runtime. The previous thirteen languages' selected native entries, 69 effect input templates and cap/rate text were unchanged in the new executable.

The original Czech icon integration supplied 449 non-identity alias groups from official ability-name keys and verified custom-talent keys. The shared alias preparation now covers every supported language, as described below.

## Source-icon languages — 2026-10-27

The Portuguese report showed working native meter totals and bars but question marks for translated abilities. Only Czech had a `spellNames` table; the packaged spell database has English names, and `GetLocale()` can differ from the game's picker. The shared SCT/meter resolver already reads aliases from the effective game language at lookup time. Supplying the missing tables fixes that metadata gap without changing native row names, values or language detection.

`scripts/generate_localization.py` now generates exact aliases for all fourteen catalogs. Selection remains limited to official `ability.*.name` fields and literal keys matching verified custom talents in `SpellIconCatalog.game`. It never reverse-maps arbitrary catalog values. Each translated name retains every canonical English candidate, including an identity candidate when another name shares it; conflicting icon choices remain ambiguous. Live spellbook/aura/talent observations retain their priority. Unknown or ambiguous names retain the shared question mark.

| Catalog | Non-identity alias groups | Groups with multiple English candidates |
| ------- | ------------------------- | --------------------------------------- |
| en      | 0                         | 0                                       |
| pl      | 446                       | 4                                       |
| cs      | 449                       | 0                                       |
| de      | 441                       | 0                                       |
| pt      | 447                       | 2                                       |
| es      | 448                       | 0                                       |
| fr      | 429                       | 2                                       |
| ro      | 442                       | 5                                       |
| tr      | 321                       | 1                                       |
| ru      | 448                       | 3                                       |
| uk      | 448                       | 3                                       |
| zh      | 450                       | 1                                       |
| ja      | 449                       | 2                                       |
| ko      | 449                       | 2                                       |

The installed executable, SHA-256 `80ac3217660a02020b3e09f1ce93bfaa6ba89abd9a9d62405b9f70114fd6d46c`, supplies these aliases. Its exact Portuguese pairs include `Dor Lancinante` → `Searing Pain`, `Seta Sombria` → `Shadow Bolt`, `Fogo do Inferno` → `Hellfire` and `Espiral da Morte` → `Death Coil`; each English name has a verified native ability icon in the existing catalog. Czech's group count is unchanged, with eleven translated labels refreshed to this client's wording. Other UI/native captions, effects, caps/rate text and the generator's original full-catalog fingerprint are preserved.

The bounded refresh reuses the item generator's hash-guarded native catalog reader. It replaces only `spellNames` blocks and requires all fourteen runtime language sections. Full generation also emits every language's aliases; run the bounded refresh afterward when retaining the separately pinned current alias source:

```sh
python3 -B scripts/generate_localization.py \
  --client /path/to/AzerothSurvivors.exe \
  --refresh-spell-names-only \
  --metadata /tmp/source-icon-languages.json
```

AzerothSurvivorsRE's `docs/analysis/run-meters-0.105.0.md` and `gameplay/addon_meters.rs::source_name` lead to localized ability/literal-talent names before wire publication. Its `docs/analysis/localization-loader-0.119.0.md` describes selected-language lookup with English fallback and external overrides. The retained `0.120.2/embedded-api.lua` meter parser still publishes names, amounts, rates, shares and proc flags without icons. These historical references guide the fix; the installed executable above supplies the actual translated data. Custom external translations or future wording can remain unresolved because the API supplies no stable spell key/icon for those rows.

Source/data preparation, manual diffs and pinned formatting do not establish in-game appearance or native-speaker approval; no local tests, standalone validation or addon/game execution was performed. See [SCT-ICONS.md](SCT-ICONS.md) for source-tier behavior and [PERFORMANCE.md](PERFORMANCE.md#source-icon-language-coverage--2026-10-27) for costs.

## Source and maintenance

The meter's **Melee** icon matches the exact native `Melee` caption in all
fourteen languages. These UI/native entries and `localization/native-keys.json`
reuse the installed executable's dictionaries, read as data on 2026-10-26 from
SHA-256 `291c281bd0a4255fdb3d04b2e442121e2df144f388f16de086b430e875aaad08`.
Catalogs were matched by their existing exact `class.warrior.name` identity;
no translated spell name, fuzzy match or runtime binary access is introduced.
Other native entries, effect templates, aliases and the generator's older source
fingerprint remain unchanged.

The 2026-10-27 healing-icon follow-up selects the same executable's exact
`Regeneration`, `Leech`, `Healing on Kill`, `Level Up` and `Soul Link` captions in all fourteen
languages. `ui.tsv` references those native keys with `@key` cells, and
`native-keys.json` plus the UI/native runtime sections retain them for regeneration.
`scripts/extract_meter_healing_icons.py` reads the reviewed producer/icon pairs
and matches embedded catalogs by existing `class.warrior.name` identity. Only
these selected captions are added; the general generator's pinned older native
catalogs, effect templates and spell-name aliases stay unchanged. The mapping
selects display metadata without translating or rewriting native meter rows.

The stored-level button uses the user-requested **LEVEL UP** heading through `localization/ui.tsv` and the matching fourteen runtime UI entries. This is addon wording rather than a native caption. The former `Level Up!` and `LEVEL {n}` selections were removed with the current-level subtitle. See [STORED-LEVELS.md](STORED-LEVELS.md); other generated catalogs and the generator's reviewed source fingerprint are unchanged.

Source executable SHA-256: `6382e9ae654295293b82d48fb07a1aa999132775bda10c6c6f80d973d2c1ddfb`. The reviewed physical catalog order is `en/pl/cs/de/pt/es/fr/ro/tr/ru/uk/zh/ja/ko`. The generator reads the client only as data; it never launches it or executes addon/formatter code. The previous thirteen-language source was pinned to `2149da82c8e6e1096cdd7d600c60a2b7d763a6969bae425323db9ebbe6e56a4e` with 2,621 keys per catalog.

- `localization/effects.json` records each native English source key, existing English compact form and optional native compact-output key.
- `localization/effects.tsv` contains thirteen compact translations for the templates needing addon-specific wording. Rows follow the effect numbers in `effects.json`.
- `localization/ui.tsv` contains English caption keys and thirteen translations, in the header's language order. An `@key` cell explicitly reuses a native catalog entry. Both TSV files identify their columns by code; Czech is appended without reordering existing translation columns, independently of its third position in the executable.
- `localization/native-keys.json` selects native captions/chat templates. The generator also includes only the identity names/subtitles needed for language detection.
- `scripts/generate_localization.py --client PATH_TO_CLIENT` prepares `localization/data.lua`. Its pinned fingerprint and catalog-count guard require source review before accepting a different game build or language order. It supplies neither fixed gameplay values nor a complete localization dump.

The runtime manifest adds only `core/localization.lua` and `localization/data.lua`; source JSON/TSV, documentation and the generator do not enter the release ZIP. Source inspection and data generation do not establish packaged-game behavior or native-speaker translation approval. No local tests, syntax checks, formatting tools or addon/game execution were run. The existing PR GitHub Actions checks are the authorized static checks.

The guardian tracker adds nine addon-caption rows for its heading, layout label,
states, formatted return text and lair tooltip. They are represented
in `ui.tsv` and all fourteen generated UI sections. The current executable was not
accepted as a replacement for the pinned native catalogs: its layout could not be
read by the existing extractor. Only the new TSV caption data was inserted into
the existing generated UI sections; native wording, effects, identity evidence and
Czech icon aliases remain from the reviewed source above.

The resting guardian caption is **Alive** in all fourteen languages; native due
rows optimistically use the same caption and green color. The tracker
uses shared boss-bar current / maximum health formatting instead of a Fighting
caption or percentage; the unused earlier status captions were removed.

The guardian settings page adds **Show dead** and its hint in all fourteen
source/runtime UI catalogs. It defaults on and replaces the header button's
session-only filter. The unused **Show living guardians only** and **Show all
lairs** captions are removed. Native row names and status captions are unchanged.

The action-bar **Show gryphons** caption and its winged-ornament hint have
source TSV entries and runtime UI entries in all fourteen languages. Only
these two caption rows were added; native catalogs, effects and aliases
remain unchanged. The existing editor measures both strings when sizing
the Action bar page.
