# Jewelry effect wording

## Catalog and maintenance

The formatter in `modules/ui/jewelry.lua` uses the game's localized item-effect sentence templates rather than item IDs, screenshots or calculated stats. A read-only inspection of the Windows client on 2026-10-18 found 2,621 English localization keys. The item-modifier sections supply **47 general/named-ability templates and 22 special-modifier templates**, recorded below. This is coverage of those 69 templates in the inspected build; it does not establish exhaustive coverage of future versions, arbitrary spell descriptions or unsupported languages. All thirteen native catalogs are now represented; see [LOCALIZATION.md](LOCALIZATION.md). The pairs below document the unchanged English output.

Source fingerprint: SHA-256 `2149da82c8e6e1096cdd7d600c60a2b7d763a6969bae425323db9ebbe6e56a4e`. The embedded English JSON dictionary starts at byte offset `108160178` in this executable. The first item block runs from `Increases all damage you deal by {p}.` through `{who} strike {n} more targets.`; the later additions include weakening, strength, proc rate, stun duration and four special modifiers. Only functional effect templates are recorded here; the executable and the complete localization dictionary are not distributed.

To update for a new game build, inspect its item-modifier catalogs as data, compare them with this list, update the source rows under `localization/` and prepare `localization/data.lua` using the documented data generator. Do not execute the game, addon or formatter locally. Keep already concise native captions and unknown descriptions unchanged. A template can cover every item and ability using that wording, so new items and changing values do not require screenshots or item-specific branches. A changed native sentence deliberately falls back to its original wording until its template is reviewed.

## Value and meaning preservation

- Every displayed value comes from the live equipped-item tooltip. The catalog supplies wording only; it supplies no fixed item values, item lookup, stat calculations or gameplay data.
- `{p}`, `{frac}` and `{chance}` capture native percentage text, including its percent sign. `{v}` and `{g}` capture native numeric text with its optional percent sign. A percent sign already present in a template stays literal, with a bare numeric capture before it.
- Decimal points and decimal commas are copied without numeric conversion or rounding. Unsupported value formats keep the original description rather than guessing their units.
- `{who}`, `{hits}` and `{spell}` copy the native subject, including ordinary spell names, `your hits` and critical-hit subjects. Names containing sentence separators, colons or percent signs are not rewritten.
- `{n}` is an integer count. A leading plus in an additional-target count is replaced by the display's plus sign; the numeric text is unchanged. Both `strike`/`strikes` and singular/plural native target templates are covered.
- Conditions, fixed thresholds, distances, durations, proc chances, shield requirements, half-health revives, life limits and explicit numeric caps stay in the compact wording. Health regeneration distinguishes flat health per second from a percentage of maximum health per second.
- A native trailing `(max)` or its localized equivalent is restored after a successful rewrite. A native `, at most N times a second` suffix is also retained in full. No cap is inferred from an item's name or value.
- Wrapped whitespace and an optional final period are tolerated. Each compiled rule anchors both ends of the description and escapes its literal wording. Only typed fields vary; there is no arbitrary substring replacement.
- Descriptions that do not match one complete catalog template, including unfamiliar compounds and unsupported languages, retain their original wording and markers after the existing trigger-label removal. The separate, already concise native stat captions have no rewrite rule.

These rewrites remain limited to the five equipped jewelry sockets' effects-only hover cards. Armor, flat Health metadata, ability rows, equipment selection and other item tooltips are unchanged. No catalog data or hover state is saved. Source inspection and diff review do not establish packaged-game rendering. No local validation, tests, syntax checks or addon/game execution were performed; the existing PR GitHub Actions checks are the authorized static checks.

## General stats: 31 templates

- `Increases all damage you deal by {p}.` → `+ Damage dealt: {p}`.
- `Reduces the cooldown of your spells by {p}.` → `- {p} Cooldown`.
- `Increases your maximum health by {p}.` → `+ Maximum health: {p}`.
- `Improves your chance to get a critical strike by {p}.` → `+ Critical strike chance: {p}`.
- `Increases the damage of your critical strikes by {p}.` → `+ Critical damage: {p}`.
- `Reduces all damage taken by {p}.` → `- {p} Damage taken`.
- `Restores {v} health per second.` → `+ Health regen: {v}/s`.
- `Increases your movement speed by {p}.` → `+ Movement speed: {p}`.
- `Increases the area of effect of your spells by {p}.` → `+ Spell area: {p}`.
- `Increases the range you pick up loot from by {p}.` → `+ Loot pickup range: {p}`.
- `Increases experience gained by {p}.` → `+ Experience gained: {p}`.
- `Increases gold found by {p}.` → `+ Gold found: {p}`.
- `Increases your luck by {p}.` → `+ Luck: {p}`.
- `Gives your spells a {p} chance to cast twice.` → `+ Spell double-cast chance: {p}`.
- `Heals you for {p} of all damage you deal.` → `+ Lifesteal: {p}`.
- `Each enemy you kill restores {v} health.` → `+ Health on kill: {v}`.
- `Increases your weapon damage by {p}.` → `+ Weapon damage: {p}`.
- `Increases the damage your pets deal by {p}.` → `+ Pet damage: {p}`.
- `Increases damage dealt to crowd-controlled enemies by {p}.` → `+ Damage vs crowd-controlled enemies: {p}`.
- `Increases damage dealt to elites and bosses by {p}.` → `+ Damage vs elites / bosses: {p}`.
- `Increases damage dealt to enemies below 30% health by {p}.` → `+ Damage vs enemies below 30% health: {p}`.
- `Increases damage dealt to afflicted enemies by {p}.` → `+ Damage vs afflicted enemies: {p}`.
- `Melee attackers take {p} of the damage they deal you.` → `Reflect to melee attackers: {p} of their damage to you`.
- `Your damage, haste, shield and thorns buffs are {p} stronger.` → `+ Buff power: {p}`.
- `Restores {p} of your maximum health per second.` → `+ Health regen: {p} max health/s`.
- `Increases all damage you deal by {v}% for every 10% damage reduction you have.` → `+ Damage: {v}% per 10% damage reduction`.
- `Each 1% of damage reduction past the cap increases your damage by {v}%.` → `+ Damage: {v}% per 1% damage reduction above cap`.
- `Raises your damage reduction cap by {p}.` → `+ Damage reduction cap: {p}`.
- `Increases all damage you deal by {p} while a shield holds.` → `+ Damage while shielded: {p}`.
- `Your damage over time spells tick {v}% faster: more ticks, and more damage, in the same time. {max}% at most.` → `+ DoT haste: {v}% (more ticks / damage; same duration; cap {max}%)`.
- `Returns you to life at half health when you die. Holds {n} lives at most.` → `Revive at half health; max {n} lives`.

## Named modifiers: 16 templates

- `Increases the healing of {who} by {g}.` → `+ {who} healing: {g}`.
- `Increases the absorb of {who} by {g}.` → `+ {who} absorb: {g}`.
- `Increases the damage of {who} by {v}.` → `+ {who} damage: {v}`.
- `Reduces the cooldown of {who} by {v}.` → `- {who} cooldown: {v}`.
- `Increases the area of {who} by {v}.` → `+ {who} area: {v}`.
- `Increases the duration of {who} by {v}.` → `+ {who} duration: {v}`.
- `{who} deals an extra {v} of your maximum health.` → `{who}: +{v} of your max health as damage`.
- `{who} deal an extra {v} of your maximum health.` → `{who}: +{v} of your max health as damage`.
- `{who} strikes 1 more target.` → `+ {who} targets: 1`.
- `{who} strikes {n} more targets.` → `+ {who} targets: {n}`.
- `{who} strike 1 more target.` → `+ {who} targets: 1`.
- `{who} strike {n} more targets.` → `+ {who} targets: {n}`.
- `Increases how much {who} weakens enemies by {v}.` → `+ {who} weakening: {v}`.
- `Increases the strength of {who} by {v}.` → `+ {who} strength: {v}`.
- `{who} procs {v} more often.` → `+ {who} proc rate: {v}`.
- `Increases the stun duration of {who} by {v}.` → `+ {who} stun duration: {v}`.

## Special modifiers: 22 templates

- `{hits} leap to 1 more enemy for {frac}` → `{hits}: chain +1 enemy at {frac} damage`.
- `{hits} leap to {n} more enemies for {frac}` → `{hits}: chain +{n} enemies at {frac} damage`.
- `{chance} chance for {hits} to strike again for {frac}` → `{hits}: {chance} chance to hit again for {frac}`.
- `{chance} chance to stun a melee attacker for {s} sec` → `Melee attackers: {chance} stun chance for {s} sec`.
- `A broken shield bursts for {frac} of what it absorbed on enemies within {radius} yd` → `Shield breaks: {frac} of absorbed damage to enemies within {radius} yd`.
- `{hits} stun for {s} sec` → `{hits}: stun {s} sec`.
- `{hits} root for {s} sec` → `{hits}: root {s} sec`.
- `{hits} leave enemies taking {v} more damage for {s} sec` → `{hits}: enemies take {v} more damage for {s} sec`.
- `{hits} hinder enemies` → `{hits}: hinder enemies`.
- `{hits} burn and bleed for {frac} more over {dur} sec` → `{hits}: +{frac} burn and bleed over {dur} sec`.
- `{hits} splash {frac} on enemies within {radius} yd` → `{hits}: splash {frac} to enemies in {radius} yd`.
- `Enemies that die with {spell} on them explode for {frac} of their max health` → `On enemy death with {spell}: explode for {frac} of its max health`.
- `Enemies {spell} kills explode for {frac} of their max health` → `{spell} kills: explode for {frac} of enemy max health`.
- `Enemies you kill explode for {frac} of their max health` → `On kill: explode for {frac} of enemy max health`.
- `{who} leaps to {n} enemies when its victim dies` → `On victim death: {who} leaps to {n} enemies`.
- `A kill with {who} readies it again at once` → `On {who} kill: ready again instantly`.
- `Every totem pulse heals you {frac} of max health` → `Totem pulse: heal {frac} of max health`.
- `A killing blow leaves you at {heal} health instead, once every {cd} sec` → `Fatal hit: survive at {heal} health (once per {cd} sec)`.
- `Enemies you kill during {spell} explode for {frac} of their max health` → `Kills during {spell}: explode for {frac} of enemy max health`.
- `{spell} explodes a second time for {frac} of its damage` → `{spell}: second explosion for {frac} of its damage`.
- `{spell} also shields you for {frac} of your max health` → `{spell}: also shield for {frac} of your max health`.
- `While {spell} heals you, {p} of the damage you deal heals you too` → `While {spell} heals you: lifesteal {p} of damage dealt`.
