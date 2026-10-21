"""Extract exact native gear-name/icon metadata, without executing game or Lua.

Like the SCT catalog generator, this reads pinned native records and DBC rows.
Only final localized names and texture paths enter the addon; ids, binary data,
catalog offsets and extraction dependencies remain outside the runtime payload.
"""

import argparse
import hashlib
import json
import struct
from pathlib import Path

from generate_spell_icons import Dbc, lua_string, native_icon


SOURCE_SHA256 = "8f8de1512420dd6c9fefcbbf90a6a6feaf7388ba1cda3b6c3d5eaa7a74927514"
DISPLAY_SHA256 = "6f37ca862dc632a11aaf86e0ba7b183aa7abaebb052549e6120aa9fa69dd9dee"
CLASS_OFFSET, CLASS_BYTES, WEAPON_BYTES = 119190736, 304, 144
PVP_OFFSET, PVP_BYTES, PVP_WEAPON_BYTES = 119194688, 120, 48
CLASSES = ((1, "warrior"), (2, "paladin"), (3, "hunter"), (4, "rogue"), (5, "priest"), (7, "shaman"), (8, "mage"), (9, "warlock"), (11, "druid"))
MATERIALS = {1: "cloth", 2: "leather", 3: "mail", 4: "plate"}
CODES = ("en", "pl", "cs", "de", "pt", "es", "fr", "ro", "tr", "ru", "uk", "zh", "ja", "ko")


class Native:
    def __init__(self, path):
        self.raw = path.read_bytes()
        if hashlib.sha256(self.raw).hexdigest() != SOURCE_SHA256:
            raise ValueError("Review the changed executable before updating native offsets")
        pe = self.number(0x3C, "I")
        optional = pe + 24
        if self.raw[:2] != b"MZ" or self.raw[pe:pe + 4] != b"PE\0\0" or self.number(optional, "H") != 0x20B:
            raise ValueError("Expected the pinned PE32+ executable")
        base = self.number(optional + 24, "Q")
        self.sections = []
        for index in range(self.number(pe + 6, "H")):
            at = optional + self.number(pe + 20, "H") + index * 40
            _, rva, size, offset = struct.unpack_from("<4I", self.raw, at + 8)
            self.sections.append((base + rva, offset, size))

    def number(self, at, kind="Q"):
        return struct.unpack_from("<" + kind, self.raw, at)[0]

    def offset(self, address):
        for base, offset, size in self.sections:
            if base <= address < base + size:
                return offset + address - base
        raise ValueError("Native pointer is outside file-backed sections")

    def text(self, at):
        address, length = struct.unpack_from("<QQ", self.raw, at)
        start = self.offset(address)
        if not 0 < length < 1024 or start + length > len(self.raw):
            raise ValueError("Unexpected native string slice")
        return self.raw[start:start + length].decode("utf-8")

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

    def add(names, display_id, origin, class_key):
        icon = display_icons.get(display_id)
        for code, name in names.items():
            groups[code].setdefault(name, set()).add(icon)
            class_groups[code][class_key].setdefault(name, set()).add(icon)
        records.append({"name": names["en"], "class": class_key, "display": display_id, "icon": icon, "source_offset": origin})

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
                add(names, native.number(origin, "I"), origin, key)
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
                add(names, native.number(origin, "I"), origin, key)
        weapons, count = struct.unpack_from("<QQ", native.raw, at + 32)
        if count not in (1, 2):
            raise ValueError("Review the changed native PvP weapon array")
        for weapon in range(count):
            start = native.offset(weapons) + weapon * PVP_WEAPON_BYTES
            for faction in range(2):
                origin = start + faction * 24
                label = "weapon.pvp." + native.text(origin + 8)
                add({code: catalog[label] for code, catalog in catalogs.items()}, native.number(origin, "I"), origin, key)

    resolved = {code: {name: next(iter(choices)) if len(choices) == 1 and None not in choices else False for name, choices in names.items()} for code, names in groups.items()}
    refinements = {code: {key: {name: next(iter(choices)) for name, choices in names.items() if resolved[code][name] is False and len(choices) == 1 and None not in choices} for key, names in classes.items()} for code, classes in class_groups.items()}
    paths = sorted({icon for catalog in resolved.values() for icon in catalog.values() if icon} | {icon for classes in refinements.values() for names in classes.values() for icon in names.values()})
    indices = {path: index + 1 for index, path in enumerate(paths)}
    lines = ["-- Generated native display metadata by scripts/generate_loot_icons.py; do not edit.",
             "-- Exact localized gear names only; missing/conflicting native icons remain false.",
             "-- Executable SHA256: " + SOURCE_SHA256, "-- ItemDisplayInfo.dbc SHA256: " + DISPLAY_SHA256,
             "-- Provenance and coverage: docs/LOOT-ICONS.md. No binary/DBC is read at runtime.", "local icons = {"]
    lines.extend("    " + lua_string(path) + "," for path in paths)
    lines.extend(["}", "DFRL.LootIconCatalog = {"])
    for code, catalog in resolved.items():
        lines.append("    " + code + " = {")
        for name, icon in sorted(catalog.items()):
            lines.append("        [" + lua_string(name) + "] = " + ("icons[" + str(indices[icon]) + "]" if icon else "false") + ",")
        lines.append("    },")
    lines.append("    classes = {")
    for code, classes in refinements.items():
        lines.append("        " + code + " = {")
        for key, catalog in classes.items():
            lines.append("            " + key + " = {")
            for name, icon in sorted(catalog.items()):
                lines.append("                [" + lua_string(name) + "] = icons[" + str(indices[icon]) + "],")
            lines.append("            },")
        lines.append("        },")
    lines.extend(["    },", "}"])
    arguments.output.write_text("\n".join(lines) + "\n")
    metadata = {"executable_sha256": SOURCE_SHA256, "item_display_sha256": DISPLAY_SHA256, "class_offset": CLASS_OFFSET, "class_stride": CLASS_BYTES, "weapon_stride": WEAPON_BYTES, "pvp_offset": PVP_OFFSET, "pvp_stride": PVP_BYTES, "pvp_weapon_stride": PVP_WEAPON_BYTES, "records": records,
                "locales": {code: {"names": len(catalog), "resolved": sum(bool(icon) for icon in catalog.values())} for code, catalog in resolved.items()}, "texture_paths": len(paths)}
    arguments.metadata.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
    print(str(len(records)) + " native gear records; " + str(len(paths)) + " texture paths; fourteen language catalogs")
    print("English exact names:", metadata["locales"]["en"])
    print("Novice's Circlet:", resolved["en"].get("Novice's Circlet"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", required=True, type=Path)
    parser.add_argument("--item-display-dbc", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--metadata", required=True, type=Path)
    generate(parser.parse_args())
