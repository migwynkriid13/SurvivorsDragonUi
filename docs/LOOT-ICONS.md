# Native loot icon metadata

The native self-loot producer formats the item as a colored `[name]`, without
an `item:` hyperlink. Its separate native drop record has an icon, but the
published Lua run API does not expose that record. The original addon resolver
returned immediately without a hyperlink, so these drops never reached
`GetItemInfo` and the view deliberately hid the icon.

The fix follows the existing SCT approach: generate exact display metadata from
the installed game's own authored catalogs and native database. Live
exact-reference `GetItemInfo` metadata retains priority. The generated fallback
uses the full received name and works without an item link or warmed item cache.

For the reported **Novice's Circlet**, the native Warlock record supplies
display id **8415**. That exact `ItemDisplayInfo.dbc` row supplies
**`INV_Helmet_04`**, yielding `Interface\Icons\INV_Helmet_04`.
This is a native record join, not an icon selected from the word “Circlet.”

## Runtime lookup

`modules/ui/loot_icons.lua` loads before the loot service. It contains only
localized name/path tables, exact Tier 0.5 item references and native class refinements. `loot.Resolve` first
tries the original item reference when supplied, then consults this catalog.
Unknown and conflicting entries remain unavailable. Existing message names,
quality colors, collection filtering and chat output remain unchanged.

The service captures the second, canonical return of native `UnitClass("player")`
when each accepted self-loot occurrence arrives. For a name that is ambiguous
across the native class-specific gear catalogs, that captured class can narrow
the same catalog tier. Class is never inferred from a name, icon, color or
equipment. Seven Russian and Ukrainian Mage names are shared by the regular
rare set and Tier 0.5. Those class entries require the exact received native
color, `ff0070dd` for the regular set or `ffa335ee` for Tier 0.5. This selects
between source records without deriving quality from the color. Missing class
or color leaves those entries unresolved. Queued cards retain the class at
delivery, and world cleanup clears them.

A linked drop can show the catalog icon immediately while its existing bounded
two-second metadata retry still waits for a stronger native template. A later
native icon replaces the generated fallback. There is no extra polling scan,
spell-icon lookup, runtime binary/DBC access, new bitmap or SavedVariable.
Hover uses the original received hyperlink payload or the exact Tier 0.5
reference. For example, **Helm of Heroism** joins display **34614** to
`INV_Helmet_02` and uses gear ID **101070** for the native tooltip.

## Pinned inputs and extraction

The current extraction uses the installed Windows 0.141.0 executable, with
151,493,632 bytes and SHA-256
`6ca5f4ba4eb6b26716e4b7d9e03cbd25ddafe7582dcd8e55333e070a28058afa`.
The original extraction observed the linkless drop format at
`0x145898b59` in build `8f8de1512420dd6c9fefcbbf90a6a6feaf7388ba1cda3b6c3d5eaa7a74927514`.

The native regular class array starts at file offset **0x771e5b0**. Its nine
304-byte records contain five 24-byte prefix/grammar records, a weapon-array
pointer/count at 120/128, five eight-element display-id rows at 136, and
material/class bytes at 296/297. Each 144-byte weapon record supplies five
name slices at 8 and five display ids at 120. All selected arrays are walked.
The recovered regular armor display order is:
start at the item's tier, descend to zero, then search higher tiers ascending,
returning the first nonzero display. The generator mirrors that verified order
when a field is zero; it does not assign an icon from an armor-slot stereotype.

The PvP array starts at **0x771f520**. Each of its nine 120-byte records contains
the two faction prefixes, a weapon-array pointer/count at 32/40, two eight-element
display-id rows at 48 and the class id at 112. Its 48-byte weapon records contain
two 24-byte display/name records. The generator reads the actual prefix and
weapon names; it does not invent faction aliases or add a weapon whitelist.
An empty PvP display is replaced by
`class + 0xe8 + slot*4`: the regular tier with index 3. This native fallback
also participates in generation. Developer metadata preserves both the declared
display field and the resolved display's actual source offset.

All fourteen embedded catalogs provide the exact `set.*`, `noun.*`,
`item.name_prefix`, `item.name_of` and `weapon.*` text. Regular names use their
stored native grammar flag. Both CRLF and LF JSON boundaries are handled: the
current English catalog uses CRLF. Unknown executable hashes, changed record
identities, strings or language layout are rejected before generation.

The winning Windows input is `Data/patch.MPQ` →
`DBFilesClient\ItemDisplayInfo.dbc`. The installed patches 2 through C contain no override.
The 23-field, 29,604-row table has SHA-256
`6f37ca862dc632a11aaf86e0ba7b183aa7abaebb052549e6120aa9fa69dd9dee`;
field 0 is the display id and field 5 its icon basename. Its extracted bytes
also match the installed web client's loose table. Original archives,
executable, DBC and texture bytes do not enter the addon repository or payload.

```sh
python3 scripts/generate_loot_icons.py \
  --exe /path/to/AzerothSurvivors.exe \
  --item-display-dbc /path/to/ItemDisplayInfo.dbc \
  --output modules/ui/loot_icons.lua \
  --metadata docs/loot-icon-metadata.json
```

The generator reuses SCT's DBC reader, native texture normalization and Lua
string writer. This is text-data extraction, without executing game or addon
code. The committed developer metadata records every source offset and display
join for review. Only the generated Lua tables join the runtime manifest.

Tier 0.5 uses nine 0x228-byte class records at file offset **0x772aa88**.
Each contains eight 0x40-byte armor rows and a weapon pointer/count at
`+0x210` and `+0x218`. Weapon rows use a 0x50-byte stride. In both layouts
`+0x30` is the `t05.<id>` localization key and `+0x34` is the display ID.
The native equipment receipt and item query use
`100070 + 1000 * class + 100 * compact_slot`, with weapon slots following
the eight armor slots. This is the ID sent to the tooltip. The generator
checks each raw English name against the localized record and requires a
valid display join.

## Coverage and limits

The current extraction joins **664** source records to native icons across
fourteen languages. This covers 415 regular and 166 faction PvP records, plus
72 Tier 0.5 armor pieces and 11 Scholomance weapons. There are 201 texture
paths. The 43 native display fallbacks still cover seven regular armor
records and 36 PvP records.

English has 553 exact names and 532 globally resolved names. The existing
class refinement handles cross-class variants, with seven more names
requiring class and color. Fourteen Romanian same-class collisions remain
ambiguous. Unknown names or unavailable artwork retain the text-only fallback.

The native record join establishes the expected icons and tooltip references.
In-game tooltip delivery and rendering remain unverified. Lifecycle coverage
is authored for CI only.
