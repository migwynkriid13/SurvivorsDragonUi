"""Extract exact native gear-name/icon metadata, without executing game or Lua.

Like the SCT catalog generator, this reads pinned native records and DBC rows.
Only localized names, texture paths and exact Tier 0.5 tooltip references enter
the addon. Binary data, offsets and extraction dependencies stay outside it.
"""

import argparse
import hashlib
import json
import struct
from pathlib import Path

from generate_spell_icons import Dbc, lua_string, native_icon
from native_pe import PeImage


SOURCE_SHA256 = "6ca5f4ba4eb6b26716e4b7d9e03cbd25ddafe7582dcd8e55333e070a28058afa"
DISPLAY_SHA256 = "6f37ca862dc632a11aaf86e0ba7b183aa7abaebb052549e6120aa9fa69dd9dee"
CLASS_OFFSET, CLASS_BYTES, WEAPON_BYTES = 0x771E5B0, 304, 144
PVP_OFFSET, PVP_BYTES, PVP_WEAPON_BYTES = 0x771F520, 120, 48
TIER_HALF_OFFSET, TIER_HALF_BYTES = 0x772AA88, 0x228
TIER_HALF_ARMOR_BYTES, TIER_HALF_WEAPON_BYTES = 0x40, 0x50
CLASSES = ((1, "warrior"), (2, "paladin"), (3, "hunter"), (4, "rogue"), (5, "priest"), (7, "shaman"), (8, "mage"), (9, "warlock"), (11, "druid"))
MATERIALS = {1: "cloth", 2: "leather", 3: "mail", 4: "plate"}
CODES = ("en", "pl", "cs", "de", "pt", "es", "fr", "ro", "tr", "ru", "uk", "zh", "ja", "ko")
ARMOR_NOTICE_COLORS = ("ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffa335ee")


class Native:
    def __init__(self, path, source_sha256=SOURCE_SHA256):
        self.raw = path.read_bytes()
        if hashlib.sha256(self.raw).hexdigest() != source_sha256:
            raise ValueError("Review the changed executable before updating native offsets")
        self.image = PeImage(self.raw)
        self.number, self.offset = self.image.number, self.image.offset

    def text(self, at):
        address, length = struct.unpack_from("<QQ", self.raw, at)
        if not 0 < length < 1024:
            raise ValueError("Unexpected native string slice")
        return self.image.read(address, length).decode("utf-8")

    def catalogs(self):
        catalogs, seen, cursor = [], set(), 0
        while True:
            hit = self.raw.find(b'"noun.cloth.0"', cursor)
            if hit < 0:
                break
            cursor = hit + 1
            start = max(self.raw.rfind(b"{\n", 0, hit), self.raw.rfind(b"{\r\n", 0, hit))
            if start < 0 or start in seen:
                continue
            try:
                catalog, _ = json.JSONDecoder().raw_decode(self.raw[start:start + 2_000_000].decode(errors="replace"))
            except ValueError:
                continue
            if "item.name_prefix" not in catalog or "set.warlock.0" not in catalog:
                continue
            seen.add(start)
            catalogs.append(catalog)
        if len(catalogs) != len(CODES) or catalogs[0]["noun.cloth.0"] != "Circlet":
            raise ValueError("Review the changed native language order/layout")
        return dict(zip(CODES, catalogs))


def generate(arguments):
    native = Native(arguments.exe)
    display = Dbc(arguments.item_display_dbc, 23)
    if display.sha256() != DISPLAY_SHA256:
        raise ValueError("Review the changed native ItemDisplayInfo table")
    display_keys, native_paths = {}, {}
    for row in display.records():
        basename = display.string(row[5])
        path = basename if basename.lower().startswith("interface") else "Interface\\Icons\\" + basename
        resolved = native_icon(path) if basename else None
        display_keys[row[0]] = resolved[0] if resolved else None
        if resolved:
            key, path = resolved
            native_paths[key] = min(native_paths.get(key, path), path)
    display_icons = {ident: native_paths.get(key) for ident, key in display_keys.items()}
    catalogs = native.catalogs()
    groups = {code: {} for code in CODES}
    class_groups = {code: {key: {} for _, key in CLASSES} for code in CODES}
    records = []

    def add(names, display_id, origin, class_key, declared=None, display_origin=None, item_id=None, color=None):
        icon = display_icons.get(display_id)
        for code, name in names.items():
            groups[code].setdefault(name, set()).add((icon, item_id, color))
            class_groups[code][class_key].setdefault(name, set()).add((icon, item_id, color))
        record = {"name": names["en"], "class": class_key, "declared_display": display_id if declared is None else declared, "display": display_id, "icon": icon, "source_offset": origin, "display_source_offset": origin if display_origin is None else display_origin}
        if item_id is not None:
            record["item_id"] = item_id
        records.append(record)

    for index, (class_id, key) in enumerate(CLASSES):
        at = CLASS_OFFSET + index * CLASS_BYTES
        material, stored_class = struct.unpack_from("<BB", native.raw, at + 296)
        if stored_class != class_id or material not in MATERIALS:
            raise ValueError("Unexpected native class/material record")
        for tier in range(5):
            prefix_key = "set." + key + "." + str(tier)
            if native.text(at + tier * 24) != catalogs["en"][prefix_key]:
                raise ValueError("Native set prefix disagrees with its literal catalog key")
            grammar = native.number(at + tier * 24 + 16)
            if grammar not in (0, 1):
                raise ValueError("Unknown native item-name grammar")
            template = "item.name_of" if grammar else "item.name_prefix"
            for slot in range(8):
                noun = "noun." + MATERIALS[material] + "." + str(slot)
                names = {code: catalog[template].replace("{noun}", catalog[noun]).replace("{set}", catalog[prefix_key]) for code, catalog in catalogs.items()}
                origin = at + 136 + tier * 32 + slot * 4
                declared, selected, display_origin = native.number(origin, "I"), 0, origin
                # Native iterator 0x1459d2510: current tier down through zero,
                # then higher tiers ascending, selecting the first nonzero id.
                for candidate in list(range(tier, -1, -1)) + list(range(tier + 1, 5)):
                    display_origin = at + 136 + candidate * 32 + slot * 4
                    selected = native.number(display_origin, "I")
                    if selected:
                        break
                add(names, selected, origin, key, declared, display_origin, color=ARMOR_NOTICE_COLORS[tier])
        weapons, count = struct.unpack_from("<QQ", native.raw, at + 120)
        if count not in (1, 2):
            raise ValueError("Review the changed native weapon array")
        for weapon in range(count):
            start = native.offset(weapons) + weapon * WEAPON_BYTES
            for tier in range(5):
                label = "weapon." + key + "." + str(weapon) + "." + str(tier)
                if native.text(start + 8 + tier * 16) != catalogs["en"][label]:
                    raise ValueError("Native weapon name disagrees with its literal catalog key")
                origin = start + 120 + tier * 4
                add({code: catalog[label] for code, catalog in catalogs.items()}, native.number(origin, "I"), origin, key)

    for index, (class_id, key) in enumerate(CLASSES):
        at = PVP_OFFSET + index * PVP_BYTES
        if native.number(at + 112) != class_id:
            raise ValueError("Unexpected native PvP class record")
        material = MATERIALS[native.number(CLASS_OFFSET + index * CLASS_BYTES + 296, "B")]
        for faction in range(2):
            prefix = "set.pvp." + native.text(at + faction * 16)
            for slot in range(8):
                noun = "noun." + material + "." + str(slot)
                names = {code: catalog["item.name_prefix"].replace("{noun}", catalog[noun]).replace("{set}", catalog[prefix]) for code, catalog in catalogs.items()}
                origin = at + 48 + faction * 32 + slot * 4
                declared = native.number(origin, "I")
                # Native 0x1458f24c6..0x1458f24d8 substitutes class +0xe8:
                # regular tier index 3, for an empty PvP display field.
                display_origin = origin if declared else CLASS_OFFSET + index * CLASS_BYTES + 0xE8 + slot * 4
                add(names, native.number(display_origin, "I"), origin, key, declared, display_origin)
        weapons, count = struct.unpack_from("<QQ", native.raw, at + 32)
        if count not in (1, 2):
            raise ValueError("Review the changed native PvP weapon array")
        for weapon in range(count):
            start = native.offset(weapons) + weapon * PVP_WEAPON_BYTES
            for faction in range(2):
                origin = start + faction * 24
                label = "weapon.pvp." + native.text(origin + 8)
                add({code: catalog[label] for code, catalog in catalogs.items()}, native.number(origin, "I"), origin, key)

    regular_paths = {record["icon"] for record in records}
    for index, (class_id, key) in enumerate(CLASSES):
        at = TIER_HALF_OFFSET + index * TIER_HALF_BYTES
        if native.number(at + 0x224, "B") != class_id:
            raise ValueError("Unexpected Tier 0.5 class record")
        weapons, count = struct.unpack_from("<QQ", native.raw, at + 0x210)
        if count not in (1, 2):
            raise ValueError("Unexpected Tier 0.5 weapon slice")
        rows = [at + slot * TIER_HALF_ARMOR_BYTES for slot in range(8)]
        rows.extend(native.offset(weapons) + slot * TIER_HALF_WEAPON_BYTES for slot in range(count))
        for slot, row in enumerate(rows):
            name_id, display_id = struct.unpack_from("<II", native.raw, row + 0x30)
            label = "t05." + str(name_id)
            names = {code: catalog[label] for code, catalog in catalogs.items()}
            if names["en"] != native.text(row) or not display_icons.get(display_id):
                raise ValueError("Unresolved Tier 0.5 item name or display")
            # The native reward/query ID uses class and compact slot, not the
            # separate t05 localization key ID from the descriptor.
            item_id = 100070 + class_id * 1000 + slot * 100
            add(names, display_id, row + 0x34, key, item_id=item_id, color=ARMOR_NOTICE_COLORS[3])

    def resolve(choices):
        icons = {icon for icon, _, _ in choices}
        if len(icons) != 1 or None in icons:
            return False
        ids = {item_id for _, item_id, _ in choices}
        item_id = next(iter(ids)) if len(ids) == 1 else None
        return next(iter(icons)), item_id

    resolved = {code: {name: resolve(choices) for name, choices in names.items()} for code, names in groups.items()}
    refinements = {code: {key: {} for _, key in CLASSES} for code in CODES}
    # Some Mage set translations collide with the older rare set. Narrow only
    # when all of that name/class group's native notice colors are known.
    color_refinements = {code: {key: {} for _, key in CLASSES} for code in CODES}
    for code, classes in class_groups.items():
        for key, names in classes.items():
            for name, choices in names.items():
                if resolved[code][name]:
                    continue
                value = resolve(choices)
                if value:
                    refinements[code][key][name] = value
                    continue
                if not any(item_id for _, item_id, _ in choices):
                    continue
                colors = {color for _, _, color in choices}
                if None in colors:
                    continue
                values = {color: resolve({row for row in choices if row[2] == color}) for color in sorted(colors)}
                if any(values.values()):
                    color_refinements[code][key][name] = values
    paths = {value[0] for catalog in resolved.values() for value in catalog.values() if value} | {value[0] for classes in refinements.values() for names in classes.values() for value in names.values()}
    paths.update(value[0] for classes in color_refinements.values() for names in classes.values()
                 for values in names.values() for value in values.values() if value)
    paths = sorted(paths & regular_paths) + sorted(paths - regular_paths)
    indices = {path: index + 1 for index, path in enumerate(paths)}

    def lua_value(value):
        if not value:
            return "false"
        icon, item_id = value
        return f"tierHalf[{item_id}]" if item_id else f"icons[{indices[icon]}]"

    lines = ["-- Generated native display metadata by scripts/generate_loot_icons.py; do not edit.",
             "-- Exact localized gear names only; missing/conflicting native icons remain false.",
             "-- Executable SHA256: " + SOURCE_SHA256, "-- ItemDisplayInfo.dbc SHA256: " + DISPLAY_SHA256,
             "-- Provenance and coverage: docs/LOOT-ICONS.md. No binary/DBC is read at runtime.", "local icons = {"]
    lines.extend("    " + lua_string(path) + "," for path in paths)
    lines.extend(["}", "local tierHalf = {"])
    for record in records:
        if "item_id" in record and record["icon"] in indices:
            item_id, icon = record["item_id"], indices[record["icon"]]
            lines.append(f'    [{item_id}] = {{ icon = icons[{icon}], reference = "item:{item_id}:0:0:0" }},')
    lines.extend(["}", "DFRL.LootIconCatalog = {"])
    for code, catalog in resolved.items():
        lines.append("    " + code + " = {")
        for name, value in sorted(catalog.items()):
            lines.append("        [" + lua_string(name) + "] = " + lua_value(value) + ",")
        lines.append("    },")
    lines.append("    classes = {")
    for code, classes in refinements.items():
        lines.append("        " + code + " = {")
        for key, catalog in classes.items():
            lines.append("            " + key + " = {")
            for name, value in sorted(catalog.items()):
                lines.append("                [" + lua_string(name) + "] = " + lua_value(value) + ",")
            for name, values in sorted(color_refinements[code][key].items()):
                lines.append("                [" + lua_string(name) + "] = { byColor = {")
                for color, value in values.items():
                    lines.append("                    " + color + " = " + lua_value(value) + ",")
                lines.append("                } },")
            lines.append("            },")
        lines.append("        },")
    lines.extend(["    },", "}"])
    arguments.output.write_text("\n".join(lines) + "\n")
    metadata = {"executable_sha256": SOURCE_SHA256, "item_display_sha256": DISPLAY_SHA256, "class_offset": CLASS_OFFSET, "class_stride": CLASS_BYTES, "weapon_stride": WEAPON_BYTES, "pvp_offset": PVP_OFFSET, "pvp_stride": PVP_BYTES, "pvp_weapon_stride": PVP_WEAPON_BYTES, "records": records,
                "locales": {code: {"names": len(catalog), "resolved": sum(bool(icon) for icon in catalog.values())} for code, catalog in resolved.items()}, "texture_paths": len(paths),
                "unresolved_class_names": {code: sum(not resolve(choices) for names in classes.values() for choices in names.values()) for code, classes in class_groups.items()},
                "tier_half_offset": TIER_HALF_OFFSET, "tier_half_stride": TIER_HALF_BYTES}
    arguments.metadata.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
    print(str(len(records)) + " native gear records; " + str(len(paths)) + " texture paths; fourteen language catalogs")
    print("English exact names:", metadata["locales"]["en"])
    print("Novice's Circlet:", resolved["en"].get("Novice's Circlet"))
    print("Native display fallbacks:", sum(record["declared_display"] != record["display"] for record in records))
    print("Source records without a native icon:", sum(not record["icon"] for record in records))
    print("Exact name/class groups requiring color:",
          sum(len(names) for classes in color_refinements.values() for names in classes.values()))
    print("Exact name/class groups unresolved by class alone:", metadata["unresolved_class_names"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", required=True, type=Path)
    parser.add_argument("--item-display-dbc", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--metadata", required=True, type=Path)
    generate(parser.parse_args())
