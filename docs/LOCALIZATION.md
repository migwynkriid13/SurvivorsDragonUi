# Languages

SurvivorsDragonUi includes English, Polish, German, Brazilian Portuguese, Spanish, French, Romanian, Turkish, Russian, Ukrainian, Simplified Chinese, Japanese and Korean. `core/localization.lua` supplies the shared text functions; `localization/data.lua` contains the generated runtime text. Both load before the editor and HUD modules.

## Following the game

The initial fallback is the native `GetLocale()` value, with aliases for the supported language codes. This alone does not establish the language selected by the game's thirteen-language picker: the inspected [base-client implementation](https://github.com/samwhosung/benilla/blob/main/crates/benilla-ui/src/script/client.rs) reads the older client locale table.

The authoritative addon-visible evidence is the game's localized text published in the official `AZS_ZONE` snapshot. For each candidate catalog, compare the exact `zname` and `zsub` associated with the stable `zone` key and `cname` associated with the stable `class` key. Select the unique highest-scoring catalog. Shared proper names alone can tie; a tie or unfamiliar wording retains the existing fallback rather than choosing a language arbitrarily. The normal localized zone subtitle distinguishes the catalogs without deriving anything from an enemy or item name.

Read the native phase before retained snapshots. Accept only `ready`, `playing`, `choosing`, `paused`, `dead` and `victory`. World entry and `AZSZONE` schedule a deferred read, allowing the native parser to finish regardless of handler order. Pending reads retry at most five times a second until the phase and zone snapshot are available, then stop. World leave/logout cancel pending work. An active-world language change is reflected when the game republishes its zone metadata; there is no invented language getter or client patch.

Language is session-only. No setting, command, profile, SavedVariable, client preference write or gameplay snapshot is added. Existing confirmed geometry, visibility, display booleans, timer font choices and combat-text mode retain their normal lifecycle.

## Display text

The shared editor/button factories bind only addon-owned captions. Changing the language refreshes existing bound captions, including layout handles and pending editor status text, without recreating controls or discarding drafts. Dynamic HUD/tooltips read the shared translations when they update.

Coverage includes the four editor tabs and their controls, numeric-layout hints and status, run label, counter and encounter hints, waypoint titles/map-pin hints/distance units, menu buttons, chat scrolling/copy captions, combat-text feedback/miss captions, cooldown unit abbreviations and the frame inspector's explanatory text. Font family names, addon/game names, slash-command tokens, API identifiers, native unit/item/spell names, raw captured messages/events and bootstrap error diagnostics remain verbatim.

Editor controls measure native glyph widths across all thirteen translations before choosing shared widths. The dialog stays within the available viewport width. Jewelry retains natural-width measurement, its 272-unit wrapping column and the native wrapped-height measurement; no character-count width estimates or UTF-8 byte slicing are introduced. The frame inspector truncates previews only at complete UTF-8 character boundaries. Copy's hint area reserves two lines.

Ordinary captions use the game's `DEFAULT` font. When the translated run prefix contains non-ASCII glyphs, run/sample rendering also uses `DEFAULT` for the game's glyph support; the saved font selection is retained. Other run prefixes keep the user's selected face. Returning to a language with an ASCII run prefix reapplies that selection.

## Jewelry effects

All 69 existing effect templates have thirteen localized input/output pairs. English compact output retains the established wording. Other languages reuse the game's compact modifier captions where available; reviewed compact translations cover the DoT-cap, revival and special-effect templates. The reference English pairs remain listed in [JEWELRY-EFFECTS.md](JEWELRY-EFFECTS.md).

The formatter lazily compiles complete literal templates per language, with typed numeric fields and bounded subject fields. Subjects can begin with accented, Cyrillic or Asian characters; ASCII sentence separators, newlines, colons, percent signs and full-width sentence/colon separators are excluded. Numeric text is copied without rounding or converting decimal separators. Native singular/plural variants, additional targets, units, conditions, durations, range, proc chances, half-health revives and explicit numeric caps remain part of the output.

Both native cap spellings represented by ` (max)` and `{mods} (max)` are supported in each language, including full-width parentheses and different Chinese cap words. The exact recognized cap suffix and localized per-second proc ceiling are retained after rewriting. Latin or CJK final periods and wrapped ASCII whitespace are tolerated. Unknown wording, unsupported values or conflicting cross-language matches keep the original description. The selected language is tried first; a description received before language metadata may use another complete template only when the resulting fallback is unambiguous. Matching a tooltip never changes the UI language.

Inventory reading remains effects-only, using the native localized trigger globals with existing English fallbacks. It still handles five equipped slots, both attachment modes and existing refresh/cleanup. No item lookup, sample values or alternate equipment feed is introduced.

## Chat

Existing learned/skill and level formats still prefer native GlobalStrings and preserve their arguments. Selected native system-announcement patterns, talent-progress templates, self-loot prefixes and collection markers additionally use the game's translated catalogs. Output captions use the selected language. Item hyperlinks, quality colors, native amounts, supplied class names and collection-status wording/colors are preserved. This adds no new hidden-announcement category and does not translate player conversation, native item/ability names or raw diagnostic capture.

## Source and maintenance

The inspected client has thirteen embedded JSON dictionaries with 2,621 keys each. Source SHA-256: `2149da82c8e6e1096cdd7d600c60a2b7d763a6969bae425323db9ebbe6e56a4e`. The generator reads the client only as data; it never launches it or executes addon/formatter code.

- `localization/effects.json` records each native English source key, existing English compact form and optional native compact-output key.
- `localization/effects.tsv` contains twelve compact translations for the templates needing addon-specific wording. Rows follow the effect numbers in `effects.json`.
- `localization/ui.tsv` contains English caption keys and twelve translations, in the header's language order. An `@key` cell explicitly reuses a native catalog entry.
- `localization/native-keys.json` selects native captions/chat templates. The generator also includes only the identity names/subtitles needed for language detection.
- `scripts/generate_localization.py --client PATH_TO_CLIENT` prepares `localization/data.lua`. Its pinned fingerprint and catalog-count guard require source review before accepting a different game build or language order. It supplies neither fixed gameplay values nor a complete localization dump.

The runtime manifest adds only `core/localization.lua` and `localization/data.lua`; source JSON/TSV, documentation and the generator do not enter the release ZIP. Source inspection and data generation do not establish packaged-game behavior or native-speaker translation approval. No local tests, syntax checks, formatting tools or addon/game execution were run. The existing PR GitHub Actions checks are the authorized static checks.
