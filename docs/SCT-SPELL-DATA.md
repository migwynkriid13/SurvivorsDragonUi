# SCT area spell data

**Combat → Combat text → Area of Effect** defaults on. Turning it off excludes
identified area damage even when Direct abilities / spells and Critical damage
are enabled. Turning it on retains the other result/category filters. The
checkbox uses the existing display transaction, profiles, search and resets;
missing/invalid choices and older profiles default on, while saved off survives.

## Native data and classification

`modules/nameplates/spell_data.lua` is generated from the installed executable's
complete native ability table, not a maintained list of reported abilities.
The current input is 147,995,648 bytes, SHA-256
`eb5fd1c1b96e6180fcf5f3d685d90a61471af28d22e5f060c02b7b7663fbf79e`.
The table starts at file offset `0x711b6a8`, with 114 records of 120 bytes.

The reference is AzerothSurvivorsRE's
`docs/analysis/ability-definitions-0.109.0.md`, the recovered
`src/player_abilities/catalog.rs` and the dispatch/periodic/totem/class-special
consumers under `src/player_abilities/behavior/`. The older 113-row catalog
establishes the layout and cast-kind semantics; its old numeric values are not
copied into the current output. Current data adds Rockbiter and Stormstrike and
removes Call of Flame. The generated header records both input fingerprints.

| Native field                       | Offset  | Use                                                         |
| ---------------------------------- | ------- | ----------------------------------------------------------- |
| Key/name/icon pointer-length pairs | 0/16/32 | Full-table identity and exact native names                  |
| Upgrade slice                      | 48      | Record-layout admission                                     |
| Spell ID                           | 64      | Native hit identity                                         |
| Radius                             | 80      | Area versus targeted totem/class-special behavior           |
| Pulse spell ID                     | 100     | Totem damage uses this ID, independently of the summon cast |
| School/cast kind                   | 116/117 | Layout admission and recovered cast behavior                |

The authoring rule uses cast geometry:

- Kinds 2, 3 and 8 are radial attacks, ground-periodic areas and cones.
- Kinds 10 and 11 use their area classification when their definition radius is
  positive: area totem pulses and area class-special effects.
- Chain-hop radius is a distance between selected targets, not an area hit.
  Separately selected projectiles, melee targets and attached DoTs retain their
  existing categories; target count does not make them AoE.

This produces 32 area definitions. Consecration is kind 3 with radius 8 and
spell ID 26573. Magma Totem's damage uses pulse ID 8187, which is classified
alongside its primary ID; Searing Totem's targeted pulse remains non-area.
These examples do not supply a runtime whitelist or special-case branches.

## Runtime lookup and limits

The native adapter preserves the received scalar spell ID. An identified hit
uses the generated ID lookup; an unknown received ID cannot borrow another
spell's name. Shared IDs agree on one classification or retain exact-name
choices. Legacy hits without IDs use exact native names and the existing
active-language canonical aliases. Conflicting aliases remain unknown.

Unidentified effects stay visible. This catalog covers the native ability
definitions and their pulse IDs; it does not establish every independent item,
talent or dynamically supplied spell's targeting behavior. No tooltip wording,
spell-name substring, icon, current target, observed target count or timing
window is used to invent a classification. Classification describes recovered
spell geometry, not a newly received per-hit native AoE flag. An area spell
remains classified as area damage when it hits only one enemy.

Each damage hit resolves its classification once during existing intake. Pending
and active entries retain that scalar; pool retirement clears it. Performance
Mode grouping includes area classification so mixed members cannot exchange
filter visibility. Existing matching, loss consumption, native counters,
animations and lifetimes remain unchanged. Active previews use the shared
display listener, without re-registering the native frame handler or replaying
retired hits. Both Performance Mode states use the same filter.

## Regeneration and evidence

```sh
python3 -B scripts/generate_sct_spell_data.py \
  --exe /path/to/AzerothSurvivors.exe \
  --reference-catalog /path/to/AzerothSurvivorsRE/crates/azeroth-survivors-re/src/player_abilities/catalog.rs
```

The generator checks the pinned executable before reading the table, includes
every current record and preserves shared-ID/name conflicts. New executable
bytes require a reviewed pin/layout update. It reads data only and never
executes the addon, reconstructed code or game. No raw EXE/DBC or RE checkout is
required at addon runtime.

CI-only cases cover default/saved/profile/discard/reset behavior, all three
styles and both modes, native Consecration and totem pulse IDs, independent
critical/periodic choices, queued/current choices, mixed grouping, active
removal, pooled reuse, exact localized names, conflicts, unknown IDs and world
cleanup. Editor cases cover search, the compact category grid without a description, preview and the final row.
Local work is data preparation, source inspection and pinned formatting only;
no local tests, standalone validation or addon/game execution was performed.
Current native cast-consumer parity, live payloads, appearance and FPS remain
unverified.
