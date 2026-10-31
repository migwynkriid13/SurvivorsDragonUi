#!/usr/bin/env python3
"""Read pinned native talent and ability catalogs without executing the game.

The fixed PE layout belongs only to the SHA256 below. Unknown builds are rejected
before their headers, pointers or catalog offsets are interpreted.
"""

from os.path import commonprefix
from pathlib import Path
import argparse
import hashlib
import json
import struct

from generate_spell_icons import Dbc
from native_pe import PeImage


SOURCE_SHA256 = "96e24dcd0e53fc13a6fdef5826aa46f77a29aa1aad4abd585adf04e94b2756d3"
CATALOG_OFFSET = 115721904
CLASS_COUNT = 9
CLASS_BYTES = 200
TREE_COUNT = 3
TREE_BYTES = 64
NODE_BYTES = 120
ABILITY_OFFSET = 112808376
ABILITY_COUNT = 113
ABILITY_BYTES = 120
# All six direct constant spell-id producers among the 34 native damage calls.
# Each pair is (MOV r9d, immediate; CALL shared native damage function).
# Other call sites use ability fields or live state and supply no fixed id here.
EFFECT_SITES = (
    (0x1458EA8FE, 0x1458EA904),
    (0x1458F0AD1, 0x1458F0AD7),
    (0x1458F1454, 0x1458F145A),
    (0x1458F153C, 0x1458F1577),
    (0x145900E76, 0x145900E7C),
    (0x145921697, 0x14592169D),
)
DAMAGE_FUNCTION = 0x145931B50
SELECTION = (
    "All nine class records, each containing its three native tree records; "
    "each tree selects its entire node array using the stored pointer/count slice; "
    "plus the complete 113-record native ability array and all six reviewed "
    "constant spell-id producers at the shared native damage function. "
    "Names and texture basenames are read from actual UTF-8 fat-pointer string fields, "
    "not inferred from adjacent text; fixed effect ids join their exact DBC rows."
)


def extract_records(raw, spells, spell_icons):
    image = PeImage(raw)
    file_offset = image.offset

    def string_at(at):
        address, length = struct.unpack_from("<QQ", raw, at)
        return image.read(address, length).decode("utf-8")

    records = []
    for class_index in range(CLASS_COUNT):
        class_start = CATALOG_OFFSET + class_index * CLASS_BYTES
        class_id = struct.unpack_from("<Q", raw, class_start + TREE_COUNT * TREE_BYTES)[0]
        trees = []
        for tree_index in range(TREE_COUNT):
            tree_start = class_start + tree_index * TREE_BYTES
            tree_name = string_at(tree_start)
            background = string_at(tree_start + 16)
            nodes_address, node_count = struct.unpack_from("<QQ", raw, tree_start + 48)
            trees.append((tree_name, background, file_offset(nodes_address), node_count))
        class_name = commonprefix([tree[1] for tree in trees]).upper()
        for tree_name, _, nodes_start, node_count in trees:
            for node_index in range(node_count):
                at = nodes_start + node_index * NODE_BYTES
                records.append(
                    {
                        "key": string_at(at + 32),
                        "name": string_at(at + 48),
                        "icon": "Interface\\Icons\\" + string_at(at + 64),
                        "kind": "talent",
                        "class": class_name,
                        "class_id": class_id,
                        "tree": tree_name,
                        "offset": at,
                    }
                )
    for index in range(ABILITY_COUNT):
        at = ABILITY_OFFSET + index * ABILITY_BYTES
        records.append(
            {
                "key": string_at(at),
                "name": string_at(at + 16),
                "icon": "Interface\\Icons\\" + string_at(at + 32),
                "kind": "ability",
                "offset": at,
            }
        )
    spell_rows = {row[0]: row for row in spells.records()}
    icon_paths = {row[0]: spell_icons.string(row[1]) for row in spell_icons.records()}
    for producer_address, call_address in EFFECT_SITES:
        producer, call = file_offset(producer_address), file_offset(call_address)
        if raw[producer : producer + 2] != b"\x41\xb9" or raw[call] != 0xE8:
            raise ValueError("Unexpected native fixed-effect instruction layout")
        destination = call_address + 5 + struct.unpack_from("<i", raw, call + 1)[0]
        if destination != DAMAGE_FUNCTION:
            raise ValueError("Native fixed-effect call has a different destination")
        spell_id = struct.unpack_from("<I", raw, producer + 2)[0]
        row = spell_rows[spell_id]
        records.append(
            {
                "name": spells.string(row[120]),
                "icon": icon_paths[row[117]],
                "kind": "effect",
                "spell_id": spell_id,
                "offset": producer,
                "call_offset": call,
            }
        )
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", required=True, type=Path)
    parser.add_argument("--spell-dbc", required=True, type=Path)
    parser.add_argument("--spell-icon-dbc", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()
    raw = arguments.exe.read_bytes()
    sha256 = hashlib.sha256(raw).hexdigest()
    if sha256 != SOURCE_SHA256:
        raise ValueError("Unsupported native catalog executable SHA256: " + sha256)
    spells = Dbc(arguments.spell_dbc, 173)
    spell_icons = Dbc(arguments.spell_icon_dbc, 2)
    records = extract_records(raw, spells, spell_icons)
    metadata = {
        "source": {
            "artifact": "AzerothSurvivors.exe",
            "sha256": sha256,
            "class_table_file_offset": CATALOG_OFFSET,
            "class_record_bytes": CLASS_BYTES,
            "tree_record_bytes": TREE_BYTES,
            "node_record_bytes": NODE_BYTES,
            "ability_table_file_offset": ABILITY_OFFSET,
            "ability_records": ABILITY_COUNT,
            "ability_record_bytes": ABILITY_BYTES,
            "fixed_effect_sites": len(EFFECT_SITES),
            "damage_function_address": hex(DAMAGE_FUNCTION),
            "spell_dbc_sha256": spells.sha256(),
            "spell_icon_dbc_sha256": spell_icons.sha256(),
            "selection": SELECTION,
        },
        "records": records,
    }
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(str(arguments.output))
    print(str(len(records)) + " native talent/ability/effect records")


if __name__ == "__main__":
    main()
