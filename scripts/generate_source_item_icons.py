"""Author shared source item icons from pinned native records, without running the game.

Only names and texture paths ship. Table bounds, keys and source offsets stay
in developer metadata. The existing PE/catalog reader keeps language handling
shared with loot preparation; no addon or native instruction is executed.
"""

import argparse
import json
import re
from pathlib import Path

from generate_loot_icons import CODES, Native
from generate_spell_icons import lua_string, native_icon


SOURCE_SHA256 = "80ac3217660a02020b3e09f1ce93bfaa6ba89abd9a9d62405b9f70114fd6d46c"
TABLES = (("jewel", 0x72BE930, 72, 23), ("amulet", 0x72BFB90, 80, 16))


def generate(arguments):
    source = Native(arguments.client, SOURCE_SHA256)
    catalogs = source.catalogs()
    records = []
    for kind, start, stride, count in TABLES:
        for index in range(count):
            offset = start + index * stride
            key, name, icon = (source.text(offset + field) for field in (0, 16, 32))
            if not re.fullmatch(r"[a-z][a-z0-9_]+", key):
                raise ValueError("Review the native item key layout")
            locale_key = kind + "." + key
            if catalogs["en"].get(locale_key) != name:
                raise ValueError("Native item name disagrees with its locale key")
            normalized = native_icon("Interface\\Icons\\" + icon)
            if not normalized:
                raise ValueError("Native item record has no usable icon")
            records.append({"key": locale_key, "name": name, "icon": normalized[1], "source_offset": hex(offset)})

    paths = sorted({record["icon"] for record in records})
    indices = {path: index for index, path in enumerate(paths, 1)}
    lines = [
        "-- Generated native display metadata by scripts/generate_source_item_icons.py.",
        "-- Exact jewelry/amulet names; conflicting icons remain false.",
        "-- Executable SHA256: " + SOURCE_SHA256,
        "-- Provenance: docs/SOURCE-ICONS.md. No game/binary access at runtime.",
        'DFRL.tools.SourceIconFallback = "Interface\\\\Icons\\\\INV_Misc_QuestionMark"',
        "local icons = {",
    ]
    lines.extend("    " + lua_string(path) + "," for path in paths)
    lines.extend(["}", "DFRL.tools.SourceItemIconCatalog = {"])
    counts = {}
    for code in CODES:
        groups = {}
        for record in records:
            names = (record["name"], catalogs[code][record["key"]])
            for name in names:
                groups.setdefault(name, set()).add(record["icon"])
        lines.append("    " + code + " = {")
        for name, choices in sorted(groups.items()):
            value = "icons[" + str(indices[next(iter(choices))]) + "]" if len(choices) == 1 else "false"
            lines.append("        [" + lua_string(name) + "] = " + value + ",")
        lines.append("    },")
        counts[code] = {"names": len(groups), "ambiguous": sum(len(value) > 1 for value in groups.values())}
    lines.append("}")
    arguments.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    metadata = {"source_sha256": SOURCE_SHA256, "tables": TABLES, "records": records, "catalogs": counts}
    arguments.metadata.parent.mkdir(parents=True, exist_ok=True)
    arguments.metadata.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Prepared", len(records), "native item records in", len(CODES), "languages")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--client", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--metadata", required=True, type=Path)
    generate(parser.parse_args())
