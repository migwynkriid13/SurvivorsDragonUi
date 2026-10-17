#!/usr/bin/env python3
"""Read the pinned native talent catalog as data without executing the game.

The fixed PE layout belongs only to the SHA256 below. Unknown builds are rejected
before their headers, pointers or catalog offsets are interpreted.
"""

from os.path import commonprefix
from pathlib import Path
import argparse
import hashlib
import json
import struct


SOURCE_SHA256 = "7264d50b82a1ecc2b5f0fcf2f29669c2acaa8bb87c058e17898a47a12984ff30"
CATALOG_OFFSET = 109907016
CLASS_COUNT = 9
CLASS_BYTES = 200
TREE_COUNT = 3
TREE_BYTES = 64
NODE_BYTES = 104
SELECTION = (
    "All nine class records, each containing its three native tree records; "
    "each tree selects its entire node array using the stored pointer/count slice. "
    "Names and texture basenames are read from native UTF-8 fat-pointer string fields, "
    "not inferred from adjacent text."
)


def extract_records(raw):
    pe = struct.unpack_from("<I", raw, 0x3C)[0]
    if raw[:2] != b"MZ" or raw[pe : pe + 4] != b"PE\0\0":
        raise ValueError("Expected the pinned Windows PE executable")
    section_count = struct.unpack_from("<H", raw, pe + 6)[0]
    optional_size = struct.unpack_from("<H", raw, pe + 20)[0]
    optional = pe + 24
    if struct.unpack_from("<H", raw, optional)[0] != 0x20B:
        raise ValueError("Expected the pinned PE32+ optional header")
    image_base = struct.unpack_from("<Q", raw, optional + 24)[0]
    sections = []
    for index in range(section_count):
        at = optional + optional_size + index * 40
        _, rva, size, offset = struct.unpack_from("<4I", raw, at + 8)
        sections.append((image_base + rva, offset, size))

    def file_offset(address):
        for base, offset, size in sections:
            if base <= address < base + size:
                return offset + address - base
        raise ValueError("Native pointer is outside the PE file-backed sections")

    def string_at(at):
        address, length = struct.unpack_from("<QQ", raw, at)
        start = file_offset(address)
        if start + length > len(raw):
            raise ValueError("Native string extends beyond the PE file")
        return raw[start : start + length].decode("utf-8")

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
                        "key": string_at(at),
                        "name": string_at(at + 16),
                        "icon": "Interface\\Icons\\" + string_at(at + 32),
                        "class": class_name,
                        "class_id": class_id,
                        "tree": tree_name,
                        "offset": at,
                    }
                )
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()
    raw = arguments.exe.read_bytes()
    sha256 = hashlib.sha256(raw).hexdigest()
    if sha256 != SOURCE_SHA256:
        raise ValueError("Unsupported native catalog executable SHA256: " + sha256)
    records = extract_records(raw)
    metadata = {
        "source": {
            "artifact": "AzerothSurvivors.exe",
            "sha256": sha256,
            "class_table_file_offset": CATALOG_OFFSET,
            "class_record_bytes": CLASS_BYTES,
            "tree_record_bytes": TREE_BYTES,
            "node_record_bytes": NODE_BYTES,
            "selection": SELECTION,
        },
        "records": records,
    }
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(str(arguments.output))
    print(str(len(records)) + " native talent records")


if __name__ == "__main__":
    main()
