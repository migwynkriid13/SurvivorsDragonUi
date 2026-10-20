# Languages

SurvivorsDragonUi includes English, Polish, Czech (**Čeština**), German, Brazilian Portuguese, Spanish, French, Romanian, Turkish, Russian, Ukrainian, Simplified Chinese, Japanese and Korean. `core/localization.lua` supplies the shared text functions; `localization/data.lua` contains the generated runtime text. Both load before the editor and HUD modules.

## Following the game

The initial fallback is the native `GetLocale()` value, with aliases for the supported language codes, including `csCZ` → `cs`. This alone does not establish the language selected by the game's fourteen-language picker: the inspected [base-client implementation](https://github.com/samwhosung/benilla/blob/main/crates/benilla-ui/src/script/client.rs) reads the older client locale table.

The authoritative addon-visible evidence is the game's localized text published in the official `AZS_ZONE` snapshot. For each candidate catalog, compare the exact `zname` and `zsub` associated with the stable `zone` key and `cname` associated with the stable `class` key. Select the unique highest-scoring catalog. Shared proper names alone can tie; a tie or unfamiliar wording retains the existing fallback rather than choosing a language arbitrarily. The normal localized zone subtitle distinguishes the catalogs without deriving anything from an enemy or item name.

Read the native phase before retained snapshots. Accept only `ready`, `playing`, `choosing`, `paused`, `dead` and `victory`. World entry and `AZSZONE` schedule a deferred read, allowing the native parser to finish regardless of handler order. Pending reads retry at most five times a second until the phase and zone snapshot are available, then stop. World leave/logout cancel pending work. An active-world language change is reflected when the game republishes its zone metadata; there is no invented language getter or client patch.

Language is session-only. No setting, command, profile, SavedVariable, client preference write or gameplay snapshot is added. Existing confirmed geometry, visibility, display booleans, timer font choices and combat-text mode retain their normal lifecycle.

## Display text

The shared editor/button factories bind only addon-owned captions. Changing the language refreshes existing bound captions, including layout handles and pending editor status text, without recreating controls or discarding drafts. Dynamic HUD/tooltips read the shared translations when they update.

Coverage includes the four editor tabs and their controls, numeric-layout hints and status, run label, counter and encounter hints, waypoint titles/map-pin hints/distance units, menu buttons, chat scrolling/copy captions, combat-text feedback/miss captions, cooldown unit abbreviations and the frame inspector's explanatory text. Font family names, addon/game names, slash-command tokens, API identifiers, native unit/item/spell names, raw captured messages/events and bootstrap error diagnostics remain verbatim.

Editor controls measure native glyph widths across all fourteen translations before choosing shared widths. The dialog stays within the available viewport width. Jewelry retains natural-width measurement, its 272-unit wrapping column and the native wrapped-height measurement; no character-count width estimates or UTF-8 byte slicing are introduced. The frame inspector truncates previews only at complete UTF-8 character boundaries. Copy's hint area reserves two lines.

Ordinary captions use the game's `DEFAULT` font. When the translated run prefix contains non-ASCII glyphs, run/sample rendering also uses `DEFAULT` for the game's glyph support; the saved font selection is retained. Other run prefixes keep the user's selected face. Returning to a language with an ASCII run prefix reapplies that selection.

## Jewelry effects

All 69 existing effect templates have fourteen localized input/output pairs. English compact output retains the established wording. Other languages reuse the game's compact modifier captions where available; reviewed compact translations cover the DoT-cap, revival and special-effect templates. The reference English pairs remain listed in [JEWELRY-EFFECTS.md](JEWELRY-EFFECTS.md).

The formatter lazily compiles complete literal templates per language, with typed numeric fields and bounded subject fields. Subjects can begin with accented, Cyrillic or Asian characters; ASCII sentence separators, newlines, colons, percent signs and full-width sentence/colon separators are excluded. Numeric text is copied without rounding or converting decimal separators. Native singular/plural variants, additional targets, units, conditions, durations, range, proc chances, half-health revives and explicit numeric caps remain part of the output.

Both native cap spellings represented by ` (max)` and `{mods} (max)` are supported in each language, including full-width parentheses and different Chinese cap words. The exact recognized cap suffix and localized per-second proc ceiling are retained after rewriting. Latin or CJK final periods and wrapped ASCII whitespace are tolerated. Unknown wording, unsupported values or conflicting cross-language matches keep the original description. The selected language is tried first; a description received before language metadata may use another complete template only when the resulting fallback is unambiguous. Matching a tooltip never changes the UI language.

Inventory reading remains effects-only, using the native localized trigger globals with existing English fallbacks. It still handles five equipped slots, both attachment modes and existing refresh/cleanup. No item lookup, sample values or alternate equipment feed is introduced.

## Chat

Existing learned/skill and level formats still prefer native GlobalStrings and preserve their arguments. Selected native system-announcement patterns, talent-progress templates, self-loot prefixes and collection markers additionally use the game's translated catalogs. Output captions use the selected language. Item hyperlinks, quality colors, native amounts, supplied class names and collection-status wording/colors are preserved. This adds no new hidden-announcement category and does not translate player conversation, native item/ability names or raw diagnostic capture.

The composite damage/maximum-health/regeneration notice also matches the selected native template through named fields. Czech places a space before the percent sign and uses its own sentence wording, so the previous English-only regular expression could not recognize it. The existing gain formatting removes at most one incoming plus before adding the styled plus, retaining the exact integer or decimal text. The English compatibility fallback and the existing level/stat coalescing remain. The extracted JSON does not contain learned/skill or level-announcement GlobalStrings; their existing native-format path stays in place without invented Czech inputs.

## Czech source and integration

The installed client inspected on 2026-10-20 contains fourteen complete JSON dictionaries, each with 2,636 keys. Its Czech dictionary starts at zero-based file offset `113211537` (`0x6bf7891`), immediately after native `csČeština` label bytes. The original Czech JSON has SHA-256 `ef2f716889ff757c688e105c9fcacd88c8de69630f886a383147ae20049c5e77`. Examples of its exact language evidence include `Válečník`, `Kněz`, `Elwynnský les` and `Povstání Defias`; runtime detection compares the relevant stable class/zone keys, never an unrestricted text or byte guess.

All addon UI captions have Czech source entries, with native `@key` references where the game supplies an exact caption. The 24 compact-effect override rows also include Czech; the remaining effect outputs reuse the native compact modifier captions. The native Czech cap markers are ` (max.)` and `{mods} (max.)`, and its rate suffix is `, nejvýš {n}krát za sekundu`. They are copied with the templates rather than translated from English at runtime. The previous thirteen languages' selected native entries, 69 effect input templates and cap/rate text were unchanged in the new executable.

Optional custom SCT icons use exact Czech names derived only from the official `ability.*.name` fields and native keys matching the already verified custom-talent names. The 112 official ability-name keys and 345 verified custom-talent keys produce 449 non-identity alias groups; two identity-only groups need no alias. These aliases connect to existing English display metadata; they do not invent spell IDs, icons, schools or learned state. Different canonical names sharing one Czech name remain candidates, and differing icons remain ambiguous within each generated source tier. Live spellbook/aura/talent observations keep their existing priority. Unknown names retain the existing fallback. Only Czech receives this additional alias table; see [SCT-ICONS.md](SCT-ICONS.md) for the underlying metadata and limitations.

## Source and maintenance

The stored-level button uses the user-requested **LEVEL UP** heading through `localization/ui.tsv` and the matching fourteen runtime UI entries. This is addon wording rather than a native caption. The former `Level Up!` and `LEVEL {n}` selections were removed with the current-level subtitle. See [STORED-LEVELS.md](STORED-LEVELS.md); other generated catalogs and the generator's reviewed source fingerprint are unchanged.

Source executable SHA-256: `6382e9ae654295293b82d48fb07a1aa999132775bda10c6c6f80d973d2c1ddfb`. The reviewed physical catalog order is `en/pl/cs/de/pt/es/fr/ro/tr/ru/uk/zh/ja/ko`. The generator reads the client only as data; it never launches it or executes addon/formatter code. The previous thirteen-language source was pinned to `2149da82c8e6e1096cdd7d600c60a2b7d763a6969bae425323db9ebbe6e56a4e` with 2,621 keys per catalog.

- `localization/effects.json` records each native English source key, existing English compact form and optional native compact-output key.
- `localization/effects.tsv` contains thirteen compact translations for the templates needing addon-specific wording. Rows follow the effect numbers in `effects.json`.
- `localization/ui.tsv` contains English caption keys and thirteen translations, in the header's language order. An `@key` cell explicitly reuses a native catalog entry. Both TSV files identify their columns by code; Czech is appended without reordering existing translation columns, independently of its third position in the executable.
- `localization/native-keys.json` selects native captions/chat templates. The generator also includes only the identity names/subtitles needed for language detection.
- `scripts/generate_localization.py --client PATH_TO_CLIENT` prepares `localization/data.lua`. Its pinned fingerprint and catalog-count guard require source review before accepting a different game build or language order. It supplies neither fixed gameplay values nor a complete localization dump.

The runtime manifest adds only `core/localization.lua` and `localization/data.lua`; source JSON/TSV, documentation and the generator do not enter the release ZIP. Source inspection and data generation do not establish packaged-game behavior or native-speaker translation approval. No local tests, syntax checks, formatting tools or addon/game execution were run. The existing PR GitHub Actions checks are the authorized static checks.
