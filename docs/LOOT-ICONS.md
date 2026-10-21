# Native loot icon metadata

The native self-loot producer formats the item as a colored `[name]`, without
an `item:` hyperlink. Its separate native drop record has an icon, but the
published Lua run API does not expose that record. The original addon resolver
returned immediately without a hyperlink, so these drops never reached
`GetItemInfo` and the view deliberately hid the icon.

The fix follows the existing SCT approach: generate exact display metadata from
the installed game's own authored catalogs and native database. Live
exact-reference `GetItemInfo` metadata retains priority. The generated fallback
needs no item link or warmed item cache, uses the full received name, and never
queries guessed item ids, picks a similar name or substitutes an unrelated icon.

For the reported **Novice's Circlet**, the native Warlock record supplies
display id **8415**. That exact `ItemDisplayInfo.dbc` row supplies
**`INV_Helmet_04`**, yielding `Interface\Icons\INV_Helmet_04`.
This is a native record join, not an icon selected from the word “Circlet.”

## Runtime lookup

`modules/ui/loot_icons.lua` loads before the loot service. It contains only
localized name/path tables and native class refinements. `loot.Resolve` first
tries the original item reference when supplied, then consults this catalog.
Unknown and conflicting entries remain unavailable. Existing message names,
quality colors, collection filtering and chat output remain unchanged.

The service captures the second, canonical return of native `UnitClass("player")`
when each accepted self-loot occurrence arrives. For a name that is ambiguous
across the native class-specific gear catalogs, that captured class can narrow
the same catalog tier. Class is never inferred from a name, icon, color or
equipment. An ambiguity remaining within that class is still unavailable;
missing class data retains the global ambiguity instead of choosing a class.
Queued cards retain their delivery's class, and world cleanup clears them.

A linked drop can show the catalog icon immediately while its existing bounded
two-second metadata retry still waits for a stronger native template. A later
native icon replaces the generated fallback. There is no extra polling scan,
spell-icon lookup, runtime binary/DBC access, new bitmap or SavedVariable.

## Pinned inputs and extraction

The inspected installed Windows executable has 140,034,048 bytes and SHA-256
`8f8de1512420dd6c9fefcbbf90a6a6feaf7388ba1cda3b6c3d5eaa7a74927514`.
Its current drop producer at `0x145898b59` translates `You receive loot:` and
formats the item through the compiled literal at `0x1471a9830`, whose text
fragments are `|c`, `[` and `]|r`; it creates no hyperlink payload. The native
drop record separately contains `type`, `name`, `rarity`, `icon`, `slot`, `new`.
These are observations of this pinned packaged client, independent of the
unrelated reconstruction's runtime behavior.

The native regular class array starts at file offset **119190736**. Its nine
304-byte records contain five 24-byte prefix/grammar records, a weapon-array
pointer/count at 120/128, five eight-element display-id rows at 136, and
material/class bytes at 296/297. Each 144-byte weapon record supplies five
name slices at 8 and five display ids at 120. All selected arrays are walked.
The native gear reader calls `0x1459d2510` to choose a regular armor display:
start at the item's tier, descend to zero, then search higher tiers ascending,
returning the first nonzero display. The generator mirrors that verified order
when a field is zero; it does not assign an icon from an armor-slot stereotype.

The PvP array starts at **119194688**. Each of its nine 120-byte records contains
the two faction prefixes, a weapon-array pointer/count at 32/40, two eight-element
display-id rows at 48 and the class id at 112. Its 48-byte weapon records contain
two 24-byte display/name records. The generator reads the actual prefix and
weapon names; it does not invent faction aliases or add a weapon whitelist.
At `0x1458f24c6` through `0x1458f24d8`, an empty PvP display is replaced by
`class + 0xe8 + slot*4`: the regular tier with index 3. This native fallback
also participates in generation. Developer metadata preserves both the declared
display field and the resolved display's actual source offset.

All fourteen embedded catalogs provide the exact `set.*`, `noun.*`,
`item.name_prefix`, `item.name_of` and `weapon.*` text. Regular names use their
stored native grammar flag. Both CRLF and LF JSON boundaries are handled: the
current English catalog uses CRLF. Unknown executable hashes, changed record
identities, strings or language layout are rejected before generation.

The winning Windows input is `Data/patch.MPQ` →
`DBFilesClient\ItemDisplayInfo.dbc`. Patches 2 through 8 contain no override.
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

## Coverage and limits

The current extraction walks **581** authored gear records: **415** regular
armor/weapon records and **166** faction PvP records across all nine classes.
It produces **194** texture paths and fourteen localized name catalogs. The
English catalog has **470** exact names, **449** globally resolved; native class
refinements retain otherwise ambiguous authored class variants.

All **581** source records resolve to native icons after the game's **43**
display fallbacks: seven regular armor records and 36 PvP records. This also
covers pieces such as Squire's Helm whose direct display field is zero.
Every exact name/class group resolves within each of the fourteen catalogs;
class data is still required for globally ambiguous names. An actually absent
or question-mark icon, an unresolved collision, definitions outside the pinned
catalogs and future changed names retain the existing unavailable fallback.
No generic item picture is passed off as a known native icon.

No local tests, syntax/formatting checks or addon/game execution were run.
GitHub Actions supplies the authorized static checks. The native data join
establishes the intended icon for the report; in-game rendering still requires
the user's next observation.
