"""Read native healing source/icon pairs as data, without executing the client.

The five reviewed producers build the records used by the official healing
meter. Read their RIP-relative string pointers and immediate lengths, not
neighboring strings or spell-name guesses. Unknown builds require source review.
"""

import argparse
import hashlib
import json
import re
import struct
from pathlib import Path

from native_pe import PeImage

ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHA256 = "291c281bd0a4255fdb3d04b2e442121e2df144f388f16de086b430e875aaad08"
# Name LEA, name-length MOV, icon LEA, icon-length MOV/prefix, record call/target.
SITES = (
    (0x145B772BA, 0x145B772C1, 0x145B7730C, 0x145B77317, b"\x48\xc7\x45\x48", 0x145B7734B, 0x145BF4D30),
    (0x145B7C92C, 0x145B7C938, 0x145B7C963, 0x145B7C96F, b"\x48\xc7\x44\x24\x50", 0x145B7C9A5, 0x145BF4D30),
    (0x145BC12B9, 0x145BC12C5, 0x145BC12F7, 0x145BC1305, b"\x48\xc7\x85\x00\x01\x00\x00", 0x145BC1365, 0x145B7C8A0),
    (0x145B8EF63, 0x145B8EF5E, 0x145B8EFDF, 0x145B8EFEA, b"\x48\xc7\x45\x00", 0x145B8F016, 0x145BF4D30),
    (0x145B79C8E, 0x145B79C9A, 0x145B79CC2, 0x145B79CCD, b"\x48\xc7\x45\x60", 0x145B79CFB, 0x145BF4D30),
)


def extract(client):
    raw = client.read_bytes()
    fingerprint = hashlib.sha256(raw).hexdigest()
    if fingerprint != SOURCE_SHA256:
        raise ValueError("Review the new executable before interpreting the pinned healing producers.")
    image = PeImage(raw)
    read = image.read

    def immediate(address, prefix):
        encoded = read(address, len(prefix) + 4)
        if not encoded.startswith(prefix):
            raise ValueError("Review the native healing length instruction.")
        return struct.unpack_from("<I", encoded, len(prefix))[0]

    def text(lea, length):
        encoded = read(lea, 7)
        if encoded[0] not in (0x48, 0x4C) or encoded[1] != 0x8D or encoded[2] & 0xC7 != 5:
            raise ValueError("Review the native healing string instruction.")
        target = lea + 7 + struct.unpack_from("<i", encoded, 3)[0]
        return read(target, length).decode("utf-8")

    records = []
    for name_at, length_at, icon_at, icon_length_at, prefix, call_at, target in SITES:
        call = read(call_at, 5)
        if call[0] != 0xE8 or call_at + 5 + struct.unpack_from("<i", call, 1)[0] != target:
            raise ValueError("Review the native healing record consumer.")
        records.append({
            "name": text(name_at, immediate(length_at, b"\xba")),
            "icon": "Interface\\Icons\\" + text(icon_at, immediate(icon_length_at, prefix)),
            "name_instruction": hex(name_at),
            "icon_instruction": hex(icon_at),
            "record_call": hex(call_at),
            "record_consumer": hex(target),
        })

    runtime = (ROOT / "localization/data.lua").read_text()
    identities = {}
    for match in re.finditer(r"^    (\w+) = \{\n.*?^        native = \{\n(.*?)^        \},", runtime, re.M | re.S):
        warrior = re.search(r'^            \["class.warrior.name"\] = ("(?:[^"\\]|\\.)*"),$', match[2], re.M)
        if warrior:
            identities[json.loads(warrior[1])] = match[1]
    catalogs, seen = {}, set()
    for match in re.finditer(b'"class.warrior.name"', raw):
        at = match.start()
        start = max(raw.rfind(b"{\r\n", max(0, at - 2_000_000), at), raw.rfind(b"{\n", max(0, at - 2_000_000), at))
        if start < 0 or start in seen:
            continue
        try:
            catalog, _ = json.JSONDecoder().raw_decode(raw[start : start + 2_000_000].decode("utf-8", errors="replace"))
        except ValueError:
            continue
        if not isinstance(catalog, dict) or "Increases your luck by {p}." not in catalog:
            continue
        seen.add(start)
        code = identities[catalog["class.warrior.name"]]
        catalogs[code] = {record["name"]: catalog[record["name"]] for record in records}
    if len(catalogs) != 14:
        raise ValueError("Review the native catalog identities before authoring translated healing keys.")
    return {"source_sha256": fingerprint, "records": records, "captions": catalogs}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--client", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()
    metadata = extract(arguments.client)
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
    print(arguments.output)


if __name__ == "__main__":
    main()
